package com.tecsys.domain.decision.service;

import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.GatewayCandidate;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class LineOfSightService {

    private final ElevationService elevationService;
    private final BDGDHeightResolver heightResolver;

    public LineOfSightService(ElevationService elevationService, BDGDHeightResolver heightResolver) {
        this.elevationService = elevationService;
        this.heightResolver = heightResolver;
    }

    public boolean hasLineOfSight(
            GatewayCandidate candidate,
            CoveragePoint point,
            Map<String, Double> requestCache
    ) {
        // 1. Resolve as alturas reais da estrutura BDGD
        double hGateway = heightResolver.resolveGatewayHeight(candidate);
        double hPoint = heightResolver.resolvePointHeight(point);

        // 2. Altitude do terreno extraída do GeoTIFF + altura da estrutura BDGD
        double zStart = elevationService.getElevation(candidate.latitude(), candidate.longitude(), requestCache) + hGateway;
        double zEnd = elevationService.getElevation(point.latitude(), point.longitude(), requestCache) + hPoint;

        // 3. Checa a visada em 5 amostras intermediárias no raio de rádio
        int samples = 5;
        for (int i = 1; i < samples; i++) {
            double fraction = (double) i / samples;

            double sampleLat = candidate.latitude() + fraction * (point.latitude() - candidate.latitude());
            double sampleLng = candidate.longitude() + fraction * (point.longitude() - candidate.longitude());

            // Elevação calculada da linha de rádio
            double radioZ = zStart + fraction * (zEnd - zStart);

            // Elevação real do terreno no ponto amostrado
            double terrainZ = elevationService.getElevation(sampleLat, sampleLng, requestCache);

            // Se o morro/terreno for mais alto que a linha do rádio, o sinal é bloqueado!
            if (terrainZ > radioZ) {
                return false;
            }
        }

        return true; // Feixe de rádio desobstruído!
    }
}