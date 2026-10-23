package com.tecsys.domain.decision.service;

import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.GatewayCandidate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class LineOfSightService {

    private final ElevationService elevationService;
    private final BDGDHeightResolver heightResolver;
    private final double obstructionToleranceMeters;
    private final int losSamples;

    @Autowired
    public LineOfSightService(
            ElevationService elevationService,
            BDGDHeightResolver heightResolver,
            @Value("${app.elevation.obstruction-tolerance-meters:1.5}") double obstructionToleranceMeters,
            @Value("${app.elevation.los-samples:5}") int losSamples
    ) {
        this.elevationService = elevationService;
        this.heightResolver = heightResolver;
        this.obstructionToleranceMeters = obstructionToleranceMeters;
        this.losSamples = losSamples;
    }

    /**
     * Construtor para testes unitários com valores padrão de tolerância (1.5m) e amostras (5).
     */
    public LineOfSightService(ElevationService elevationService, BDGDHeightResolver heightResolver) {
        this(elevationService, heightResolver, 1.5, 5);
    }

    /**
     * Valida a visada direta (Line of Sight) utilizando o raster da Bounding Box carregado em memória.
     * Considera a margem de tolerância e a quantidade configurável de amostras intermediárias.
     */
    public boolean hasLineOfSight(
            GatewayCandidate candidate,
            CoveragePoint point,
            AreaElevationRaster elevationRaster
    ) {
        // 1. Resolve as alturas reais da estrutura BDGD
        double hGateway = heightResolver.resolveGatewayHeight(candidate);
        double hPoint = heightResolver.resolvePointHeight(point);

        // 2. Altitude do terreno extraída do raster + altura da estrutura BDGD
        double zStart = elevationRaster.getElevation(candidate.latitude(), candidate.longitude()) + hGateway;
        double zEnd = elevationRaster.getElevation(point.latitude(), point.longitude()) + hPoint;

        // 3. Checa a visada em amostras intermediárias no trajeto do rádio
        int samples = Math.max(2, losSamples);
        for (int i = 1; i < samples; i++) {
            double fraction = (double) i / samples;

            double sampleLat = candidate.latitude() + fraction * (point.latitude() - candidate.latitude());
            double sampleLng = candidate.longitude() + fraction * (point.longitude() - candidate.longitude());

            // Elevação calculada da linha de rádio
            double radioZ = zStart + fraction * (zEnd - zStart);

            // Elevação real do terreno lida diretamente do raster em memória
            double terrainZ = elevationRaster.getElevation(sampleLat, sampleLng);

            // Só considera obstruído se o morro/terreno superar a linha de rádio além da margem de tolerância
            if (terrainZ > (radioZ + obstructionToleranceMeters)) {
                return false;
            }
        }

        return true;
    }

    /**
     * Sobrecarga usando cache de requisição e busca pontual.
     */
    public boolean hasLineOfSight(
            GatewayCandidate candidate,
            CoveragePoint point,
            Map<String, Double> requestCache
    ) {
        double hGateway = heightResolver.resolveGatewayHeight(candidate);
        double hPoint = heightResolver.resolvePointHeight(point);

        double zStart = elevationService.getElevation(candidate.latitude(), candidate.longitude(), requestCache) + hGateway;
        double zEnd = elevationService.getElevation(point.latitude(), point.longitude(), requestCache) + hPoint;

        int samples = Math.max(2, losSamples);
        for (int i = 1; i < samples; i++) {
            double fraction = (double) i / samples;

            double sampleLat = candidate.latitude() + fraction * (point.latitude() - candidate.latitude());
            double sampleLng = candidate.longitude() + fraction * (point.longitude() - candidate.longitude());

            double radioZ = zStart + fraction * (zEnd - zStart);
            double terrainZ = elevationService.getElevation(sampleLat, sampleLng, requestCache);

            if (terrainZ > (radioZ + obstructionToleranceMeters)) {
                return false;
            }
        }

        return true;
    }
}
