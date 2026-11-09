
package com.tecsys.domain.auth;

import com.tecsys.domain.user.User;
import com.tecsys.domain.user.UserRole;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class TokenServiceTest {

    private static final String SEGREDO_VALIDO = "A".repeat(64);

    @Test
    void deveRejeitarSegredoVazio() {
        assertThrows(
                IllegalStateException.class,
                () -> new TokenService("")
        );
    }

    @Test
    void deveRejeitarSegredoCurto() {
        assertThrows(
                IllegalStateException.class,
                () -> new TokenService("123456")
        );
    }

    @Test
    void deveGerarEValidarTokenComSegredoSeguro() {
        TokenService service = new TokenService(SEGREDO_VALIDO);

        User usuario = User.builder()
                .email("admin@teste.local")
                .role(UserRole.ADM)
                .build();

        String token = service.generateToken(usuario);

        assertNotNull(token);
        assertEquals(
                "admin@teste.local",
                service.validateToken(token)
        );
    }

    @Test
    void deveRejeitarTokenAssinadoComOutroSegredo() {
        TokenService emissor = new TokenService("A".repeat(64));
        TokenService validador = new TokenService("B".repeat(64));

        User usuario = User.builder()
                .email("admin@teste.local")
                .role(UserRole.ADM)
                .build();

        String token = emissor.generateToken(usuario);

        assertEquals("", validador.validateToken(token));
    }
}
