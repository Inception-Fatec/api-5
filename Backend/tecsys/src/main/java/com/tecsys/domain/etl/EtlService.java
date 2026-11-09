package com.tecsys.domain.etl;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.etl.dto.EtlJobResponseDto;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.NestedExceptionUtils;
import org.springframework.core.task.TaskRejectedException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Stream;

@Slf4j
@Service
@RequiredArgsConstructor
public class EtlService {

    /** Upload inspecionado que ninguém iniciou nesse prazo é descartado (libera o disco). */
    static final Duration PRAZO_ESCOLHA = Duration.ofHours(6);
    static final String MSG_EXPIRADO =
            "Upload descartado: os municípios não foram escolhidos a tempo. Envie o arquivo de novo.";
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private static final Pattern CODIGO_IBGE = Pattern.compile("^\\d{7}$");
    private static final String INDICE_UM_ATIVO = "uq_etl_jobs_um_ativo";
    private static final String MSG_EM_ANDAMENTO =
            "Já existe um ETL em andamento. Aguarde a conclusão para enviar outro arquivo.";

    private final EtlJobRepository jobRepository;
    private final EtlRunner etlRunner;

    public EtlJobResponseDto startGdbUpload(MultipartFile file, List<String> municipios,
                                            boolean incluirConsumidores, Long userId) {
        // Sem municípios: fluxo em duas etapas da tela (#TG-143). Com municípios:
        // carga direta, mantida para scripts e chamadas pela API.
        if (municipios == null || municipios.stream().allMatch(m -> m == null || m.isBlank())) {
            return receberParaInspecao(file, userId);
        }
        List<String> codigos = validarMunicipios(municipios);
        String filename = validarArquivo(file);

        EtlJob job = reservarExecucao(filename, file.getSize(), codigos, userId);

        Path workDir;
        try {
            workDir = salvarUpload(file);
        } catch (RuntimeException e) {
            marcarFalha(job, e.getMessage());
            throw e;
        }

        try {
            etlRunner.run(job.getId(), workDir, codigos, incluirConsumidores);
        } catch (TaskRejectedException e) {
            apagar(workDir);
            marcarFalha(job, MSG_EM_ANDAMENTO);
            throw new BusinessRuleException(MSG_EM_ANDAMENTO);
        } catch (RuntimeException e) {
            apagar(workDir);
            marcarFalha(job, "Não foi possível iniciar o ETL: " + e.getMessage());
            throw new BusinessRuleException("Não foi possível iniciar o ETL. Tente novamente.");
        }
        return EtlJobResponseDto.fromEntity(job);
    }

    /**
     * Etapa 1 (#TG-143): guarda o arquivo, descompacta e lê da .gdb a
     * distribuidora e os municípios presentes. A carga fica aguardando a escolha.
     */
    private EtlJobResponseDto receberParaInspecao(MultipartFile file, Long userId) {
        String filename = validarArquivo(file);
        EtlJob job = jobRepository.saveAndFlush(EtlJob.builder()
                .status(EtlJobStatus.INSPECTING)
                .originalFilename(filename)
                .fileSizeBytes(file.getSize())
                .municipios("")
                .createdBy(userId)
                .stage("Lendo o arquivo")
                .build());

        Path workDir = null;
        try {
            workDir = salvarUpload(file);
            // Lê a .gdb direto do .zip (GDAL /vsizip/): não descompacta agora, então
            // o upload em espera ocupa só o .zip no disco e a análise leva segundos.
            EtlRunner.Inspecao inspecao = etlRunner.inspecionar(workDir.resolve(EtlRunner.ZIP));
            if (inspecao.json() == null) {
                job.setLogTail(inspecao.logTail());
                throw new BusinessRuleException(
                        "Não foi possível ler a geodatabase: confira se o .zip é da BDGD da ANEEL.");
            }
            job.setInspectionJson(inspecao.json());
            job.setWorkDir(workDir.toString());
            job.setStage(null);
            job.setStatus(EtlJobStatus.AWAITING_SELECTION);
            return EtlJobResponseDto.fromEntity(jobRepository.save(job));
        } catch (BusinessRuleException e) {
            apagar(workDir);
            marcarFalha(job, e.getMessage());
            throw e;
        } catch (IOException e) {
            apagar(workDir);
            marcarFalha(job, e.getMessage());
            throw new BusinessRuleException(e.getMessage());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            apagar(workDir);
            marcarFalha(job, "Inspeção interrompida.");
            throw new BusinessRuleException("Inspeção do arquivo interrompida. Tente novamente.");
        }
    }

    /** Etapa 2 (#TG-143): municípios escolhidos entre os da .gdb; a carga começa. */
    public EtlJobResponseDto iniciarCarga(Long id, List<String> municipios, boolean incluirConsumidores) {
        EtlJob job = buscar(id);
        if (job.getStatus() != EtlJobStatus.AWAITING_SELECTION) {
            throw new BusinessRuleException("Esta carga não está aguardando a escolha dos municípios.");
        }
        List<String> codigos = validarMunicipios(municipios);
        Set<String> doArquivo = municipiosDaInspecao(job);
        List<String> fora = codigos.stream().filter(c -> !doArquivo.contains(c)).toList();
        if (!fora.isEmpty()) {
            throw new BusinessRuleException("Municípios que não estão no arquivo: " + fora);
        }

        Path workDir = Path.of(job.getWorkDir());
        job.setMunicipios(String.join(",", codigos));
        job.setStatus(EtlJobStatus.PENDING);
        job.setStage("Na fila");
        try {
            jobRepository.saveAndFlush(job);
        } catch (DataIntegrityViolationException e) {
            String causa = NestedExceptionUtils.getMostSpecificCause(e).getMessage();
            if (causa != null && causa.contains(INDICE_UM_ATIVO)) {
                throw new BusinessRuleException(
                        "Já existe um ETL em andamento. Aguarde a conclusão e clique em Iniciar carga de novo.");
            }
            throw e;
        }

        try {
            etlRunner.run(job.getId(), workDir, codigos, incluirConsumidores);
        } catch (TaskRejectedException e) {
            apagar(workDir);
            marcarFalha(job, MSG_EM_ANDAMENTO);
            throw new BusinessRuleException(MSG_EM_ANDAMENTO);
        }
        return EtlJobResponseDto.fromEntity(job);
    }

    /** Descarta um upload que aguardava a escolha dos municípios. */
    public EtlJobResponseDto cancelar(Long id) {
        EtlJob job = buscar(id);
        if (job.getStatus() != EtlJobStatus.AWAITING_SELECTION) {
            throw new BusinessRuleException("Só é possível cancelar uma carga que ainda não começou.");
        }
        descartar(job, "Cancelado antes de iniciar a carga.");
        return EtlJobResponseDto.fromEntity(job);
    }

    /** Uploads esquecidos aguardando escolha ocupam o disco: descarta depois do prazo. */
    @Scheduled(fixedDelayString = "PT30M", initialDelayString = "PT5M")
    public void descartarUploadsExpirados() {
        Instant limite = Instant.now().minus(PRAZO_ESCOLHA);
        for (EtlJob job : jobRepository.findByStatusAndCreatedAtBefore(EtlJobStatus.AWAITING_SELECTION, limite)) {
            log.info("Descartando upload {} aguardando escolha desde {}", job.getId(), job.getCreatedAt());
            descartar(job, MSG_EXPIRADO);
        }
    }

    void descartar(EtlJob job, String mensagem) {
        if (job.getWorkDir() != null) {
            apagar(Path.of(job.getWorkDir()));
        }
        job.setWorkDir(null);
        job.setStage(null);
        job.setStatus(EtlJobStatus.CANCELED);
        job.setErrorMessage(mensagem);
        job.setFinishedAt(Instant.now());
        jobRepository.save(job);
    }

    private Set<String> municipiosDaInspecao(EtlJob job) {
        Set<String> codigos = new HashSet<>();
        try {
            JsonNode lista = MAPPER.readTree(job.getInspectionJson()).path("municipios");
            for (JsonNode m : lista) {
                codigos.add(m.path("codigo").asText());
            }
        } catch (Exception e) {
            throw new BusinessRuleException("Inspeção do arquivo ilegível. Envie o arquivo de novo.");
        }
        return codigos;
    }

    private EtlJob buscar(Long id) {
        return jobRepository.findById(id)
                .orElseThrow(() -> new BusinessRuleException("Execução de ETL não encontrada."));
    }

    public EtlJobResponseDto getJob(Long id) {
        return jobRepository.findById(id)
                .map(EtlJobResponseDto::fromEntity)
                .orElseThrow(() -> new BusinessRuleException("Execução de ETL não encontrada."));
    }

    /**
     * Últimas cargas (de qualquer ADM), mais novas primeiro (#TG-141). O log
     * só vai junto nas que falharam, para a lista não ficar pesada.
     */
    public List<EtlJobResponseDto> listarJobs() {
        return jobRepository.findTop30ByOrderByCreatedAtDescIdDesc().stream()
                .map(job -> job.getStatus() == EtlJobStatus.FAILED
                        ? EtlJobResponseDto.fromEntity(job)
                        : EtlJobResponseDto.semLog(job))
                .toList();
    }

    private EtlJob reservarExecucao(String filename, long tamanho, List<String> codigos, Long userId) {
        try {
            return jobRepository.saveAndFlush(EtlJob.builder()
                    .status(EtlJobStatus.PENDING)
                    .originalFilename(filename)
                    .fileSizeBytes(tamanho)
                    .municipios(String.join(",", codigos))
                    .createdBy(userId)
                    .build());
        } catch (DataIntegrityViolationException e) {
            String causa = NestedExceptionUtils.getMostSpecificCause(e).getMessage();
            if (causa != null && causa.contains(INDICE_UM_ATIVO)) {
                throw new BusinessRuleException(MSG_EM_ANDAMENTO);
            }
            throw e;
        }
    }

    private void marcarFalha(EtlJob job, String mensagem) {
        job.setStage(null);
        job.setWorkDir(null);
        job.setStatus(EtlJobStatus.FAILED);
        job.setErrorMessage(mensagem);
        job.setFinishedAt(Instant.now());
        jobRepository.save(job);
    }

    private List<String> validarMunicipios(List<String> municipios) {
        if (municipios == null || municipios.isEmpty()) {
            throw new BusinessRuleException("Informe ao menos um código IBGE de município.");
        }
        List<String> codigos = municipios.stream()
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(java.util.stream.Collectors.collectingAndThen(
                        java.util.stream.Collectors.toCollection(LinkedHashSet::new), List::copyOf));

        if (codigos.isEmpty()) {
            throw new BusinessRuleException("Informe ao menos um código IBGE de município.");
        }
        List<String> invalidos = codigos.stream().filter(c -> !CODIGO_IBGE.matcher(c).matches()).toList();
        if (!invalidos.isEmpty()) {
            throw new BusinessRuleException("Códigos IBGE inválidos (esperado 7 dígitos): " + invalidos);
        }
        return codigos;
    }

    private String validarArquivo(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessRuleException("Envie um arquivo .zip contendo a pasta .gdb.");
        }
        String filename = StringUtils.cleanPath(file.getOriginalFilename() == null ? "" : file.getOriginalFilename());
        if (!filename.toLowerCase().endsWith(".zip")) {
            throw new BusinessRuleException("Formato inválido: compacte a pasta .gdb em um arquivo .zip.");
        }
        return filename;
    }

    private Path salvarUpload(MultipartFile file) {
        Path workDir = null;
        try {
            workDir = Files.createTempDirectory("etl-gdb-");
            file.transferTo(workDir.resolve("upload.zip"));
            return workDir;
        } catch (IOException e) {
            apagar(workDir);
            throw new BusinessRuleException("Falha ao salvar o arquivo enviado.");
        }
    }

    private void apagar(Path dir) {
        if (dir == null) {
            return;
        }
        try (Stream<Path> paths = Files.walk(dir)) {
            paths.sorted(Comparator.reverseOrder()).forEach(p -> p.toFile().delete());
        } catch (IOException ignored) {
        }
    }
}