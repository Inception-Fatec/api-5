package com.tecsys.domain.decision.model;

import java.util.List;

public record DecisionResult(

        int totalPoints,

        int totalCandidates,

        int coveredPoints,

        int uncoveredPoints,

        double coveragePercentage,

        List<SelectedGateway> selectedGateways,

        List<CoverageAssignment> coveredAssignments,

        List<CoveragePoint> uncoveredCoveragePoints

) {

    public DecisionResult {

        selectedGateways =
                List.copyOf(selectedGateways);

        coveredAssignments =
                List.copyOf(coveredAssignments);

        uncoveredCoveragePoints =
                List.copyOf(uncoveredCoveragePoints);
    }
}