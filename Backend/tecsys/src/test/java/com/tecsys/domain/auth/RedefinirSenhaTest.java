package com.tecsys.domain.auth;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.user.User;
import com.tecsys.domain.user.UserRepository;
import com.tecsys.domain.user.UserRole;
import com.tecsys.domain.user.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/** Redefinir senha: pelo próprio usuário (menu da conta) e pelo administrador (Usuários). */
class RedefinirSenhaTest {

    private final PasswordEncoder encoder = new BCryptPasswordEncoder();
    private UserRepository repo;
    private AuthService authService;
    private UserService userService;

    @BeforeEach
    void setUp() {
        repo = mock(UserRepository.class);
        when(repo.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        authService = new AuthService(repo, encoder);
        userService = new UserService(repo, encoder);
    }

    private User usuario(long id, UserRole role, String senha) {
        User u = User.builder().id(id).name("U" + id).email("u" + id + "@tecsys.com")
                .passwordHash(encoder.encode(senha)).role(role)
                .mustChangePassword(false).isActive(true).build();
        when(repo.findByEmail(u.getEmail())).thenReturn(Optional.of(u));
        when(repo.findById(id)).thenReturn(Optional.of(u));
        return u;
    }

    // --- Usuário logado troca a própria senha ---

    @Test
    void trocaASenhaComASenhaAtualCerta() {
        User u = usuario(1, UserRole.USER, "antiga1");
        authService.updatePassword(u.getEmail(), "antiga1", "nova123");
        assertTrue(encoder.matches("nova123", u.getPasswordHash()));
        assertFalse(u.isMustChangePassword());
        verify(repo).save(u);
    }

    @Test
    void senhaAtualErradaNaoTroca() {
        User u = usuario(1, UserRole.USER, "antiga1");
        var e = assertThrows(BusinessRuleException.class,
                () -> authService.updatePassword(u.getEmail(), "errada", "nova123"));
        assertEquals("A senha atual está incorreta.", e.getMessage());
        assertTrue(encoder.matches("antiga1", u.getPasswordHash()));
        verify(repo, never()).save(any());
    }

    @Test
    void novaSenhaIgualAAtualERecusada() {
        User u = usuario(1, UserRole.USER, "antiga1");
        assertThrows(BusinessRuleException.class,
                () -> authService.updatePassword(u.getEmail(), "antiga1", "antiga1"));
        verify(repo, never()).save(any());
    }

    // --- Administrador redefine a senha de quem esqueceu ---

    @Test
    void administradorRedefineASenhaDeUmUsuario() {
        usuario(9, UserRole.ADM, "admin1");
        User u = usuario(2, UserRole.USER, "esquecida");
        userService.resetPassword(2L, "temp123", 9L);
        assertTrue(encoder.matches("temp123", u.getPasswordHash()));
        assertTrue(u.isMustChangePassword(), "no próximo acesso ele cria uma senha nova");
    }

    @Test
    void naoRedefineASenhaDeOutroAdministrador() {
        usuario(9, UserRole.ADM, "admin1");
        User outro = usuario(3, UserRole.ADM, "outro1");
        assertThrows(AccessDeniedException.class, () -> userService.resetPassword(3L, "temp123", 9L));
        assertTrue(encoder.matches("outro1", outro.getPasswordHash()));
        verify(repo, never()).save(any());
    }

    @Test
    void aPropriaSenhaSeTrocaPeloMenuDaConta() {
        usuario(9, UserRole.ADM, "admin1");
        assertThrows(BusinessRuleException.class, () -> userService.resetPassword(9L, "temp123", 9L));
        verify(repo, never()).save(any());
    }

    @Test
    void usuarioRemovidoNaoEEncontrado() {
        User u = usuario(4, UserRole.USER, "x12345");
        u.setActive(false);
        assertThrows(BusinessRuleException.class, () -> userService.resetPassword(4L, "temp123", 9L));
    }
}
