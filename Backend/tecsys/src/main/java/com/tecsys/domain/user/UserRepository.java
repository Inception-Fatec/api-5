package com.tecsys.domain.user;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);

    // Exclusão é lógica (is_active = false): as listagens só mostram os ativos.
    List<User> findAllByIsActiveTrue();

    Page<User> findAllByIsActiveTrue(Pageable pageable);
}
