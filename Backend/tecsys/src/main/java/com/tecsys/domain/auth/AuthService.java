package com.tecsys.domain.auth;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.user.User;
import com.tecsys.domain.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public void changePassword(String email, String newPassword) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new BusinessRuleException("Usuário não encontrado."));

        user.setPasswordHash(passwordEncoder.encode(newPassword));
        user.setMustChangePassword(false);
        userRepository.save(user);
    }

    /**
     * "Redefinir Senha" do menu da conta: o usuário logado troca a própria
     * senha. Exige a senha atual, para uma sessão esquecida aberta não
     * bastar para tomar a conta.
     */
    @Transactional
    public void updatePassword(String email, String currentPassword, String newPassword) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new BusinessRuleException("Usuário não encontrado."));

        if (!passwordEncoder.matches(currentPassword, user.getPasswordHash())) {
            throw new BusinessRuleException("A senha atual está incorreta.");
        }
        if (passwordEncoder.matches(newPassword, user.getPasswordHash())) {
            throw new BusinessRuleException("A nova senha precisa ser diferente da atual.");
        }

        user.setPasswordHash(passwordEncoder.encode(newPassword));
        user.setMustChangePassword(false);
        userRepository.save(user);
    }
}