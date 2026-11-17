package com.tecsys.domain.gateway;

import com.fasterxml.jackson.databind.JsonNode;
import com.tecsys.core.exception.BusinessRuleException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * Decide qual perfil de gateway uma versão do projeto usa (#TG-150), nesta ordem:
 * <ol>
 *   <li>o perfil informado no pedido (precisa existir e estar ativo);</li>
 *   <li>o perfil da versão anterior do projeto (recálculo sem perfil);</li>
 *   <li>o perfil padrão (o front ainda não escolhe perfil; projetos antigos).</li>
 * </ol>
 * O id escolhido vai para {@code filter_params.gateway_profile_id}, que o motor lê.
 */
@Component
@RequiredArgsConstructor
public class GatewayProfileResolver {

    public static final String CAMPO = "gateway_profile_id";

    private final GatewayProfileRepository repository;

    /**
     * @param pedido    perfil enviado pelo front (pode ser null)
     * @param anteriores filter_params da versão anterior (null num projeto novo)
     * @return id do perfil, ou null se não houver perfil padrão cadastrado
     */
    public Long resolver(Long pedido, JsonNode anteriores) {
        if (pedido != null) {
            if (!repository.existsByIdAndActiveTrue(pedido)) {
                throw new BusinessRuleException("Perfil de gateway selecionado não existe ou está inativo.");
            }
            return pedido;
        }
        Long anterior = idEm(anteriores);
        if (anterior != null) {
            // Mantém o perfil da versão anterior, mesmo que tenha sido excluído depois:
            // o recálculo deve repetir as mesmas premissas.
            return anterior;
        }
        return repository.findFirstByPadraoTrueAndActiveTrue().map(GatewayProfile::getId).orElse(null);
    }

    /** gateway_profile_id gravado num filter_params, ou null. */
    public static Long idEm(JsonNode filterParams) {
        if (filterParams == null) return null;
        JsonNode v = filterParams.path(CAMPO);
        if (v.canConvertToLong()) return v.asLong();
        if (v.isTextual() && v.asText().trim().matches("\\d+")) return Long.parseLong(v.asText().trim());
        return null;
    }
}
