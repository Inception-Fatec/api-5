package com.tecsys.domain.user;

import com.tecsys.domain.user.dto.UserCreateDto;
import com.tecsys.domain.user.dto.UserResponseDto;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @PostMapping
    public ResponseEntity<UserResponseDto> create(@RequestBody @Valid UserCreateDto dto) {
        UserResponseDto response = userService.createUser(dto);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
}