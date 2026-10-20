
package com.tecsys.domain.decision.client;

import com.tecsys.domain.decision.dto.DecisionResultResponseDto;
import com.tecsys.domain.decision.model.DecisionCriteria;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.server.ResponseStatusException;

@Component
public class MotorClient {

    private final RestClient restClient;

    public MotorClient(
            RestClient.Builder builder,
            @Value("${motor.base-url:http://127.0.0.1:8082}")
            String motorBaseUrl
    ) {

        SimpleClientHttpRequestFactory factory =
                new SimpleClientHttpRequestFactory();

        factory.setConnectTimeout(5000);
        factory.setReadTimeout(120000);

        this.restClient = builder
                .baseUrl(motorBaseUrl)
                .requestFactory(factory)
                .build();
    }

    public DecisionResultResponseDto calculate(
            DecisionCriteria criteria
    ) {
        try {
            DecisionResultResponseDto response = restClient
                    .post()
                    .uri("/internal/decision/calculate")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(criteria)
                    .retrieve()
                    .body(DecisionResultResponseDto.class);

            if (response == null) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_GATEWAY,
                        "MOTOR retornou uma resposta vazia."
                );
            }

            return response;

        } catch (ResourceAccessException e) {
            throw new ResponseStatusException(
                    HttpStatus.GATEWAY_TIMEOUT,
                    "Falha de comunicacao ou timeout do MOTOR.",
                    e
            );

        } catch (RestClientResponseException e) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_GATEWAY,
                    "MOTOR retornou HTTP " + e.getStatusCode().value(),
                    e
            );
        }
    }
}
