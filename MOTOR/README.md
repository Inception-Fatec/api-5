# Motor de decisão

Responde à pergunta do projeto: **onde instalar o menor número de gateways que cubra os pontos de consumo de uma área**, levando em conta o relevo.

O backend chama `POST /api/calculate` com `{"project_id": N}`. O motor lê os filtros do projeto, calcula, grava o resultado em `project_coverage` e muda o status do projeto: `PROCESSANDO` durante o cálculo, depois `SUCESSO` ou `FALHA`. O formato gravado é o mesmo de antes, então o relatório e o mapa não mudam.

O relevo vem do Copernicus GLO-30 no AWS Open Data. Para a operação do mirror, cache, NAS e licença, veja [`docs/MOTOR_RELEVO_AWS.md`](../docs/MOTOR_RELEVO_AWS.md).

- [Como rodar](#como-rodar)
- [Como funciona](#como-funciona)
- [Perfis e parâmetros](#perfis-e-parâmetros)
- [Relevo e cache](#relevo-e-cache)
- [O que mudou em relação ao motor anterior](#o-que-mudou-em-relação-ao-motor-anterior)
- [Desempenho medido](#desempenho-medido)

## Como rodar

```bash
./scripts/run-motor.sh                 # contra o PostGIS local
./scripts/run-motor.sh --db supabase   # contra o Supabase
```

O relevo usa o AWS Open Data e **não precisa de chave de API**. As variáveis de banco ficam em `MOTOR/.env.properties` (ou `.env.supabase`). O mirror local/NAS é opcional:

```properties
DEM_MIRROR_DIR=/mnt/tecsys-dem-mirror
```

Sem mirror, o motor usa o cache e depois o S3 público. Se o relevo não puder ser obtido, o projeto termina em `FALHA` com o motivo.

Testes: `mvn test`. O `MotorApplicationTests` precisa de `DB_URL`, `DB_USER` e `DB_PASSWORD`; os outros rodam sem banco. O teste de rede é opt-in: `mvn test -Dtest=DemServiceNetworkTest -DexcludedGroups=`.

## Como funciona

1. **Dados.** Pontos são os consumidores `ucbt`, `ucmt_pj` e `ucat_pj` que passam nos filtros do projeto. Candidatos a gateway são os transformadores `untrmt` e `untrat`.
   - O motor também considera trafos fora da área, mas ao alcance dela (#TG-138). Eles saem marcados com `outside_filters: true`.
   - O filtro de bairro usa a mesma regra do mapa: `ILIKE '%nome%'` (#TG-98).
2. **Agrupamento.** Pontos no mesmo lugar e com a mesma altura têm a mesma cobertura e viram um único "local". Em SJC, 31 mil pontos viram 18,7 mil locais.
3. **Relevo.** Usa o Copernicus GLO-30 (30 m), lido em float32, ou seja, em metros de verdade. O terreno é amostrado por interpolação bilinear.
4. **Visada.** Para cada candidato, o motor marca quais pontos ele enxerga. O padrão é o viewshed por raios (`RayViewshed`): cerca de 4 mil raios por gateway, acumulando o maior ângulo de elevação do terreno, com curvatura da Terra. O custo cresce com a área, não com o número de pares. Os candidatos são processados em paralelo.
5. **Otimização.** É uma cobertura de conjuntos (`SetCover`):
   1. guloso (quem cobre mais pontos novos);
   2. remoção de redundantes e busca local 2→1;
   3. até 4 milhões de pares visíveis, o solver exato **HiGHS** (via OR-Tools), que prova o ótimo ou dá um limite inferior;
   4. acima disso, LNS (remove gateways vizinhos e recobre os pontos órfãos de forma exata) e relaxação lagrangiana para o limite inferior.
6. **Resultado.** Gateways em ordem de ganho, com a curva de cobertura acumulada. O `summary` traz `lower_bound_gateways` e `optimality_gap_pct`, ou seja, quanto, no máximo, ainda pode faltar para o ótimo. `0` quer dizer ótimo provado.

| Pacote | Conteúdo |
|---|---|
| `engine/MotorEngine` | orquestração, alturas, agrupamento |
| `engine/MotorParams`, `MotorProperties` | perfis e parâmetros (`app.motor.*`) |
| `engine/Radio`, `Geo` | FSPL, orçamento, horizonte, Fresnel, projeção local |
| `engine/LineOfSight`, `RayViewshed` | visada par a par e viewshed por raios |
| `engine/CoverageBuilder`, `CoverageMatrix` | matriz esparsa de cobertura, em paralelo |
| `engine/SetCover` | guloso, redundância, busca local, HiGHS, LNS, lagrangiano |
| `terrain/DemService`, `GeoTiffReader` | download AWS, cache, mirror, mosaico e leitura float32 do relevo |
| `DecisionRepository` | consultas ao PostGIS |

## Perfis e parâmetros

`MOTOR_PROFILE` escolhe a base. O padrão é `tecsys`.

| Perfil | Para que serve | Alcance | Alturas | Visada |
|---|---|---|---|---|
| `tecsys` | modelo do parceiro (doc *API_relevo_doc*) | FSPL ≤ orçamento de 141 dB e horizonte de rádio (~19,3 km) | gateway 6 m, sensor 5 m | raios a cada 30 m, com curvatura |
| `compat-preciso` | premissas do motor anterior, com visada precisa | 4 km fixo | por estrutura da BDGD | perfil a cada 30 m, com curvatura |
| `compat` | réplica do motor anterior | 4 km fixo | por estrutura da BDGD | 5 amostras, pixel mais próximo, folga de 1,5 m |

Nenhum valor de RF fica fixo no código: qualquer campo do perfil pode ser trocado por variável de ambiente, em `MOTOR/.env.properties` ou direto no container. Vazio mantém o valor do perfil.

| Variável | `tecsys` | Significado |
|---|---|---|
| `MOTOR_FREQUENCY_MHZ` | 915 | frequência |
| `MOTOR_TX_POWER_DBM` | 21 | potência de transmissão |
| `MOTOR_SENSITIVITY_DBM` | −120 | sensibilidade do receptor |
| `MOTOR_ANTENNA_GAINS_DB` | 0 | ganho das antenas (Tx + Rx) |
| `MOTOR_EXTRA_LOSS_DB` | 0 | perdas extras (vegetação, obstáculos) |
| `MOTOR_GATEWAY_HEIGHT_M` / `MOTOR_SENSOR_HEIGHT_M` | 6 / 5 | alturas das antenas |
| `MOTOR_BDGD_HEIGHTS` | false | alturas por estrutura da BDGD (15 / 10,5 / 3,5 m; pontos 10 / 6 / 3 m) |
| `MOTOR_FIXED_RANGE_M` | — | alcance fixo; ignora o orçamento |
| `MOTOR_MAX_RANGE_M` | — | teto de alcance |
| `MOTOR_LINE_OF_SIGHT` | RAYS | `RAYS`, `PROFILE` ou `TEAM` |
| `MOTOR_LOS_STEP_M` | 30 | passo da visada |
| `MOTOR_FRESNEL_FRACTION` | 0 | fração da 1ª zona de Fresnel que precisa ficar livre (0,6 = projeto conservador) |
| `MOTOR_EARTH_CURVATURE` / `MOTOR_REFRACTION_K` | true / 4/3 | curvatura da Terra e refração |
| `MOTOR_NEIGHBOR_CANDIDATES` | true | trafos ao alcance da área (#TG-138) |
| `MOTOR_EXACT_SECONDS` | 180 | tempo do solver exato (0 = só heurística) |
| `MOTOR_USE_TERRAIN` | true | `false` = terreno plano, só para teste |
| `MOTOR_THREADS` | 0 | threads da visada (0 = núcleos − 1) |

O `gateway_range_m` do resumo é o raio de busca usado. No perfil `tecsys` ele é o horizonte de rádio (~19 km), não um raio fixo de 4 km.

## Relevo e cache

- O relevo vem do **Copernicus DEM GLO-30 público no AWS Open Data**, em tiles COG de 1° x 1°, sem chave e sem cota diária.
- A ordem de busca é **cache → mirror → catálogo → S3**. Cada tile é validado antes de entrar no cache.
  - Tile fora do catálogo da AWS (`tileList.txt`) é só mar: vira 0 m sem consultar o S3. Detalhes em [`docs/MOTOR_RELEVO_AWS.md`](../docs/MOTOR_RELEVO_AWS.md#oceano).
  - Pelo `run-motor.sh`, o cache fica no volume Docker `tecsys-dem-cache`.
  - Fora do Docker, fica em `cache/dem` (`DEM_CACHE_DIR`).
  - O cache novo fica em `<DEM_CACHE_DIR>/aws-copernicus/<tile>/<tile>.tif`.
- O mirror local/NAS é opcional (`DEM_MIRROR_DIR`), montado read-only. Use `./scripts/sync-dem-mirror.sh` para semeá-lo. O cache antigo da OpenTopography é preservado, mas ignorado.
- O perfil `tecsys` precisa de relevo numa margem de ~19 km em volta da área.
- Se o relevo não puder ser obtido (S3 fora, tile do catálogo ausente no cache/mirror), o projeto termina em **`FALHA`** com o motivo no log. Ponto ou candidato em tile de mar também falha. O motor anterior caía em terreno plano sem avisar.
- O domínio suportado é latitude -50° a +50°, longitude -180° a +180°, sem antimeridiano.

## O que mudou em relação ao motor anterior

| Problema do motor anterior | Agora |
|---|---|
| #TG-132: o GeoTIFF era lido como imagem RGB de 8 bits (714 m virava 126), o que criava morros falsos e de 3,4 a 21 vezes mais gateways | leitura float32 com `getRasterData` |
| #TG-97: sem chave, ou com a cota esgotada, calculava em terreno plano e marcava `SUCESSO`: declarava ~99,9% de cobertura quando a real ficava entre 43% e 69% | falha com mensagem clara |
| #TG-139: OpenTopography exigia chave e tinha cota diária | Copernicus GLO-30 no AWS Open Data, sem chave e sem cota, com mirror local opcional |
| Visada com 5 amostras e pixel mais próximo: morros entre as amostras passavam despercebidos | perfil a cada 30 m, bilinear, com curvatura da Terra |
| O guloso parava na primeira solução | busca local + solver exato (ótimo provado ou limite inferior) |
| Alcance fixo de 4 km no código | orçamento de enlace e horizonte de rádio, tudo parametrizável |
| #TG-138: trafo logo fora da área nunca era candidato | candidatos ao alcance da área |
| #TG-98: bairro comparado com igualdade exata, enquanto o mapa usa `ILIKE` | mesma regra do mapa |
| #TG-96: o motor podia ler o projeto antes do commit do backend | espera até 5 s pelo projeto |
| #TG-134: erro grave (ex.: falta de memória) deixava o projeto em "Enviado" | marca `FALHA` também nesse caso |

A imagem Docker passou a usar `eclipse-temurin:17-jre-jammy` em vez da Alpine, porque o OR-Tools traz bibliotecas nativas que precisam de glibc. Com isso, a imagem foi de ~210 MB para ~400 MB.

## Desempenho medido

EDP SP (distribuidora 391), PostGIS local, 8 núcleos, em 05/11/2026. A coluna Python é o motor de referência que deu origem a este, rodado com os mesmos dados.

| Cenário | Perfil | Gateways | Limite inferior | Cobertura | Tempo | Python |
|---|---|---|---|---|---|---|
| Caçapava (3.849 pontos) | `tecsys` | **22** | 22 (ótimo) | 100% | 24 s | 22 gw, 154 s |
| Caçapava | `compat` | **23** | 23 (ótimo) | 99,97% | 92 s | 23 gw, 78 s |
| São José dos Campos (31.084 pontos) | `tecsys` | **211** | 202–203 | 100% | 4 min | 211 gw, 18 min |

A memória de pico do container em SJC ficou em ~1,9 GB.
