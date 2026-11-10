package com.tecsys.domain.etl;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.etl.dto.CsvRejectionDto;
import com.tecsys.domain.etl.dto.ExternalPointsImportResponseDto;
import lombok.RequiredArgsConstructor;
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
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
public class ExternalPointsImportService {

    private static final Pattern CODIGO_IBGE = Pattern.compile("^\\d{7}$");
    private static final char SEPARADOR = ';';
    private static final int TAMANHO_MAX_ID = 100;
    private static final Set<String> PAPEIS_VALIDOS = Set.of("candidato", "ponto_a_cobrir", "interesse");
    private static final List<String> COLUNAS_OBRIGATORIAS = List.of("id", "latitude", "longitude", "papel");
    private static final Pattern CODIGO_DISTRIBUIDORA = Pattern.compile("^\\d{1,10}$");

    private final ExternalPointJdbcRepository repository;

    private record Cabecalho(int totalColunas, int id, int latitude, int longitude, int papel, int descricao) {
    }

    public ExternalPointsImportResponseDto importar(MultipartFile file, String distribuidora,
                                                    String municipio, Long userId) {
        String dist = validarDistribuidora(distribuidora);
        String mun = validarMunicipio(municipio);
        validarArquivo(file);

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

        int importadas = validos.isEmpty() ? 0 : repository.inserirNovos(dist, mun, validos, userId);
        int jaExistentes = validos.size() - importadas;

        return new ExternalPointsImportResponseDto(total, importadas, jaExistentes, rejeicoes.size(), rejeicoes);
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