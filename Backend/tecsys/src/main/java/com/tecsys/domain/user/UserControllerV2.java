package com.tecsys.domain.user;

import com.tecsys.domain.user.dto.UserResponseDto;
import lombok.RequiredArgsConstructor;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v2/users")
@RequiredArgsConstructor
public class UserControllerV2 {

    private final UserService userService;

    @GetMapping
    @PreAuthorize("hasRole('ADM')")
    public ResponseEntity<Page<UserResponseDto>> listAllPaginated(@ParameterObject @PageableDefault(size = 10) Pageable pageable) {
        return ResponseEntity.ok(userService.listAllUsersPaginated(pageable));
    }

}