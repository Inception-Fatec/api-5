package com.tecsys.domain.decision;

import com.tecsys.domain.decision.model.CandidateType;
import com.tecsys.domain.decision.model.CoverageAssignment;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.CoverageRelation;
import com.tecsys.domain.decision.model.DecisionResult;
import com.tecsys.domain.decision.model.GatewayCandidate;
import com.tecsys.domain.decision.model.SelectedGateway;
import com.tecsys.domain.decision.model.VoltageLevel;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.BitSet;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Component
public class DecisionEngine {

    public DecisionResult calculate(
            List<CoveragePoint> coveragePoints,
            List<GatewayCandidate> candidates,
            List<CoverageRelation> relations
    ) {

        int totalPoints = coveragePoints.size();
        int totalCandidates = candidates.size();

        
        if (totalPoints == 0) {

            return new DecisionResult(
                    0,
                    totalCandidates,
                    0,
                    0,
                    0.0,
                    List.of(),
                    List.of(),
                    List.of()
            );
        }

        
        Map<PointKey, Integer> pointIndexes =
                createPointIndexes(coveragePoints);

        
        Map<CandidateKey, Integer> candidateIndexes =
                createCandidateIndexes(candidates);

        
        List<BitSet> coverageByCandidate =
                createCoverageMatrix(
                        candidates.size(),
                        relations,
                        pointIndexes,
                        candidateIndexes
                );

        
        BitSet uncovered = new BitSet(totalPoints);

        uncovered.set(
                0,
                totalPoints
        );

        List<SelectedGateway> selectedGateways =
                new ArrayList<>();

        List<CoverageAssignment> assignments =
                new ArrayList<>();

        int coveredCount = 0;
        int gatewayOrder = 1;

        
        while (!uncovered.isEmpty()) {

            CandidateSelection best =
                    findBestCandidate(
                            candidates,
                            coverageByCandidate,
                            uncovered
                    );

            
            if (best == null || best.gain() == 0) {
                break;
            }

            GatewayCandidate selectedCandidate =
                    candidates.get(
                            best.candidateIndex()
                    );

            BitSet newlyCovered =
                    best.newlyCovered();

           
            for (
                    int pointIndex =
                    
            for (
                    int pointIndex =
                       newlyCovered.nextSetBit(0);

                    pointIndex >= 0;

                    pointIndex =
                            newlyCovered.nextSetBit(
                                    pointIndex + 1
                            )
            ) {

                CoveragePoint point =
                        coveragePoints.get(
                                pointIndex
                        );

                assignments.add(
                        new CoverageAssignment(
                                point,
                                selectedCandidate,
                                gatewayOrder
                        )
                );
            }

            
            uncovered.andNot(
                    newlyCovered
            );

            coveredCount +=
                    best.gain();

            double cumulativePercentage =
                    percentage(
                            coveredCount,
                            totalPoints
                    );

            selectedGateways.add(
                    new SelectedGateway(
                            gatewayOrder,
                            selectedCandidate,
                            best.gain(),
                            coveredCount,
                            cumulativePercentage
                    )
            );

            gatewayOrder++;
        }

        
        List<CoveragePoint> uncoveredPoints =
                new ArrayList<>();

        for (
                int pointIndex =
                        uncovered.nextSetBit(0);

                pointIndex >= 0;

                pointIndex =
                        uncovered.nextSetBit(
                                pointIndex + 1
                        )
        ) {

            uncoveredPoints.add(
                    coveragePoints.get(
                            pointIndex
                    )
            );
        }

        return new DecisionResult(
                totalPoints,
                totalCandidates,
                coveredCount,
                uncoveredPoints.size(),
                percentage(
                        coveredCount,
                        totalPoints
                ),
                selectedGateways,
                assignments,
                uncoveredPoints
        );
    }

    
    private CandidateSelection findBestCandidate(
            List<GatewayCandidate> candidates,
            List<BitSet> coverageByCandidate,
            BitSet uncovered
    ) {

        CandidateSelection best = null;

        for (
                int candidateIndex = 0;
                candidateIndex < candidates.size();
                candidateIndex++
        ) {

            BitSet newlyCovered =
                    (BitSet) coverageByCandidate
                            .get(candidateIndex)
                            .clone();

            
            newlyCovered.and(
                    uncovered
            );

            int gain =
                    newlyCovered.cardinality();

            if (gain == 0) {
                continue;
            }

            if (
                    best == null
                    || gain > best.gain()
                    || (
                        gain == best.gain()
                        && shouldReplaceOnTie(
                                candidates,
                                candidateIndex,
                                best.candidateIndex()
                        )
                    )
            ) {

                best = new CandidateSelection(
                        candidateIndex,
                        gain,
                        newlyCovered
                );
            }
        }

        return best;
    }

    
    private boolean shouldReplaceOnTie(
            List<GatewayCandidate> candidates,
            int candidateIndex,
            int currentBestIndex
    ) {

        GatewayCandidate candidate =
                candidates.get(
                        candidateIndex
                );

        GatewayCandidate currentBest =
                candidates.get(
                        currentBestIndex
                );

        String candidateKey =
                candidate.type().name()
                        + ":"
                        + candidate.id();

        String currentBestKey =
                currentBest.type().name()
                        + ":"
                        + currentBest.id();

        return candidateKey.compareTo(
                currentBestKey
        ) < 0;
    }

    private List<BitSet> createCoverageMatrix(
            int candidateCount,
            List<CoverageRelation> relations,
            Map<PointKey, Integer> pointIndexes,
            Map<CandidateKey, Integer> candidateIndexes
    ) {

        List<BitSet> matrix =
                new ArrayList<>(
                        candidateCount
                );

        for (
                int i = 0;
                i < candidateCount;
                i++
        ) {

            matrix.add(
                    new BitSet()
            );
        }

        for (CoverageRelation relation : relations) {

            CandidateKey candidateKey =
                    new CandidateKey(
                            relation.candidateType(),
                            relation.candidateId()
                    );

            PointKey pointKey =
                    new PointKey(
                            relation.pointLevel(),
                            relation.pointId()
                    );

            Integer candidateIndex =
                    candidateIndexes.get(
                            candidateKey
                    );

            Integer pointIndex =
                    pointIndexes.get(
                            pointKey
                    );

            
            if (
                    candidateIndex == null
                    || pointIndex == null
            ) {
                continue;
            }

            matrix.get(
                    candidateIndex
            ).set(
                    pointIndex
            );
        }

        return matrix;
    }

    private Map<PointKey, Integer> createPointIndexes(
            List<CoveragePoint> points
    ) {

        Map<PointKey, Integer> indexes =
                new HashMap<>();

        for (
                int index = 0;
                index < points.size();
                index++
        ) {

            CoveragePoint point =
                    points.get(index);

            indexes.put(
                    new PointKey(
                            point.level(),
                            point.id()
                    ),
                    index
            );
        }

        return indexes;
    }

    private Map<CandidateKey, Integer> createCandidateIndexes(
            List<GatewayCandidate> candidates
    ) {

        Map<CandidateKey, Integer> indexes =
                new HashMap<>();

        for (
                int index = 0;
                index < candidates.size();
                index++
        ) {

            GatewayCandidate candidate =
                    candidates.get(index);

            indexes.put(
                    new CandidateKey(
                            candidate.type(),
                            candidate.id()
                    ),
                    index
            );
        }

        return indexes;
    }

    private double percentage(
            int covered,
            int total
    ) {

        if (total == 0) {
            return 0.0;
        }

        return Math.round(
                (
                    covered
                    * 10000.0
                    / total
                )
        ) / 100.0;
    }

    
    private record PointKey(
            VoltageLevel level,
            String id
    ) {
    }

    private record CandidateKey(
            CandidateType type,
            String id
    ) {
    }

    private record CandidateSelection(
            int candidateIndex,
            int gain,
            BitSet newlyCovered
    ) {
    }
}