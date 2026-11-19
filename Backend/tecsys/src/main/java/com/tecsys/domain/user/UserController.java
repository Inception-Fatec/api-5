package com.tecsys.domain.user;

import com.tecsys.domain.user.dto.AdminResetPasswordDto;
import com.tecsys.domain.user.dto.UserCreateDto;
import com.tecsys.domain.user.dto.UserResponseDto;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @PostMapping
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<UserResponseDto> create(@RequestBody @Valid UserCreateDto dto) {
        return ResponseEntity.status(HttpStatus.CREATED).body(userService.createUser(dto));
    }

    @GetMapping
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<List<UserResponseDto>> listAll() {
        return ResponseEntity.ok(userService.listAllUsers());
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<UserResponseDto> getById(@PathVariable Long id) {
        return ResponseEntity.ok(userService.getUserById(id));
    }

    @PostMapping("/batch")
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<List<UserResponseDto>> getByIds(@RequestBody List<Long> ids) {
        return ResponseEntity.ok(userService.getUsersByIds(ids));
    }

    /** Senha temporária para quem esqueceu; o usuário cria uma nova no próximo acesso. */
    @PostMapping("/{id}/reset-password")
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<Void> resetPassword(@PathVariable Long id,
                                              @RequestBody @Valid AdminResetPasswordDto dto,
                                              @AuthenticationPrincipal User currentUser) {
        userService.resetPassword(id, dto.temporaryPassword(), currentUser.getId());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<Void> delete(@PathVariable Long id, @AuthenticationPrincipal User currentUser) {
        userService.deleteUser(id, currentUser.getId());
        return ResponseEntity.noContent().build();
    }
}