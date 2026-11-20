package com.tecsys.domain.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Troca da própria senha pelo usuário logado ("Redefinir Senha" do menu da conta). */
public record UpdatePasswordDto(
        @NotBlank(message = "Informe a senha atual")
        String currentPassword,

        @NotBlank(message = "A nova senha não pode estar em branco")
        @Size(min = 6, message = "A senha deve ter no mínimo 6 caracteres")
        String newPassword
) {}
