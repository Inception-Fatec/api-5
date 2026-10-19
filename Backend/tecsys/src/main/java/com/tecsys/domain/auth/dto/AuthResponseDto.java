package com.tecsys.domain.auth.dto;

public record AuthResponseDto(
        String token,
        String role,
        boolean mustChangePassword,
        String name
) {}