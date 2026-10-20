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
        List<String> bairroNames

) {

    public DecisionCriteria {
        distCodes = safeList(distCodes);
        munCodes = safeList(munCodes);
        conjCodes = safeList(conjCodes);
        subCodes = safeList(subCodes);
        targetLevels = safeList(targetLevels);
        clasSub = safeList(clasSub);
        cnaeCodes = safeList(cnaeCodes);
        bairroNames = safeList(bairroNames);
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