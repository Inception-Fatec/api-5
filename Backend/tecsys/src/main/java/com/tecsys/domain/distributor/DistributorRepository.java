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

    @Query(value = """
           SELECT
               d.dist AS dist,
               d.dist_name AS distName,
               COUNT(s.dist) AS totalSub
           FROM distributor d
           JOIN sub s ON s.dist = d.dist
           GROUP BY d.dist, d.dist_name
           ORDER BY totalSub DESC
           """, nativeQuery = true)
    List<DistributorResumoProjection> findDistribuidorasResumo();

    @Query(value = """
           WITH pontos AS (
               SELECT t.mun, t.geom, s.dist
               FROM untrmt t
               JOIN sub s ON s.cod_id = t.sub
               WHERE t.geom IS NOT NULL
               
               UNION ALL
               
               SELECT a.mun, a.geom, s.dist
               FROM untrat a
               JOIN sub s ON s.cod_id = a.sub
               WHERE a.geom IS NOT NULL
           )
           SELECT 
               mun AS ibgeCode,
               ST_Y(ST_Transform(ST_SetSRID(ST_Centroid(ST_Extent(geom)::geometry), 4674), 4326)) AS latitude,
               ST_X(ST_Transform(ST_SetSRID(ST_Centroid(ST_Extent(geom)::geometry), 4674), 4326)) AS longitude
           FROM pontos
           WHERE dist = :dist
           GROUP BY mun
           """, nativeQuery = true)
    List<MunicipioProjection> findMunicipiosByDist(@Param("dist") String dist);
}