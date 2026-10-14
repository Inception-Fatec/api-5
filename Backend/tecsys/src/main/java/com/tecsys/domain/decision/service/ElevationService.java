package com.tecsys.domain.decision.service;

import org.apache.commons.imaging.Imaging;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.awt.image.BufferedImage;
import java.awt.image.Raster;
import java.io.File;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class ElevationService {

    @Value("${app.elevation.root-folder:./relevo_sjc_cacapava}")
    private String rootElevationFolder;

    private final Map<TileKey, File> tileFileCache = new ConcurrentHashMap<>();
    private final Map<TileKey, BufferedImage> imageCache = new ConcurrentHashMap<>();

    /**
     * Obtém a altitude (Z em metros) para qualquer coordenada geográfica.
     * Utiliza o cache temporário da requisição para evitar releituras no mesmo cálculo.
     */
    public double getElevation(double latitude, double longitude, Map<String, Double> requestCache) {
        // Chave de cache arredondada a ~11 metros de precisão (4 casas decimais)
        String cacheKey = String.format("%.4f,%.4f", latitude, longitude);
        if (requestCache != null && requestCache.containsKey(cacheKey)) {
            return requestCache.get(cacheKey);
        }

        int latFloor = (int) Math.floor(latitude);
        int lonFloor = (int) Math.floor(longitude);
        TileKey tileKey = new TileKey(latFloor, lonFloor);

        File tifFile = tileFileCache.computeIfAbsent(tileKey, this::findTifForTile);

        double altitude = 0.0;
        if (tifFile != null && tifFile.exists()) {
            altitude = readElevationFromRaster(tifFile, tileKey, latitude, longitude, latFloor, lonFloor);
        }

        if (requestCache != null) {
            requestCache.put(cacheKey, altitude);
        }

        return altitude;
    }

    private File findTifForTile(TileKey key) {
        File folder = new File(rootElevationFolder, key.toFolderName());
        if (!folder.exists() || !folder.isDirectory()) {
            File directFile = new File(rootElevationFolder, key.toFolderName() + ".tif");
            return directFile.exists() ? directFile : null;
        }

        File[] files = folder.listFiles((dir, name) -> name.toLowerCase().endsWith(".tif"));
        return (files != null && files.length > 0) ? files[0] : null;
    }

    private double readElevationFromRaster(File tifFile, TileKey tileKey, double lat, double lng, int latFloor, int lonFloor) {
        try {
            // Os arquivos Copernicus DEM possuem grade de 3600 x 3600 pixels (30m de resolução)
            double deltaLat = Math.abs(lat - latFloor);
            double deltaLon = Math.abs(lng - lonFloor);

            int pixelX = Math.min(3599, Math.max(0, (int) (deltaLon * 3600)));
            int pixelY = Math.min(3599, Math.max(0, (int) ((1.0 - deltaLat) * 3600)));

            return readPixelValue(tifFile, tileKey, pixelX, pixelY);
        } catch (Exception e) {
            return 0.0;
        }
    }

    private double readPixelValue(File tifFile, TileKey key, int x, int y) {
        try {
            BufferedImage image = imageCache.computeIfAbsent(key, k -> {
                try {
                    return Imaging.getBufferedImage(tifFile);
                } catch (Exception e) {
                    return null;
                }
            });

            if (image == null) {
                return 0.0;
            }

            Raster raster = image.getRaster();
            
            // Lê o valor da amostra float/int contida na matriz de elevação
            float sample = raster.getSampleFloat(x, y, 0);
            return (sample < -1000 || sample > 9000) ? 0.0 : sample; // Trata valores nulos/outliers
        } catch (Exception e) {
            return 0.0;
        }
    }

    public record TileKey(int latDegree, int lonDegree) {
        public String toFolderName() {
            char latHemi = latDegree >= 0 ? 'N' : 'S';
            char lonHemi = lonDegree >= 0 ? 'E' : 'W';
            return String.format("Copernicus_DSM_COG_10_%c%02d_00_%c%03d_00_DEM",
                    latHemi, Math.abs(latDegree), lonHemi, Math.abs(lonDegree));
        }
    }
}