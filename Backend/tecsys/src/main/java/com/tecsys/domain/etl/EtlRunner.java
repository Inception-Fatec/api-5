package com.tecsys.domain.etl;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Deque;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;
import java.util.stream.Stream;

@Slf4j
@Component
@RequiredArgsConstructor
public class EtlRunner {

    private static final String RESULT_PREFIX = "ETL_RESULT:";
    private static final String INSPECAO_PREFIX = "ETL_INSPECAO:";
    private static final String ETAPA_PREFIX = "ETL_ETAPA:";
    private static final int LOG_TAIL_LINES = 300;
    private static final List<String> PARAMS_LIBPQ = List.of("sslmode", "sslrootcert", "sslcert", "sslkey");
    private static final long INSPECAO_TIMEOUT_MINUTOS = 10;

    static final String ZIP = "upload.zip";

    private final EtlJobRepository jobRepository;
    private final DataSourceProperties dataSourceProperties;

    @Value("${etl.python-executable:python}")
    private String pythonExecutable;

    @Value("${etl.script-path:../api-5/modules/etl_cli.py}")
    private String scriptPath;

    @Value("${etl.timeout-minutes:120}")
    private long timeoutMinutes;

    private record ProcessResult(int exitCode, String payload, String logTail) {}

    /** Resultado da inspeção: o JSON devolvido pelo Python (ou null) e o fim do log. */
    public record Inspecao(String json, String logTail) {}

    @Async("etlExecutor")
    public void run(Long jobId, Path workDir, List<String> municipios, boolean incluirConsumidores) {
        EtlJob job = jobRepository.findById(jobId).orElseThrow();
        job.setStatus(EtlJobStatus.RUNNING);
        job.setStartedAt(Instant.now());
        job.setStage("Preparando o arquivo");
        jobRepository.save(job);

        try {
            // O Python lê a .gdb direto do .zip (GDAL /vsizip/): descompactar os
            // ~2,4 GB levava mais de 2 minutos e a leitura do zip dá o mesmo resultado (#TG-143).
            Path zip = workDir.resolve(ZIP).toAbsolutePath();
            if (!Files.isRegularFile(zip)) {
                throw new IOException("Arquivo enviado não encontrado no servidor. Envie de novo.");
            }
            List<String> comando = new ArrayList<>(List.of(
                    "--gdb", zip.toString(), "--municipios", String.join(",", municipios)));
            if (!incluirConsumidores) {
                comando.add("--sem-consumidores");
            }
            ProcessResult result = executarPython(comando, RESULT_PREFIX, timeoutMinutes,
                    etapa -> atualizarEtapa(job, etapa));

            job.setLogTail(result.logTail());
            if (result.exitCode() == 0 && result.payload() != null) {
                job.setStatus(EtlJobStatus.SUCCESS);
                job.setSummaryJson(result.payload());
            } else {
                job.setStatus(EtlJobStatus.FAILED);
                job.setErrorMessage("O processo de ETL terminou com código " + result.exitCode()
                        + ". Veja o log para detalhes.");
            }
        } catch (Exception e) {
            log.error("Falha no ETL (job {})", jobId, e);
            job.setStatus(EtlJobStatus.FAILED);
            job.setErrorMessage(e.getMessage());
        } finally {
            job.setStage(null);
            job.setWorkDir(null);
            job.setFinishedAt(Instant.now());
            jobRepository.save(job);
            apagarDiretorio(workDir);
        }
    }

    /** Lista distribuidora e municípios (etl_cli.py --inspecionar), lendo o .zip ou a .gdb, sem gravar nada. */
    public Inspecao inspecionar(Path zipOuGdb) throws IOException, InterruptedException {
        ProcessResult r = executarPython(List.of("--inspecionar", "--gdb", zipOuGdb.toAbsolutePath().toString()),
                INSPECAO_PREFIX, INSPECAO_TIMEOUT_MINUTOS, etapa -> { });
        return new Inspecao(r.exitCode() == 0 ? r.payload() : null, r.logTail());
    }

    private void atualizarEtapa(EtlJob job, String etapa) {
        job.setStage(etapa.length() > 120 ? etapa.substring(0, 120) : etapa);
        jobRepository.save(job);
    }

    private ProcessResult executarPython(List<String> argumentos, String prefixoResultado, long timeout,
                                         Consumer<String> onEtapa) throws IOException, InterruptedException {
        Path script = Path.of(scriptPath).toAbsolutePath().normalize();
        if (!Files.isRegularFile(script)) {
            throw new IOException("Script de ETL não encontrado: " + script + " (propriedade etl.script-path)");
        }

        List<String> comando = new ArrayList<>(List.of(pythonExecutable, script.getFileName().toString()));
        comando.addAll(argumentos);

        ProcessBuilder pb = new ProcessBuilder(comando);
        pb.directory(script.getParent().toFile());
        pb.redirectErrorStream(true);
        pb.environment().put("PYTHONUNBUFFERED", "1");
        pb.environment().put("PYTHONIOENCODING", "utf-8");
        pb.environment().put("ETL_DB_URL", montarEtlDbUrl());

        Process process = pb.start();

        Thread watchdog = new Thread(() -> {
            try {
                if (!process.waitFor(timeout, TimeUnit.MINUTES)) {
                    process.destroyForcibly();
                }
            } catch (InterruptedException ignored) {
                Thread.currentThread().interrupt();
            }
        }, "etl-watchdog");
        watchdog.setDaemon(true);
        watchdog.start();

        Deque<String> tail = new ArrayDeque<>();
        String payload = null;
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                if (line.startsWith(prefixoResultado)) {
                    payload = line.substring(prefixoResultado.length());
                } else if (line.startsWith(ETAPA_PREFIX)) {
                    String etapa = line.substring(ETAPA_PREFIX.length()).trim();
                    if (!etapa.isEmpty()) {
                        onEtapa.accept(etapa);
                    }
                }
                tail.addLast(line);
                if (tail.size() > LOG_TAIL_LINES) {
                    tail.removeFirst();
                }
                log.info("[etl] {}", line.length() > 500 ? line.substring(0, 500) + "..." : line);
            }
        }

        int exitCode = process.waitFor();
        return new ProcessResult(exitCode, payload, String.join("\n", tail));
    }

    private String montarEtlDbUrl() throws IOException {
        String jdbcUrl = dataSourceProperties.getUrl();
        if (jdbcUrl == null || !jdbcUrl.startsWith("jdbc:postgresql:")) {
            throw new IOException("spring.datasource.url ausente ou não é PostgreSQL; "
                    + "não foi possível configurar o banco do ETL.");
        }

        URI uri;
        try {
            uri = new URI(jdbcUrl.substring("jdbc:".length()));
        } catch (URISyntaxException e) {
            throw new IOException("spring.datasource.url em formato inválido.");
        }
        String path = uri.getRawPath();
        if (uri.getHost() == null || path == null || path.length() <= 1) {
            throw new IOException("spring.datasource.url precisa ter host e nome do banco.");
        }
        int port = uri.getPort() == -1 ? 5432 : uri.getPort();

        Map<String, String> params = new LinkedHashMap<>();
        if (uri.getRawQuery() != null) {
            for (String par : uri.getRawQuery().split("&")) {
                int i = par.indexOf('=');
                if (i > 0) {
                    params.put(par.substring(0, i), par.substring(i + 1));
                }
            }
        }
        if (!params.containsKey("sslmode") && "true".equalsIgnoreCase(params.get("ssl"))) {
            params.put("sslmode", "require");
        }
        List<String> query = new ArrayList<>();
        for (String chave : PARAMS_LIBPQ) {
            if (params.containsKey(chave)) {
                query.add(chave + "=" + params.get(chave));
            }
        }

        StringBuilder url = new StringBuilder("postgresql+psycopg2://");
        String user = dataSourceProperties.getUsername();
        String senha = dataSourceProperties.getPassword();
        if (user != null && !user.isBlank()) {
            url.append(codificar(user));
            if (senha != null) {
                url.append(':').append(codificar(senha));
            }
            url.append('@');
        }
        url.append(uri.getHost()).append(':').append(port).append(path);
        if (!query.isEmpty()) {
            url.append('?').append(String.join("&", query));
        }

        log.info("[etl] banco do ETL (herdado do backend): {}:{}{}", uri.getHost(), port, path);
        return url.toString();
    }

    private static String codificar(String valor) {
        return URLEncoder.encode(valor, StandardCharsets.UTF_8).replace("+", "%20");
    }

    void apagarDiretorio(Path dir) {
        if (dir == null || !Files.exists(dir)) {
            return;
        }
        try (Stream<Path> paths = Files.walk(dir)) {
            paths.sorted(Comparator.reverseOrder()).forEach(p -> p.toFile().delete());
        } catch (IOException e) {
            log.warn("Não foi possível apagar o diretório temporário {}", dir, e);
        }
    }
}
