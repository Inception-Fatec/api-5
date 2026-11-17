package com.tecsys.domain.gateway;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tecsys.core.exception.BusinessRuleException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** #TG-150 — qual perfil de gateway uma versão do projeto usa. */
class GatewayProfileResolverTest {

    private final ObjectMapper mapper = new ObjectMapper();
    private GatewayProfileRepository repository;
    private GatewayProfileResolver resolver;

    @BeforeEach
    void setUp() {
        repository = mock(GatewayProfileRepository.class);
        resolver = new GatewayProfileResolver(repository);
        GatewayProfile padrao = GatewayProfile.builder().id(1L).name("Tecsys").padrao(true).build();
        when(repository.findFirstByPadraoTrueAndActiveTrue()).thenReturn(Optional.of(padrao));
    }

    // CT1: sem perfil no pedido nem versão anterior → perfil padrão
    @Test
    void semPerfilUsaOPadrao() {
        assertEquals(1L, resolver.resolver(null, null));
    }

    @Test
    void perfilInformadoEValidoEUsado() {
        when(repository.existsByIdAndActiveTrue(7L)).thenReturn(true);
        assertEquals(7L, resolver.resolver(7L, null));
    }

    @Test
    void perfilInformadoInexistenteOuInativoERecusado() {
        when(repository.existsByIdAndActiveTrue(99L)).thenReturn(false);
        assertThrows(BusinessRuleException.class, () -> resolver.resolver(99L, null));
    }

    // CT5: recálculo sem perfil mantém o da versão anterior
    @Test
    void recalculoSemPerfilMantemOAnterior() throws Exception {
        var anteriores = mapper.readTree("{\"mun_codes\":[\"3549904\"],\"gateway_profile_id\":7}");
        assertEquals(7L, resolver.resolver(null, anteriores));
        verify(repository, never()).existsByIdAndActiveTrue(any());
    }

    @Test
    void versaoAnteriorSemPerfilCaiNoPadrao() throws Exception {
        var anteriores = mapper.readTree("{\"mun_codes\":[\"3549904\"]}");
        assertEquals(1L, resolver.resolver(null, anteriores));
    }

    @Test
    void semPerfilPadraoCadastradoDevolveNull() {
        when(repository.findFirstByPadraoTrueAndActiveTrue()).thenReturn(Optional.empty());
        assertNull(resolver.resolver(null, null));
    }

    @Test
    void idEmAceitaNumeroOuTextoNumerico() throws Exception {
        assertEquals(3L, GatewayProfileResolver.idEm(mapper.readTree("{\"gateway_profile_id\":3}")));
        assertEquals(3L, GatewayProfileResolver.idEm(mapper.readTree("{\"gateway_profile_id\":\"3\"}")));
        assertNull(GatewayProfileResolver.idEm(mapper.readTree("{\"gateway_profile_id\":\"abc\"}")));
        assertNull(GatewayProfileResolver.idEm(null));
    }
}
