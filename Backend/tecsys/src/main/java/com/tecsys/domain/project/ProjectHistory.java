// no arquivo ProjectHistory.java
package com.tecsys.domain.project;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.ColumnTransformer;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

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

    @Column(name = "polygon", columnDefinition = "geometry")
    @ColumnTransformer(
            read = "ST_AsGeoJSON(polygon)",
            write = "ST_GeomFromGeoJSON(?)"
    )
    private String polygonGeojson;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "filter_params", columnDefinition = "jsonb")
    private JsonNode filterParams;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;
}