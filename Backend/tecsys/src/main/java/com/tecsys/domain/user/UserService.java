package com.tecsys.domain.user;

import com.tecsys.core.exception.EmailAlreadyExistsException;
import com.tecsys.domain.user.dto.UserCreateDto;
import com.tecsys.domain.user.dto.UserResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
}