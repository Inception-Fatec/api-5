package com.tecsys.domain.distributor;

import com.tecsys.domain.distributor.dto.DistributorResumoProjection;
import com.tecsys.domain.distributor.dto.MunicipioProjection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DistributorRepository extends JpaRepository<Distributor, String> {

    // Parte de `sub` (preenchida pelo ETL); `distributor` só dá o nome,
    // quando existe. Sem nome, o front mostra o código.
    @Query(value = """
           SELECT
               s.dist AS dist,
               COALESCE(MAX(d.dist_name), '') AS distName,
               COUNT(*) AS totalSub
           FROM sub s
           LEFT JOIN distributor d ON d.dist = s.dist
           WHERE s.dist IS NOT NULL AND s.dist <> ''
           GROUP BY s.dist
           ORDER BY totalSub DESC
           """, nativeQuery = true)
    List<DistributorResumoProjection> findDistribuidorasResumo();

    // Cidades com consumidores (os pontos que o estudo cobre) da
    // distribuidora; o centro é a média desses consumidores (o envelope
    // fica torto quando o município tem pontos isolados longe da cidade).
    @Query(value = """
           WITH pontos AS (
               SELECT u.mun, u.geom, s.dist
               FROM ucbt u
               JOIN sub s ON s.cod_id = u.sub
               WHERE u.geom IS NOT NULL

               UNION ALL

               SELECT u.mun, u.geom, s.dist
               FROM ucmt_pj u
               JOIN sub s ON s.cod_id = u.sub
               WHERE u.geom IS NOT NULL

               UNION ALL

               SELECT u.mun, u.geom, s.dist
               FROM ucat_pj u
               JOIN sub s ON s.cod_id = u.sub
               WHERE u.geom IS NOT NULL
           )
           SELECT
               mun AS ibgeCode,
               ST_Y(ST_Transform(ST_SetSRID(ST_Centroid(ST_Collect(geom)), 4674), 4326)) AS latitude,
               ST_X(ST_Transform(ST_SetSRID(ST_Centroid(ST_Collect(geom)), 4674), 4326)) AS longitude
           FROM pontos
           WHERE dist = :dist AND mun IS NOT NULL AND mun <> ''
           GROUP BY mun
           ORDER BY mun
           """, nativeQuery = true)
    List<MunicipioProjection> findMunicipiosByDist(@Param("dist") String dist);
}