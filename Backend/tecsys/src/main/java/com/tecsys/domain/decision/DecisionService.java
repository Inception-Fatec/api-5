
package com.tecsys.domain.decision;

import com.tecsys.domain.decision.client.MotorClient;
import com.tecsys.domain.decision.dto.DecisionResultResponseDto;
import com.tecsys.domain.decision.model.DecisionCriteria;

import org.springframework.stereotype.Service;

@Service
public class DecisionService {

    private final MotorClient motorClient;

    public DecisionService(MotorClient motorClient) {
        this.motorClient = motorClient;
    }

    public DecisionResultResponseDto calculate(
            DecisionCriteria criteria
    ) {
        return motorClient.calculate(criteria);
    }
}
