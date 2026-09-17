package com.tecsys.domain.user;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.core.exception.EmailAlreadyExistsException;
import com.tecsys.domain.user.dto.UserCreateDto;
import com.tecsys.domain.user.dto.UserResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public UserResponseDto createUser(UserCreateDto dto) {
        if (userRepository.findByEmail(dto.email()).isPresent()) {
            throw new EmailAlreadyExistsException("Já existe um usuário cadastrado com este e-mail.");
        }

        User user = User.builder()
                .name(dto.name())
                .email(dto.email())
                .passwordHash(passwordEncoder.encode(dto.password()))
                .role(dto.role())
                .mustChangePassword(true)
                .isActive(true)
                .build();

        return UserResponseDto.fromEntity(userRepository.save(user));
    }

    public List<UserResponseDto> listAllUsers() {
        return userRepository.findAll().stream()
                .map(UserResponseDto::fromEntity)
                .toList();
    }

    @Transactional
    public void deleteUser(Long id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new BusinessRuleException("Usuário não encontrado."));

        if (user.getRole() == UserRole.ADM) {
            throw new BusinessRuleException("Não é permitido excluir um usuário com perfil de Administrador.");
        }

        userRepository.delete(user);
    }

}