package com.tecsys.domain.etl;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.etl.dto.CsvRejectionDto;
import com.tecsys.domain.etl.dto.ExternalPointsImportResponseDto;
import com.tecsys.domain.etl.dto.ExternalPointsListResponseDto;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.StringReader;
import java.math.BigDecimal;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.Charset;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

@Slf4j
@Service
@RequiredArgsConstructor
public class ExternalPointsImportService {

    private static final Pattern CODIGO_IBGE = Pattern.compile("^\\d{7}$");
    private static final char SEPARADOR = ';';
    private static final int TAMANHO_MAX_ID = 100;
    private static final Set<String> PAPEIS_VALIDOS = Set.of("candidato", "ponto_a_cobrir", "interesse");
    private static final List<String> COLUNAS_OBRIGATORIAS = List.of("id", "latitude", "longitude", "papel");
    private static final Pattern CODIGO_DISTRIBUIDORA = Pattern.compile("^\\d{1,10}$");

    /** Rejeições guardadas no histórico de cada importação. */
    static final int MAX_REJEICOES_HISTORICO = 500;

    /** Pontos devolvidos nos detalhes de uma importação. */
    static final int LIMITE_PONTOS_PADRAO = 1000;
    static final int LIMITE_PONTOS_MAXIMO = 5000;

    /** Chave do summary com os ids gravados pela importação. */
    public static final String CHAVE_IMPORTADOS = "importados";

    private final ExternalPointJdbcRepository repository;
    private final EtlJobRepository jobRepository;
    private final ObjectMapper objectMapper;

    private record Cabecalho(int totalColunas, int id, int latitude, int longitude, int papel, int descricao) {
    }

    public ExternalPointsImportResponseDto importar(MultipartFile file, String distribuidora,
                                                    String municipio, Long userId) {
        String dist = validarDistribuidora(distribuidora);
        String mun = validarMunicipio(municipio);
        validarArquivo(file);

        // Cada importação entra no histórico de cargas da tela de ETL (#TG-90),
        // como um job já terminado: sucesso com o resumo, ou falha com o motivo.
        Instant inicio = Instant.now();
        try {
            Resultado r = processar(file, dist, mun, userId);
            registrarNoHistorico(file, dist, mun, userId, inicio, EtlJobStatus.SUCCESS, r.resposta(), r.inseridos(), null);
            return r.resposta();
        } catch (BusinessRuleException e) {
            registrarNoHistorico(file, dist, mun, userId, inicio, EtlJobStatus.FAILED, null, List.of(), e.getMessage());
            throw e;
        }
    }

    /**
     * Pontos gravados por uma importação (detalhes do item no histórico de
     * cargas), pelos ids guardados no summary do job — sem coluna nova em
     * external_points. {@code limite} vai de 1 a 5000 (padrão 1000).
     */
    public ExternalPointsListResponseDto listarPontosDaImportacao(long jobId, Integer limite) {
        int lim = limite == null ? LIMITE_PONTOS_PADRAO : Math.max(1, Math.min(limite, LIMITE_PONTOS_MAXIMO));
        JsonNode resumo = jobRepository.findById(jobId).map(this::lerResumo).orElse(null);
        if (resumo == null || !"csv".equals(resumo.path("tipo").asText()) || !resumo.has(CHAVE_IMPORTADOS)) {
            // .zip, job inexistente ou importação anterior ao histórico guardar os ids.
            return new ExternalPointsListResponseDto(0, lim, List.of());
        }
        List<String> ids = new ArrayList<>();
        resumo.get(CHAVE_IMPORTADOS).forEach(n -> ids.add(n.asText()));
        long total = resumo.path("importadas").asLong(ids.size());
        return new ExternalPointsListResponseDto(total, lim,
                repository.listarPorIds(resumo.path("distribuidora").asText(), ids.subList(0, Math.min(lim, ids.size()))));
    }

    private JsonNode lerResumo(EtlJob job) {
        try {
            return job.getSummaryJson() == null ? null : objectMapper.readTree(job.getSummaryJson());
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Grava a importação em etl_jobs (já concluída), com {@code "tipo": "csv"} no
     * summary para a tela diferenciar das cargas da .gdb, e os ids gravados agora
     * (para os detalhes listarem as linhas importadas). Falhar aqui não desfaz a
     * importação: os pontos já foram gravados e o histórico é só informativo.
     */
    private EtlJob registrarNoHistorico(MultipartFile file, String dist, String mun, Long userId, Instant inicio,
                                        EtlJobStatus status, ExternalPointsImportResponseDto resposta,
                                        List<String> inseridos, String erro) {
        try {
            Map<String, Object> resumo = new LinkedHashMap<>();
            resumo.put("tipo", "csv");
            resumo.put("distribuidora", dist);
            resumo.put("municipio", mun);
            if (resposta != null) {
                resumo.put("total", resposta.total());
                resumo.put("importadas", resposta.importadas());
                resumo.put("jaExistentes", resposta.jaExistentes());
                resumo.put("rejeitadas", resposta.rejeitadas());
                // O histórico lista 30 jobs com o summary: guarda só as primeiras
                // rejeições para a resposta não crescer sem limite.
                List<CsvRejectionDto> rejeicoes = resposta.rejeicoes();
                resumo.put("rejeicoes", rejeicoes.subList(0, Math.min(rejeicoes.size(), MAX_REJEICOES_HISTORICO)));
                if (rejeicoes.size() > MAX_REJEICOES_HISTORICO) {
                    resumo.put("rejeicoesOmitidas", rejeicoes.size() - MAX_REJEICOES_HISTORICO);
                }
                // Até o máximo que os detalhes mostram; a listagem do histórico
                // não devolve esta chave (ver EtlJobResponseDto).
                resumo.put(CHAVE_IMPORTADOS, inseridos.subList(0, Math.min(inseridos.size(), LIMITE_PONTOS_MAXIMO)));
            }
            return jobRepository.save(EtlJob.builder()
                    .status(status)
                    .originalFilename(StringUtils.cleanPath(
                            file.getOriginalFilename() == null ? "" : file.getOriginalFilename()))
                    .fileSizeBytes(file.getSize())
                    .municipios(mun)
                    .summaryJson(objectMapper.writeValueAsString(resumo))
                    .errorMessage(erro)
                    .createdBy(userId)
                    .startedAt(inicio)
                    .finishedAt(Instant.now())
                    .build());
        } catch (Exception e) {
            log.warn("Não foi possível registrar a importação de CSV no histórico: {}", e.getMessage());
            return null;
        }
    }

    /** Resposta da importação e os ids gravados agora (para ligar ao histórico). */
    private record Resultado(ExternalPointsImportResponseDto resposta, List<String> inseridos) {
    }

    private Resultado processar(MultipartFile file, String dist, String mun, Long userId) {
        List<ExternalPointRow> validos = new ArrayList<>();
        List<CsvRejectionDto> rejeicoes = new ArrayList<>();
        Map<String, Integer> idsAceitos = new HashMap<>();
        int total = 0;

        try (BufferedReader reader = new BufferedReader(new StringReader(decodificar(file)))) {

            Cabecalho cabecalho = lerCabecalho(reader.readLine());

            String linha;
            int numeroLinha = 1;
            while ((linha = reader.readLine()) != null) {
                numeroLinha++;
                if (linha.isBlank()) {
                    continue;
                }
                total++;
                validarLinha(linha, numeroLinha, cabecalho, idsAceitos, validos, rejeicoes);
            }
        } catch (IOException e) {
            throw new BusinessRuleException("Falha ao ler o arquivo enviado.");
        }

        if (total == 0) {
            throw new BusinessRuleException("O CSV não possui linhas de dados.");
        }

        List<String> inseridos = validos.isEmpty() ? List.of() : repository.inserirNovos(dist, mun, validos, userId);
        int importadas = inseridos.size();
        int jaExistentes = validos.size() - importadas;

        return new Resultado(
                new ExternalPointsImportResponseDto(total, importadas, jaExistentes, rejeicoes.size(), rejeicoes),
                inseridos);
    }

    /** UTF-8 primeiro; se o arquivo não for UTF-8 válido (ex.: Excel em português), lê como Windows-1252. */
    private String decodificar(MultipartFile file) throws IOException {
        byte[] bytes = file.getBytes();
        try {
            return StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes)).toString();
        } catch (CharacterCodingException e) {
            return Charset.forName("windows-1252").decode(ByteBuffer.wrap(bytes)).toString();
        }
    }

    private static String[] dividirLinha(String linha) {
        List<String> campos = new ArrayList<>();
        StringBuilder atual = new StringBuilder();
        boolean entreAspas = false;
        for (int i = 0; i < linha.length(); i++) {
            char ch = linha.charAt(i);
            if (ch == '"') {
                if (entreAspas && i + 1 < linha.length() && linha.charAt(i + 1) == '"') {
                    atual.append('"');
                    i++;
                } else {
                    entreAspas = !entreAspas;
                }
            } else if (ch == SEPARADOR && !entreAspas) {
                campos.add(atual.toString());
                atual.setLength(0);
            } else {
                atual.append(ch);
            }
        }
        campos.add(atual.toString());
        return campos.toArray(new String[0]);
    }

    private void validarLinha(String linha, int numeroLinha, Cabecalho cab, Map<String, Integer> idsAceitos,
                            List<ExternalPointRow> validos, List<CsvRejectionDto> rejeicoes) {
        String[] c = dividirLinha(linha);

        if (c.length != cab.totalColunas()) {
            String idBruto = c.length > cab.id() ? c[cab.id()].trim() : "";
            rejeicoes.add(new CsvRejectionDto(numeroLinha, idBruto,
                    "número de colunas diferente do cabeçalho (esperado " + cab.totalColunas()
                            + ", encontrado " + c.length + ")"));
            return;
        }

        List<String> erros = new ArrayList<>();

        String id = c[cab.id()].trim();
        if (id.isEmpty()) {
            erros.add("id vazio");
        } else if (id.length() > TAMANHO_MAX_ID) {
            erros.add("id excede " + TAMANHO_MAX_ID + " caracteres");
        } else if (idsAceitos.containsKey(id)) {
            erros.add("id duplicado no arquivo (já usado na linha " + idsAceitos.get(id) + ")");
        }

        String papelBruto = c[cab.papel()].trim();
        String papel = papelBruto.toLowerCase(Locale.ROOT);
        if (!PAPEIS_VALIDOS.contains(papel)) {
            erros.add("papel inválido (use candidato, ponto_a_cobrir ou interesse): '" + papelBruto + "'");
        }

        Double latitude = lerCoordenada("latitude", c[cab.latitude()].trim(), -90, 90, erros);
        Double longitude = lerCoordenada("longitude", c[cab.longitude()].trim(), -180, 180, erros);

        if (!erros.isEmpty()) {
            rejeicoes.add(new CsvRejectionDto(numeroLinha, id, String.join("; ", erros)));
            return;
        }

        String descricao = cab.descricao() >= 0 ? c[cab.descricao()].trim() : "";
        validos.add(new ExternalPointRow(id, papel, descricao.isEmpty() ? null : descricao, latitude, longitude));
        idsAceitos.put(id, numeroLinha);
    }

    private Double lerCoordenada(String nome, String bruto, int min, int max, List<String> erros) {
        if (bruto.isEmpty()) {
            erros.add(nome + " vazia");
            return null;
        }
        if (bruto.contains(",") && bruto.contains(".")) {
            erros.add(nome + " em formato ambíguo (use só um separador decimal, ponto ou vírgula): " + bruto);
            return null;
        }
        BigDecimal valor;
        try {
            valor = new BigDecimal(bruto.replace(',', '.'));
        } catch (NumberFormatException e) {
            erros.add(nome + " não numérica: " + bruto);
            return null;
        }
        if (valor.compareTo(BigDecimal.valueOf(min)) < 0 || valor.compareTo(BigDecimal.valueOf(max)) > 0) {
            erros.add(nome + " fora da faixa (" + min + " a " + max + "): " + bruto);
            return null;
        }
        return valor.doubleValue();
    }

    private Cabecalho lerCabecalho(String linha) {
        if (linha == null || linha.isBlank()) {
            throw new BusinessRuleException("O CSV está vazio.");
        }
        if (linha.charAt(0) == '\uFEFF') {
            linha = linha.substring(1);
        }
        String[] nomes = dividirLinha(linha);
        Map<String, Integer> posicoes = new HashMap<>();
        for (int i = 0; i < nomes.length; i++) {
            posicoes.putIfAbsent(nomes[i].trim().toLowerCase(Locale.ROOT), i);
        }

        List<String> faltando = COLUNAS_OBRIGATORIAS.stream().filter(col -> !posicoes.containsKey(col)).toList();
        if (!faltando.isEmpty()) {
            throw new BusinessRuleException("Cabeçalho inválido: faltam as colunas " + faltando
                    + ". O separador deve ser ';'.");
        }
        return new Cabecalho(nomes.length, posicoes.get("id"), posicoes.get("latitude"),
                posicoes.get("longitude"), posicoes.get("papel"), posicoes.getOrDefault("descricao", -1));
    }

    private String validarDistribuidora(String distribuidora) {
        String dist = distribuidora == null ? "" : distribuidora.trim();
        if (!CODIGO_DISTRIBUIDORA.matcher(dist).matches()) {
            throw new BusinessRuleException(
                    "Código da distribuidora inválido (informe o código numérico, ex.: 391): " + dist);
        }
        return dist;
    }

    private String validarMunicipio(String municipio) {
        String mun = municipio == null ? "" : municipio.trim();
        if (!CODIGO_IBGE.matcher(mun).matches()) {
            throw new BusinessRuleException("Código IBGE inválido (esperado 7 dígitos): " + mun);
        }
        return mun;
    }

    private void validarArquivo(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessRuleException("Envie um arquivo .csv.");
        }
        String filename = StringUtils.cleanPath(file.getOriginalFilename() == null ? "" : file.getOriginalFilename());
        if (!filename.toLowerCase(Locale.ROOT).endsWith(".csv")) {
            throw new BusinessRuleException("Formato inválido: envie um arquivo .csv.");
        }
    }
}