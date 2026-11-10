package com.tecsys.infrastructure.engine;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.function.Consumer;

@Component
public class DecisionEngineClient {

    private static final Logger log = LoggerFactory.getLogger(DecisionEngineClient.class);

    @Value("${engine.url}")
    private String engineUrl;

    private final HttpClient httpClient;

    public DecisionEngineClient() {
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    public void sendToEngineAsync(Long projectId) {
        sendToEngineAsync(projectId, motivo -> { });
    }

    /**
     * Chama o motor sem esperar o cálculo. Se o motor estiver fora do ar ou
     * responder com erro, {@code onFailure} recebe a mensagem — quem chama
     * marca o projeto como FALHA, para ele não ficar ENVIADO para sempre.
     */
    public void sendToEngineAsync(Long projectId, Consumer<String> onFailure) {
        String payload = """
                { "project_id": %d }
                """.formatted(projectId);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(engineUrl))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(payload))
                .build();

        httpClient.sendAsync(request, HttpResponse.BodyHandlers.discarding())
                .whenComplete((resp, erro) -> {
                    String motivo = null;
                    if (erro != null) {
                        motivo = "Motor de cálculo indisponível. Verifique se ele está no ar e recalcule o projeto.";
                        log.error("Projeto {}: motor indisponível: {}", projectId, erro.toString());
                    } else if (resp.statusCode() >= 400) {
                        motivo = "O motor de cálculo respondeu com erro (HTTP " + resp.statusCode() + ").";
                        log.error("Projeto {}: {}", projectId, motivo);
                    }
                    if (motivo != null) {
                        try {
                            onFailure.accept(motivo);
                        } catch (RuntimeException e) {
                            log.error("Projeto {}: não foi possível marcar FALHA: {}", projectId, e.getMessage(), e);
                        }
                    }
                });
    }

    /**
     * Chama o motor só depois do commit da transação atual (#TG-96): assim o
     * motor sempre encontra o projeto e a versão nova do histórico gravados.
     * Fora de transação, chama na hora.
     */
    public void sendAfterCommit(Long projectId, Consumer<String> onFailure) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    sendToEngineAsync(projectId, onFailure);
                }
            });
        } else {
            sendToEngineAsync(projectId, onFailure);
        }
    }
}
