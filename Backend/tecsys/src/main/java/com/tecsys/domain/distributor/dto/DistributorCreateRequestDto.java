package com.tecsys.domain.distributor.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Cadastro de distribuidora personalizada (#TG-151), para importar pontos por CSV
 *  de uma rede que não tem BDGD carregada. */
public record DistributorCreateRequestDto(
        @NotBlank(message = "Informe o código da distribuidora.")
        @Pattern(regexp = "\\d{1,10}", message = "O código da distribuidora deve ter só números (até 10 dígitos).")
        String codigo,

        @NotBlank(message = "Informe o nome da distribuidora.")
        @Size(max = 100, message = "O nome deve ter no máximo 100 caracteres.")
        String nome
) {}
