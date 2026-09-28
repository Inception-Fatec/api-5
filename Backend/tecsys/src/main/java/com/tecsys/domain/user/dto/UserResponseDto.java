package com.tecsys.domain.user.dto;

import com.tecsys.domain.user.User;

public record UserResponseDto(
        Long id,
        String name,
        String email,
        String role
) {
    public static UserResponseDto fromEntity(User user) {
        return new UserResponseDto(
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getRole().name()
        );
    }
}