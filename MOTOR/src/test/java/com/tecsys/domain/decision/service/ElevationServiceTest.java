package com.tecsys.domain.decision.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class ElevationServiceTest {

    private ElevationService elevationService;

    @BeforeEach
    void setUp() {
        ObjectMapper objectMapper = new ObjectMapper();
        elevationService = new ElevationService(objectMapper);
    }

    @Test
    void shouldReturnCachedValueFromRequestCache() {
        Map<String, Double> requestCache = new HashMap<>();
        requestCache.put("-23.1800,-45.8800", 615.5);

        double elevation = elevationService.getElevation(-23.18, -45.88, requestCache);

        assertEquals(615.5, elevation);
    }

    @Test
    void shouldCacheElevationAfterFirstResolution() {
        Map<String, Double> requestCache = new HashMap<>();

        // Primeiro acesso (sem rede pode retornar 0.0 fallback)
        double first = elevationService.getElevation(-23.18, -45.88, requestCache);

        // Verifica se chave foi inserida no requestCache
        assertEquals(Double.valueOf(first), requestCache.get("-23.1800,-45.8800"));

        // Segundo acesso usa o cache
        double second = elevationService.getElevation(-23.18, -45.88, requestCache);
        assertEquals(first, second);
    }
}

