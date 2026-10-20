package com.tecsys.domain.project;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.ColumnTransformer;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

@Entity
@Table(name = "project_history")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ProjectHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "project_id", nullable = false)
    private Project project;

    @Column(name = "polygon", columnDefinition = "geometry", nullable = false)
    @ColumnTransformer(
            read = "ST_AsGeoJSON(polygon)",
            write = "ST_GeomFromGeoJSON(?)"
    )
    private String polygonGeojson;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;
}