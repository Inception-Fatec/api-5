package com.tecsys.domain.decision.model;

 
public record CoverageRelation(

        CandidateType candidateType,
        String candidateId,

        VoltageLevel pointLevel,
        String pointId

) {
}