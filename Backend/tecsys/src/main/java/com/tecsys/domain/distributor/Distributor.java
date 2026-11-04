package com.tecsys.domain.distributor;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.*;

@Entity
@Table(name = "distributor")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Distributor {

    @Id
    @Column(name = "dist", nullable = false, length = 10)
    private String dist;

    @Column(name = "dist_name", nullable = false)
    private String distName;
}