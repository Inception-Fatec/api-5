package com.tecsys.domain.user;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.core.exception.EmailAlreadyExistsException;
import com.tecsys.domain.user.dto.UserCreateDto;
import com.tecsys.domain.user.dto.UserResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.AccessDeniedException;
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
            throw new EmailAlreadyExistsException("Já existe um utilizador registado com este e-mail.");
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

    @Transactional(readOnly = true)
    public Page<UserResponseDto> listAllUsers(Pageable pageable) {
        return userRepository.findAll(pageable)
                .map(UserResponseDto::fromEntity);
    }

    @Transactional(readOnly = true)
    public UserResponseDto getUserById(Long id) {
        return userRepository.findById(id)
                .map(UserResponseDto::fromEntity)
                .orElseThrow(() -> new BusinessRuleException("Utilizador não encontrado."));
    }

    @Transactional(readOnly = true)
    public List<UserResponseDto> getUsersByIds(List<Long> ids) {
        return userRepository.findAllById(ids).stream()
                .map(UserResponseDto::fromEntity)
                .toList();
    }

    @Transactional
    public void deleteUser(Long id, Long currentUserId) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new BusinessRuleException("Utilizador não encontrado."));

        if (user.getRole() == UserRole.ADM && !user.getId().equals(currentUserId)) {
            throw new AccessDeniedException("Ação não permitida: Não pode eliminar a conta de outro administrador.");
        }

        user.setActive(false);
        userRepository.save(user);
    }
}