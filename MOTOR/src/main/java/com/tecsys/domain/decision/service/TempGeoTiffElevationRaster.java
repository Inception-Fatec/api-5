package com.tecsys.domain.decision.service;

import org.apache.commons.imaging.Imaging;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.awt.image.Raster;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;

public class TempGeoTiffElevationRaster implements AreaElevationRaster {

    private static final Logger log = LoggerFactory.getLogger(TempGeoTiffElevationRaster.class);

    private final Path tempFilePath;
    private final double south;
    private final double north;
    private final double west;
    private final double east;

    private BufferedImage image;
    private Raster raster;
    private final int width;
    private final int height;

    public TempGeoTiffElevationRaster(Path tempFilePath, double south, double north, double west, double east) {
        this.tempFilePath = tempFilePath;
        this.south = south;
        this.north = north;
        this.west = west;
        this.east = east;

        BufferedImage loadedImage = null;
        Raster loadedRaster = null;
        int imgWidth = 0;
        int imgHeight = 0;

        if (tempFilePath != null && Files.exists(tempFilePath)) {
            File file = tempFilePath.toFile();
            try {
                loadedImage = Imaging.getBufferedImage(file);
            } catch (Exception e) {
                log.debug("Imaging falhou ao carregar GeoTIFF, tentando ImageIO: {}", e.getMessage());
                try {
                    loadedImage = ImageIO.read(file);
                } catch (Exception ex) {
                    log.error("Não foi possível carregar a imagem do GeoTIFF: {}", ex.getMessage());
                }
            }

            if (loadedImage != null) {
                loadedRaster = loadedImage.getRaster();
                imgWidth = loadedImage.getWidth();
                imgHeight = loadedImage.getHeight();
                log.info("GeoTIFF carregado com sucesso: {}x{} pixels para a BBox [S:{}, N:{}, W:{}, E:{}]",
                        imgWidth, imgHeight, south, north, west, east);
            }
        }

        this.image = loadedImage;
        this.raster = loadedRaster;
        this.width = imgWidth;
        this.height = imgHeight;
    }

    @Override
    public double getElevation(double latitude, double longitude) {
        if (raster == null || width <= 0 || height <= 0) {
            return 0.0;
        }

        try {
            // Mapeia coordenadas geográficas (WGS84) para o índice de pixel da matriz
            // Longitude: west -> x=0, east -> x=width-1
            // Latitude: north -> y=0 (topo), south -> y=height-1 (base)
            double xNorm = (longitude - west) / (east - west);
            double yNorm = (north - latitude) / (north - south);

            int pixelX = (int) Math.round(xNorm * (width - 1));
            int pixelY = (int) Math.round(yNorm * (height - 1));

            // Clamping de segurança
            pixelX = Math.max(0, Math.min(width - 1, pixelX));
            pixelY = Math.max(0, Math.min(height - 1, pixelY));

            float sample = raster.getSampleFloat(pixelX, pixelY, 0);

            // Descarta valores NoData/outliers de DEM (ex: -9999, -32768)
            if (Float.isNaN(sample) || sample < -1000 || sample > 9000) {
                return 0.0;
            }

            return sample;
        } catch (Exception e) {
            return 0.0;
        }
    }

    @Override
    public void close() {
        // Libera referências da imagem para o Garbage Collector
        this.image = null;
        this.raster = null;

        // Exclui o arquivo temporário do disco
        if (tempFilePath != null) {
            try {
                boolean deleted = Files.deleteIfExists(tempFilePath);
                if (deleted) {
                    log.info("Arquivo GeoTIFF temporário excluído com sucesso: {}", tempFilePath);
                }
            } catch (Exception e) {
                log.warn("Erro ao tentar excluir arquivo temporário {}: {}", tempFilePath, e.getMessage());
            }
        }
    }
}

