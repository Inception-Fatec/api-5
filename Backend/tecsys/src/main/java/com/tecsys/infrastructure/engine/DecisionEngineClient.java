package com.tecsys.infrastructure.engine;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

@Component
public class DecisionEngineClient {

    @Value("${engine.url:http://localhost:8082/api/calculate}")
    private String engineUrl;

    private final HttpClient httpClient;

    public DecisionEngineClient() {
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    public void sendToEngineAsync(Long projectId) {
        String payload = """
                { "project_id": %d }
                """.formatted(projectId);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(engineUrl))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(payload))
                .build();

        httpClient.sendAsync(request, HttpResponse.BodyHandlers.discarding());
    }
}