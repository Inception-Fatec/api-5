package com.tecsys.domain.decision.terrain;

import org.apache.commons.imaging.FormatCompliance;
import org.apache.commons.imaging.ImagingException;
import org.apache.commons.imaging.bytesource.ByteSource;
import org.apache.commons.imaging.formats.tiff.TiffContents;
import org.apache.commons.imaging.formats.tiff.TiffDirectory;
import org.apache.commons.imaging.formats.tiff.TiffField;
import org.apache.commons.imaging.formats.tiff.TiffImagingParameters;
import org.apache.commons.imaging.formats.tiff.TiffRasterData;
import org.apache.commons.imaging.formats.tiff.TiffReader;

import java.io.IOException;
import java.nio.file.Path;
import java.util.Arrays;

/**
 * Lê um GeoTIFF de elevação (Copernicus DEM GLO-30: float32, DEFLATE, em blocos) como
 * <b>valores em metros</b>.
 *
 * <p>O motor antigo usava {@code Imaging.getBufferedImage}, que converte o float32 para uma
 * imagem RGB de 8 bits: 714 m virava 126 (issue #TG-132). Aqui a leitura é feita com
 * {@code getRasterData}, que devolve os floats originais.
 */
public final class GeoTiffReader {

    private static final int TAG_MODEL_PIXEL_SCALE = 33550;
    private static final int TAG_MODEL_TIEPOINT = 33922;
    private static final int TAG_GEO_KEY_DIRECTORY = 34735;
    private static final int TAG_GDAL_NODATA = 42113;
    private static final int GEOKEY_RASTER_TYPE = 1025;
    private static final int RASTER_PIXEL_IS_POINT = 2;

    private GeoTiffReader() {
    }

    public static GridTerrain read(Path file) throws IOException {
        TiffDirectory dir;
        try {
            TiffContents contents = new TiffReader(false)
                    .readDirectories(ByteSource.file(file.toFile()), true, FormatCompliance.getDefault());
            dir = contents.directories.get(0);
        } catch (ImagingException e) {
            throw new IOException("GeoTIFF inválido: " + file.getFileName() + " (" + e.getMessage() + ")", e);
        }
        if (!dir.hasTiffFloatingPointRasterData()) {
            throw new IOException("GeoTIFF sem dados de elevação em ponto flutuante: " + file.getFileName());
        }

        double[] scale = null;
        double[] tie = null;
        int[] geoKeys = null;
        Double nodata = null;
        for (TiffField f : dir.getDirectoryEntries()) {
            switch (f.getTag()) {
                case TAG_MODEL_PIXEL_SCALE -> scale = f.getDoubleArrayValue();
                case TAG_MODEL_TIEPOINT -> tie = f.getDoubleArrayValue();
                case TAG_GEO_KEY_DIRECTORY -> geoKeys = f.getIntArrayValue();
                case TAG_GDAL_NODATA -> nodata = parseNodata(f.getStringValue());
                default -> { }
            }
        }
        if (scale == null || tie == null || tie.length < 6) {
            throw new IOException("GeoTIFF sem georreferência (ModelPixelScale/ModelTiepoint): " + file.getFileName());
        }

        TiffRasterData raster;
        try {
            raster = dir.getRasterData(new TiffImagingParameters());
        } catch (ImagingException e) {
            throw new IOException("Falha ao ler o relevo de " + file.getFileName() + ": " + e.getMessage(), e);
        }
        int w = raster.getWidth();
        int h = raster.getHeight();
        float[] z = Arrays.copyOf(raster.getData(), w * h);

        boolean pixelIsPoint = false;
        if (geoKeys != null) {
            for (int k = 4; k + 3 < geoKeys.length; k += 4) {
                if (geoKeys[k] == GEOKEY_RASTER_TYPE) {
                    pixelIsPoint = geoKeys[k + 3] == RASTER_PIXEL_IS_POINT;
                }
            }
        }

        double dx = scale[0];
        double dy = scale[1];
        double lon0 = tie[3] - tie[0] * dx;
        double lat0 = tie[4] + tie[1] * dy;
        if (!pixelIsPoint) {
            // PixelIsArea: o tiepoint é o canto do pixel; a grade usa o centro
            lon0 += dx / 2;
            lat0 -= dy / 2;
        }

        fillInvalid(z, nodata);
        return new GridTerrain(z, h, w, lon0, lat0, dx, dy, "Copernicus GLO-30:" + file.getFileName());
    }

    private static Double parseNodata(String s) {
        if (s == null) return null;
        try {
            return Double.parseDouble(s.replace("\u0000", "").trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** Valores sem dado (nodata, NaN, fora de −500..9000 m) recebem a mediana dos válidos. */
    static void fillInvalid(float[] z, Double nodata) {
        int bad = 0;
        for (float v : z) {
            if (isInvalid(v, nodata)) bad++;
        }
        if (bad == 0) return;
        float fill = 0f;
        int good = z.length - bad;
        if (good > 0) {
            float[] valid = new float[good];
            int n = 0;
            for (float v : z) {
                if (!isInvalid(v, nodata)) valid[n++] = v;
            }
            Arrays.sort(valid);
            fill = good % 2 == 1 ? valid[good / 2] : (valid[good / 2 - 1] + valid[good / 2]) / 2f;
        }
        for (int i = 0; i < z.length; i++) {
            if (isInvalid(z[i], nodata)) z[i] = fill;
        }
    }

    private static boolean isInvalid(float v, Double nodata) {
        return !Float.isFinite(v) || v < -500f || v > 9000f || (nodata != null && v == nodata.floatValue());
    }
}
