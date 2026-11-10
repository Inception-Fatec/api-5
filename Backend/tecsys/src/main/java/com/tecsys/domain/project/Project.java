package com.tecsys.domain.project;

import com.tecsys.domain.user.User;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;

@Entity
@Table(name = "projects")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Project {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(name = "dist_code", nullable = false, length = 10) //campo do banco de código da empresa
    private String distCode;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ProjectStatus status;

    // Motivo da falha (status FALHA), ex.: motor fora do ar (#TG-84). Nulo nos demais.
    @Column(name = "status_message", length = 500)
    private String statusMessage;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by", nullable = false)
    private User createdBy;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;

    @Builder.Default
    @Column(nullable = false, columnDefinition = "boolean default true")
    private boolean active = true;

    // Atividade mais recente: criar, recalcular ou abrir o relatório (#TG-87).
    @Column(name = "last_activity_at", nullable = false)
    private Instant lastActivityAt;

    @PrePersist
    void aoCriar() {
        if (lastActivityAt == null) lastActivityAt = Instant.now();
    }

    /** Marca agora como a atividade mais recente do projeto. */
    public void registrarAtividade() {
        lastActivityAt = Instant.now();
    }
}