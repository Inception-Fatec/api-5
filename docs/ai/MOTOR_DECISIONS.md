# Motor terrain decisions (ADR log)

## TG-139: AWS Copernicus GLO-30 replaces OpenTopography

Status: accepted.

### Context

The motor used OpenTopography COP30 in 0.25 degree blocks. The free API has a daily
call quota (50 non-academic, 200 academic) and requires an API key. The same
Copernicus GLO-30 dataset is available anonymously on AWS Open Data in 1 degree COG
tiles, without an account or daily quota.

### Decision

Use `https://copernicus-dem-30m.s3.amazonaws.com` as the only runtime terrain source.
Remove OpenTopography from runtime configuration and documentation. Do not fall back
to OpenTopography.

### Consequences

- No API key or account is required.
- The tile count drops because each tile is 1 x 1 degree.
- The GeoTIFF reader must handle AWS COG compression. If it cannot, stop and report
  before adding a new dependency.
- Copernicus attribution is mandatory in human docs and distributed reports.

## Mirror on NAS

Status: accepted.

### Decision

Support an optional read-only local mirror at `DEM_MIRROR_DIR`. Lookup order is
cache, mirror, S3. On a mirror hit, copy the tile into cache before reading. If the
mirror is configured but unavailable, log a warning and continue to S3. If S3 also
fails and the tile is absent, fail clearly.

### Consequences

- The motor works without a NAS.
- Tests use local temporary directories.
- The NAS protocol (NFS or SMB) is an infrastructure detail; the code only sees a
  mounted directory. NFS is the default recommendation for a Linux Docker host.

## Cache layout

Status: accepted.

### Decision

New cache lives under `<DEM_CACHE_DIR>/aws-copernicus/<tile>/<tile>.tif`. The old
OpenTopography cache (`indice.json`, `dem_<hash>.tif`) is preserved and ignored.

### Consequences

- No collision with old cache files.
- Rollback and comparison remain possible.
- Do not delete the old cache automatically.

## Geographic domain

Status: accepted.

### Decision

Accept only `south >= -50`, `north <= 50`, `west >= -180`, `east <= 180`,
`south < north`, and `west < east`. Reject antimeridian crossing with a clear error.

### Consequences

- The existing mosaic can assume constant pixel size.
- All current Brazilian coverage is supported.
- The error message must explain the supported domain.

## COG compatibility gate

Status: accepted and validated. The real `S23_00_W046_00` tile was read as
3600 x 3600 Float32 DEFLATE/predictor 3 by `commons-imaging 1.0.0-alpha5`.

### Decision

Validate one real AWS COG with the current `commons-imaging 1.0.0-alpha5` reader
before implementing the full pipeline. If the reader fails, stop and report options
before adding a new dependency.

### Consequences

- No dependency is added without an explicit decision.
- The spike is a hard gate for the implementation.

## Initial mirror coverage

Status: accepted.

### Decision

Seed the mirror for Sao Jose dos Campos, Caçapava, and Campos do Jordao. Serra da
Mantiqueira is out of scope for now.

### Consequences

- The ETL team is responsible for adding Campos do Jordao data.
- The sync script accepts a bbox or an explicit tile list.
