# Motor terrain context (AI quick reference)

The motor obtains elevation for the project area before running line-of-sight and
set-cover optimization. Terrain failures must fail the project; they must never be
replaced by silent flat terrain.

## Current source

AWS Open Data Copernicus DEM GLO-30:

- base URL: `https://copernicus-dem-30m.s3.amazonaws.com`
- anonymous public GET, no credentials, no quota
- 1 x 1 degree COG tiles
- key: `<tile>/<tile>.tif`
- name: `Copernicus_DSM_COG_10_{N|S}{lat}_00_{E|W}{lon}_00_DEM.tif`

OpenTopography is no longer a runtime source.

## Lookup

For every required tile:

1. cache: `<DEM_CACHE_DIR>/aws-copernicus/<tile>/<tile>.tif`
2. mirror: `<DEM_MIRROR_DIR>/<tile>/<tile>.tif` (read-only, optional)
3. AWS S3

A mirror hit is copied into cache before reading. A mirror miss or corrupt file falls
through to S3. An unavailable mirror logs a warning.

## Guardrails

- Supported box: `south >= -50`, `north <= 50`, `west >= -180`, `east <= 180`,
  `south < north`, `west < east`.
- Antimeridian crossing is rejected.
- Old OpenTopography cache is preserved but ignored.
- `MOTOR_USE_TERRAIN=false` is the only way to get flat terrain, and it is for tests.

## Important files

- `MOTOR/src/main/java/com/tecsys/domain/decision/terrain/DemService.java`
- `MOTOR/src/main/java/com/tecsys/domain/decision/terrain/GeoTiffReader.java`
- `MOTOR/src/main/java/com/tecsys/domain/decision/engine/MotorEngine.java`
- `MOTOR/src/main/resources/application.yml`
- `scripts/run-motor.sh`
- `scripts/sync-dem-mirror.sh`
- `docs/MOTOR_RELEVO_AWS.md`

## Initial coverage

Sao Jose dos Campos, Caçapava, and Campos do Jordao. Serra da Mantiqueira is out of
scope for now.
