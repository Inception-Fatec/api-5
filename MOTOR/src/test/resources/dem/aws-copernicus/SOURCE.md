# AWS Copernicus GLO-30 test fixture

- Source tile: `Copernicus_DSM_COG_10_S23_00_W046_00_DEM`
- AWS key: `Copernicus_DSM_COG_10_S23_00_W046_00_DEM/Copernicus_DSM_COG_10_S23_00_W046_00_DEM.tif`
- Source URL: `https://copernicus-dem-30m.s3.amazonaws.com/Copernicus_DSM_COG_10_S23_00_W046_00_DEM/Copernicus_DSM_COG_10_S23_00_W046_00_DEM.tif`
- Crop window (WGS84): upper-left `-45.60, -22.65`, lower-right `-45.55, -22.70`
- Output: 181 x 181 pixels, Float32, DEFLATE with predictor 3, COG layout
- SHA-256: `31a9f8b0ffbc3d9449c5b7097536c5d1ad89a3d8179e84758e36c05b57524f0f`
- Generated with:

```bash
docker run --rm -v "$PWD:/data" ghcr.io/osgeo/gdal:alpine-small-latest \
  gdal_translate -of COG -co COMPRESS=DEFLATE -co PREDICTOR=3 \
  -projwin -45.60 -22.65 -45.55 -22.70 \
  /data/S23_00_W046_00.tif \
  /data/S23_00_W046_00_campos_cog.tif
```

This fixture is a small extract of the public Copernicus DEM GLO-30 dataset. The
dataset is distributed under the Copernicus DEM license; attribution is required.

Official notice:

> © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided
> under COPERNICUS by the European Union and ESA; all rights reserved

See `docs/MOTOR_RELEVO_AWS.md` for the derived-product notice and citation DOI.
