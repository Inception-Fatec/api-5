package com.tecsys.domain.decision.model;

import java.util.List;

public record DecisionCriteria(

        List<String> distCodes,
        List<String> munCodes,
        List<String> conjCodes,
        List<String> subCodes,

        String polygonGeojson,

        List<VoltageLevel> targetLevels,

        List<String> clasSub,
        List<String> cnaeCodes,
        List<String> bairroNames,

        // Papéis por camada (#TG-92): tabelas de pontos a cobrir e de candidatos.
        List<String> coverageLayers,
        List<String> candidateLayers

) {

    /** Camadas que podem ser pontos a cobrir (consumidores). */
    public static final List<String> CAMADAS_COBERTURA = List.of("ucat_pj", "ucmt_pj", "ucbt");
    /** Camadas que podem ser candidatas a gateway. */
    public static final List<String> CAMADAS_CANDIDATAS = List.of("untrmt", "untrat", "ucat_pj", "ucmt_pj", "ucbt");
    public static final List<String> PADRAO_CANDIDATOS = List.of("untrmt", "untrat");

    public DecisionCriteria {
        distCodes = safeList(distCodes);
        munCodes = safeList(munCodes);
        conjCodes = safeList(conjCodes);
        subCodes = safeList(subCodes);
        targetLevels = safeList(targetLevels);
        clasSub = safeList(clasSub);
        cnaeCodes = safeList(cnaeCodes);
        bairroNames = safeList(bairroNames);
        coverageLayers = camadas(coverageLayers, CAMADAS_COBERTURA, CAMADAS_COBERTURA);
        candidateLayers = camadas(candidateLayers, CAMADAS_CANDIDATAS, PADRAO_CANDIDATOS);
    }

    /** Mesmos filtros de sempre, com os papéis padrão (consumidores e transformadores). */
    public DecisionCriteria(List<String> distCodes, List<String> munCodes, List<String> conjCodes,
                            List<String> subCodes, String polygonGeojson, List<VoltageLevel> targetLevels,
                            List<String> clasSub, List<String> cnaeCodes, List<String> bairroNames) {
        this(distCodes, munCodes, conjCodes, subCodes, polygonGeojson, targetLevels,
                clasSub, cnaeCodes, bairroNames, null, null);
    }

    public boolean isCoverageLayer(String table) {
        return coverageLayers.contains(table);
    }

    public boolean isCandidateLayer(String table) {
        return candidateLayers.contains(table);
    }

    /** Camadas válidas pedidas, na ordem de {@code permitidas}; nada válido = padrão. */
    private static List<String> camadas(List<String> pedidas, List<String> permitidas, List<String> padrao) {
        if (pedidas == null) return padrao;
        List<String> normalizadas = pedidas.stream()
                .filter(c -> c != null)
                .map(c -> c.trim().toLowerCase())
                .toList();
        List<String> validas = permitidas.stream().filter(normalizadas::contains).toList();
        return validas.isEmpty() ? padrao : validas;
    }

    public boolean hasPolygon() {
        return polygonGeojson != null && !polygonGeojson.isBlank();
    }

    public boolean hasMunicipalityFilter() {
        return !munCodes.isEmpty();
    }

    public boolean hasDistributorFilter() {
        return !distCodes.isEmpty();
    }

    private static <T> List<T> safeList(List<T> values) {
        return values == null ? List.of() : List.copyOf(values);
    }
}