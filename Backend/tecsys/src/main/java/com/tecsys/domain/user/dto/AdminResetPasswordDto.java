package com.tecsys.domain.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Senha temporária definida pelo administrador para quem esqueceu a senha.
 * O usuário entra com ela e o sistema obriga a criar uma nova (primeiro acesso).
 */
public record AdminResetPasswordDto(
        @NotBlank(message = "Informe a senha temporária")
        @Size(min = 6, message = "A senha deve ter no mínimo 6 caracteres")
        String temporaryPassword
) {}
