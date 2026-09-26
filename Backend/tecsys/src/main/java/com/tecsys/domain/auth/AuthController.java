package com.tecsys.domain.auth;

import com.tecsys.domain.auth.dto.AuthRequestDto;
import com.tecsys.domain.auth.dto.AuthResponseDto;
import com.tecsys.domain.auth.dto.ChangePasswordDto;
import com.tecsys.domain.user.User;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final TokenService tokenService;
    private final AuthService authService;

    @PostMapping("/login")
    public ResponseEntity<AuthResponseDto> login(@RequestBody @Valid AuthRequestDto dto) {
        var usernamePassword = new UsernamePasswordAuthenticationToken(dto.email(), dto.password());
        var auth = authenticationManager.authenticate(usernamePassword);

        var user = (User) auth.getPrincipal();
        var token = tokenService.generateToken(user);

        var response = new AuthResponseDto(
                token,
                user.getRole().name(),
                user.isMustChangePassword(),
                user.getName()
        );

        return ResponseEntity.ok(response);
    }

    @PostMapping("/change-password")
    public ResponseEntity<String> changePassword(
            @RequestBody @Valid ChangePasswordDto dto,
            @AuthenticationPrincipal User user) {
        authService.changePassword(user.getEmail(), dto.newPassword());
        return ResponseEntity.ok("Senha redefinida com sucesso. Acesso liberado ao sistema.");
    }
}