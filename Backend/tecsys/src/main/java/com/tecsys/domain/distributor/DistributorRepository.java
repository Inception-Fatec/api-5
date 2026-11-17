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

    // Distribuidoras com rede da BDGD (`sub`, preenchida pelo ETL) ou com pontos
    // importados por CSV (`external_points`, #TG-151). Com incluirCadastradas,
    // entram também as cadastradas sem dado nenhum ainda (modal de CSV).
    // `distributor` dá o nome, quando existe; sem nome, o front mostra o código.
    // total_sub = 0 indica distribuidora sem BDGD (rede independente).
    @Query(value = """
           WITH bdgd AS (
               SELECT s.dist, COUNT(*) AS total_sub
               FROM sub s
               WHERE s.dist IS NOT NULL AND s.dist <> ''
               GROUP BY s.dist
           ),
           todas AS (
               SELECT dist FROM bdgd
               UNION
               SELECT DISTINCT dist FROM external_points
               UNION
               SELECT dist FROM distributor WHERE :incluirCadastradas
           )
           SELECT
               t.dist AS dist,
               COALESCE(MAX(d.dist_name), '') AS distName,
               COALESCE(MAX(b.total_sub), 0) AS totalSub
           FROM todas t
           LEFT JOIN distributor d ON d.dist = t.dist
           LEFT JOIN bdgd b ON b.dist = t.dist
           GROUP BY t.dist
           ORDER BY totalSub DESC, t.dist
           """, nativeQuery = true)
    List<DistributorResumoProjection> findDistribuidorasResumo(@Param("incluirCadastradas") boolean incluirCadastradas);

    /** A distribuidora já tem rede da BDGD carregada? */
    @Query(value = "SELECT EXISTS (SELECT 1 FROM sub WHERE dist = :dist)", nativeQuery = true)
    boolean temRede(@Param("dist") String dist);

    // Cidades com consumidores (os pontos que o estudo cobre) da
    // distribuidora; o centro é a média desses consumidores (o envelope
    // fica torto quando o município tem pontos isolados longe da cidade).
    @Query(value = """
           WITH pontos AS (
               SELECT u.mun, u.geom, s.dist, 'bdgd' AS origem
               FROM ucbt u
               JOIN sub s ON s.cod_id = u.sub
               WHERE u.geom IS NOT NULL

               UNION ALL

               SELECT u.mun, u.geom, s.dist, 'bdgd'
               FROM ucmt_pj u
               JOIN sub s ON s.cod_id = u.sub
               WHERE u.geom IS NOT NULL

               UNION ALL

               SELECT u.mun, u.geom, s.dist, 'bdgd'
               FROM ucat_pj u
               JOIN sub s ON s.cod_id = u.sub
               WHERE u.geom IS NOT NULL

               UNION ALL

               -- pontos importados por CSV (#TG-151): cidade sem BDGD também aparece
               SELECT e.mun, e.geom, e.dist, 'csv'
               FROM external_points e
               WHERE e.geom IS NOT NULL
           )
           SELECT
               mun AS ibgeCode,
               ST_Y(ST_Transform(ST_SetSRID(ST_Centroid(ST_Collect(geom)), 4674), 4326)) AS latitude,
               ST_X(ST_Transform(ST_SetSRID(ST_Centroid(ST_Collect(geom)), 4674), 4326)) AS longitude,
               bool_or(origem = 'bdgd') AS temRede,
               bool_or(origem = 'csv') AS temCsv
           FROM pontos
           WHERE dist = :dist AND mun IS NOT NULL AND mun <> ''
           GROUP BY mun
           ORDER BY mun
           """, nativeQuery = true)
    List<MunicipioProjection> findMunicipiosByDist(@Param("dist") String dist);
}