package com.tecsys.domain.gateway;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface GatewayProfileRepository extends JpaRepository<GatewayProfile, Long> {
    List<GatewayProfile> findAllByActiveTrue();
    Optional<GatewayProfile> findByIdAndActiveTrue(Long id);
    boolean existsByIdAndActiveTrue(Long id);
}