package com.tecsys.domain.decision.service;

import com.tecsys.domain.decision.model.CandidateType;
import com.tecsys.domain.decision.model.GatewayCandidate;
import com.tecsys.domain.decision.model.CoveragePoint;
import com.tecsys.domain.decision.model.VoltageLevel;
import org.springframework.stereotype.Component;

@Component
public class BDGDHeightResolver {

    /**
     * Resolve a altura da antena do Gateway com base no tipo de estrutura BDGD.
     */
    public double resolveGatewayHeight(GatewayCandidate candidate) {
        if (candidate.type() == CandidateType.UNTRAT || candidate.type() == CandidateType.SUB) {
            // Transformadores de alta tensão / Subestações: Mastro de telecom (~15m)
            return 15.0;
        }

        // UNTRMT (Transformadores de Média Tensão em postes)
        String posto = candidate.posto();
        if (posto != null) {
            // Se for posto de cabina abrigada/subterrânea ou pedestal
            if (posto.equalsIgnoreCase("CAB") || posto.equalsIgnoreCase("SUB")) {
                return 3.5;
            }
        }

        // Padrão UNTRMT aéreo: Instalado em poste de distribuição (norma ANEEL NBR 14039)
        return 10.5;
    }

    /**
     * Resolve a altura da antena do Ponto de Consumo com base no nível de tensão BDGD.
     */
    public double resolvePointHeight(CoveragePoint point) {
        if (point.level() == VoltageLevel.ALTO) {
            return 10.0; // Subestação de Consumidor ACAT
        } else if (point.level() == VoltageLevel.MEDIO) {
            return 6.0;  // Padrão de entrada UCMT
        }
        
        // BAIXO (UCBT) - Padrão de entrada do consumidor residencial/comercial (3m)
        return 3.0;
    }
}