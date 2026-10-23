package com.tecsys.domain.decision.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Duration;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class ElevationService {

    private static final Logger log = LoggerFactory.getLogger(ElevationService.class);

    @Value("${app.elevation.opentopography.globaldem-url:https://portal.opentopography.org/API/globaldem}")
    private String openTopographyGlobalDemUrl;

    @Value("${app.elevation.opentopography.point-url:https://portal.opentopography.org/API/v1/elevation}")
    private String openTopographyPointUrl;

    @Value("${app.elevation.opentopography.api-key:${OPENTOPOGRAPHY_API_KEY:}}")
    private String openTopographyApiKey;

    @Value("${app.elevation.opentopography.dataset:COP30}")
    private String dataset;

    @Value("${app.elevation.open-elevation.url:https://api.open-elevation.com/api/v1/lookup}")
    private String openElevationUrl;

    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final Map<String, Double> globalCache = new ConcurrentHashMap<>();

    public ElevationService(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    /**
     * Baixa um recorte GeoTIFF da Bounding Box via OpenTopography Global DEM API.
     * Retorna um AutoCloseable que, ao ser fechado, apaga o arquivo temporário do disco.
     */
    public AreaElevationRaster downloadAreaRaster(double south, double north, double west, double east) {
        if (openTopographyApiKey == null || openTopographyApiKey.trim().isEmpty()) {
            log.warn("Chave OPENTOPOGRAPHY_API_KEY não informada no .env.properties. Não foi possível baixar a área GeoTIFF da OpenTopography.");
            return new FlatElevationRaster(0.0);
        }

        try {
            StringBuilder urlBuilder = new StringBuilder(openTopographyGlobalDemUrl);
            urlBuilder.append("?demtype=").append(URLEncoder.encode(dataset, StandardCharsets.UTF_8))
                      .append("&south=").append(String.format(Locale.US, "%.5f", south))
                      .append("&north=").append(String.format(Locale.US, "%.5f", north))
                      .append("&west=").append(String.format(Locale.US, "%.5f", west))
                      .append("&east=").append(String.format(Locale.US, "%.5f", east))
                      .append("&outputFormat=GTiff")
                      .append("&API_Key=").append(URLEncoder.encode(openTopographyApiKey.trim(), StandardCharsets.UTF_8));

            log.info("Baixando recorte DEM da OpenTopography para a área [S:{}, N:{}, W:{}, E:{}]...",
                    south, north, west, east);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(urlBuilder.toString()))
                    .timeout(Duration.ofSeconds(30))
                    .header("Accept", "image/tiff, application/octet-stream")
                    .GET()
                    .build();

            HttpResponse<InputStream> response = httpClient.send(request, HttpResponse.BodyHandlers.ofInputStream());

            if (response.statusCode() == 200) {
                Path tempFile = Files.createTempFile("opentopo_dem_", ".tif");
                try (InputStream is = response.body()) {
                    Files.copy(is, tempFile, StandardCopyOption.REPLACE_EXISTING);
                }

                long fileSize = Files.size(tempFile);
                log.info("GeoTIFF temporário criado com sucesso em {} ({} KB)", tempFile, fileSize / 1024);

                return new TempGeoTiffElevationRaster(tempFile, south, north, west, east);
            } else {
                String errorBody = "";
                try {
                    errorBody = new String(response.body().readAllBytes(), StandardCharsets.UTF_8);
                } catch (Exception ignored) {}
                log.error("Falha ao baixar BBox da OpenTopography. Status HTTP: {}, Resposta: {}",
                        response.statusCode(), errorBody);
                return new FlatElevationRaster(0.0);
            }
        } catch (Exception e) {
            log.error("Exceção ao solicitar GeoTIFF da Bounding Box: {}", e.getMessage(), e);
            return new FlatElevationRaster(0.0);
        }
    }

    /**
     * Consulta individual com cache em memória (fallback para pontos isolados).
     */
    public double getElevation(double latitude, double longitude, Map<String, Double> requestCache) {
        String cacheKey = String.format(Locale.US, "%.4f,%.4f", latitude, longitude);

        if (requestCache != null && requestCache.containsKey(cacheKey)) {
            return requestCache.get(cacheKey);
        }

        if (globalCache.containsKey(cacheKey)) {
            double cached = globalCache.get(cacheKey);
            if (requestCache != null) {
                requestCache.put(cacheKey, cached);
            }
            return cached;
        }

        double elevation = fetchElevationFromApi(latitude, longitude);

        globalCache.put(cacheKey, elevation);
        if (requestCache != null) {
            requestCache.put(cacheKey, elevation);
        }

        return elevation;
    }

    private double fetchElevationFromApi(double latitude, double longitude) {
        try {
            Double otElevation = queryOpenTopographyPoint(latitude, longitude);
            if (otElevation != null) {
                return otElevation;
            }
        } catch (Exception e) {
            log.debug("Falha ao consultar ponto na OpenTopography ({}, {}): {}", latitude, longitude, e.getMessage());
        }

        try {
            Double oeElevation = queryOpenElevationPoint(latitude, longitude);
            if (oeElevation != null) {
                return oeElevation;
            }
        } catch (Exception e) {
            log.debug("Falha ao consultar ponto no Open-Elevation ({}, {}): {}", latitude, longitude, e.getMessage());
        }

        return 0.0;
    }

    private Double queryOpenTopographyPoint(double latitude, double longitude) {
        try {
            StringBuilder urlBuilder = new StringBuilder(openTopographyPointUrl);
            urlBuilder.append("?latitude=").append(String.format(Locale.US, "%.6f", latitude))
                      .append("&longitude=").append(String.format(Locale.US, "%.6f", longitude))
                      .append("&dataset=").append(URLEncoder.encode(dataset, StandardCharsets.UTF_8));

            if (openTopographyApiKey != null && !openTopographyApiKey.trim().isEmpty()) {
                urlBuilder.append("&API_Key=").append(URLEncoder.encode(openTopographyApiKey.trim(), StandardCharsets.UTF_8));
            }

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(urlBuilder.toString()))
                    .timeout(Duration.ofSeconds(5))
                    .header("Accept", "application/json, text/plain")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() == 200) {
                String body = response.body().trim();
                if (body.startsWith("{")) {
                    JsonNode root = objectMapper.readTree(body);
                    if (root.hasNonNull("Elevation")) {
                        return root.get("Elevation").asDouble();
                    } else if (root.hasNonNull("elevation")) {
                        return root.get("elevation").asDouble();
                    }
                } else {
                    return Double.parseDouble(body);
                }
            }
        } catch (Exception ignored) {}
        return null;
    }

    private Double queryOpenElevationPoint(double latitude, double longitude) {
        try {
            String url = String.format(Locale.US, "%s?locations=%.6f,%.6f", openElevationUrl, latitude, longitude);
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(5))
                    .header("Accept", "application/json")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() == 200) {
                JsonNode root = objectMapper.readTree(response.body());
                JsonNode results = root.get("results");
                if (results != null && results.isArray() && !results.isEmpty()) {
                    JsonNode first = results.get(0);
                    if (first.hasNonNull("elevation")) {
                        return first.get("elevation").asDouble();
                    }
                }
            }
        } catch (Exception ignored) {}
        return null;
    }
}
