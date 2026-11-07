# Motor terrain source: AWS Copernicus GLO-30 implementation reference

Status: implementation reference for TG-139.

This document is the source of truth for an AI agent or developer changing the motor
terrain pipeline. Human-facing instructions are in `docs/MOTOR_RELEVO_AWS.md` (pt-BR).

## Objective

Replace OpenTopography COP30 downloads with the public AWS Open Data copy of
Copernicus DEM GLO-30. The motor must keep returning real elevation in metres and must
never silently fall back to flat terrain.

## Non-goals

- CDSE, Planetary Computer, or any authenticated provider.
- A global mirror of the Copernicus dataset.
- Reusing the old OpenTopography 0.25 degree cache as if it were a new cache.
- Supporting the antimeridian or latitudes outside the validated domain.
- Changing the decision algorithm, radio model, or result format.

## Source

- HTTPS base: `https://copernicus-dem-30m.s3.amazonaws.com`
- S3 bucket: `s3://copernicus-dem-30m`
- Access: anonymous public GET. No AWS account, access key, session token, or quota.
- Dataset: Copernicus DEM GLO-30, 30 m DSM 2021, 1 x 1 degree COG tiles.
- Tile key: `<tile>/<tile>.tif`
- Tile name: `Copernicus_DSM_COG_10_{N|S}{lat}_00_{E|W}{lon}_00_DEM.tif`
- `{lat}` and `{lon}` are the floor of the south and west bounds, zero-padded.
  Example: bbox around Sao Jose dos Campos and Campos do Jordao uses
  `Copernicus_DSM_COG_10_S24_00_W046_00_DEM`.
- A tile named `S23_00_W046_00` covers `lat -23..-22`, `lon -46..-45`.

## Geographic domain

Accepted input box:

- `south < north`
- `west < east` (antimeridian crossing is rejected)
- `south >= -50`, `north <= 50`
- `west >= -180`, `east <= 180`

Anything outside this domain fails with a clear `IOException`. The reason is that the
current mosaic assumes constant `dx` and `dy`; high-latitude Copernicus tile geometry
and antimeridian bboxes would break that assumption.

## Lookup order

For each required 1 degree tile:

1. cache;
2. local mirror, when `DEM_MIRROR_DIR` is configured and readable;
3. AWS public S3.

A mirror hit is copied into the cache before reading. A mirror file that is unreadable
or corrupt is ignored and the tile is fetched from S3. A configured but unavailable
mirror logs a warning and does not fail the calculation.

If a tile cannot be obtained from cache, mirror, or S3, the project fails with the tile
name and the reason. Flat terrain is used only when `MOTOR_USE_TERRAIN=false`.

## Cache

- Root: `${DEM_CACHE_DIR:cache/dem}`
- AWS cache subdirectory: `<cache-root>/aws-copernicus`
- Layout: `<cache-root>/aws-copernicus/<tile>/<tile>.tif`
- Downloads are written to a `.part` file, validated as a readable float32 GeoTIFF,
  then atomically moved into place.
- A corrupt cache file is deleted and fetched again.
- The old OpenTopography cache remains untouched. It may contain
  `indice.json` and `dem_<hash>.tif` files. The new pipeline never reads them.

## Mirror

- Root: `DEM_MIRROR_DIR` (optional).
- The motor mounts it read-only.
- Layout mirrors S3: `<mirror-root>/<tile>/<tile>.tif`.
- A flat `<mirror-root>/<tile>.tif` is also accepted for operational flexibility.
- The mirror is seeded by `scripts/sync-dem-mirror.sh`, which runs on the host with
  write access.
- Initial coverage: Sao Jose dos Campos, Caçapava, and Campos do Jordao.
- Mirror capacity is small for this coverage; reserve 2 GB of headroom.

## Configuration

`MOTOR/src/main/resources/application.yml`:

```yaml
app:
  terrain:
    cache-dir: ${DEM_CACHE_DIR:cache/dem}
    mirror-dir: ${DEM_MIRROR_DIR:}
    download-attempts: ${DEM_DOWNLOAD_ATTEMPTS:4}
    aws:
      base-url: ${DEM_AWS_BASE_URL:https://copernicus-dem-30m.s3.amazonaws.com}
```

There is no API key. OpenTopography settings and variables must not remain in runtime
configuration, scripts, compose, or README instructions.

## Tests

- Unit tests: tile name/bounds, domain rejection, tile enumeration, cache hit, mirror
  hit and copy, corrupt cache fallback, S3 404, retry, and clear failure messages.
- Integration tests: mosaic of two synthetic adjacent 1 degree tiles, using the real
  AWS tile layout.
- Network test: opt-in with `@Tag("network")`, downloads one real tile and validates
  that it is readable by `GeoTiffReader`.
- Fixture: one small real COG (<1 MB) under
  `MOTOR/src/test/resources/dem/aws-copernicus/`, plus `SOURCE.md` with tile name,
  bbox, checksum, generation command, and license.

## License

Copernicus DEM is distributed under the Copernicus DEM license. Attribution is a
license requirement, not an optional courtesy. Human documentation and the report/UI
when the product is distributed must include the official notice. See
`docs/MOTOR_RELEVO_AWS.md`.

## Failure semantics

- Domain violation: fail before any network access.
- Cache corrupt: delete, continue.
- Mirror missing or corrupt: warn, continue to S3.
- S3 HTTP error after retries: fail with tile, HTTP status, and URL.
- S3 body is not a TIFF or not float32: fail and do not cache.
- No terrain and `MOTOR_USE_TERRAIN=true`: project status `FALHA`.

## Migration notes

- Remove `OPENTOPOGRAPHY_API_KEY`, `OPENTOPOGRAPHY_GLOBALDEM_URL`, and
  `OPENTOPOGRAPHY_DATASET` from code, config, scripts, env examples, Dockerfile
  comments, and docs.
- Keep `DEM_CACHE_DIR` and the Docker cache volume.
- Keep the old cache for rollback and comparison; do not delete it automatically.
- Update log messages so they no longer claim OpenTopography as the source.
