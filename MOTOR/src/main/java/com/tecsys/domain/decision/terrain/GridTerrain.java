package com.tecsys.domain.decision.terrain;

/**
 * Grade regular em graus (WGS 84), guardada em float32 linha a linha.
 * {@code lon0}/{@code lat0} são o centro do pixel [0, 0] (canto noroeste); {@code dx}, {@code dy} &gt; 0.
 */
public final class GridTerrain implements Terrain {

    private final float[] z;
    private final int height;
    private final int width;
    private final double lon0;
    private final double lat0;
    private final double dx;
    private final double dy;
    private final String source;
    private final double min;
    private final double max;

    public GridTerrain(float[] z, int height, int width, double lon0, double lat0, double dx, double dy, String source) {
        if (z.length != height * width) {
            throw new IllegalArgumentException("Grade de relevo com tamanho inconsistente.");
        }
        if (height < 2 || width < 2) {
            throw new IllegalArgumentException("Grade de relevo precisa de pelo menos 2×2 pixels.");
        }
        this.z = z;
        this.height = height;
        this.width = width;
        this.lon0 = lon0;
        this.lat0 = lat0;
        this.dx = dx;
        this.dy = dy;
        this.source = source;
        double mn = Double.POSITIVE_INFINITY;
        double mx = Double.NEGATIVE_INFINITY;
        for (float v : z) {
            mn = Math.min(mn, v);
            mx = Math.max(mx, v);
        }
        this.min = mn;
        this.max = mx;
    }

    @Override
    public double sample(double lat, double lon) {
        double lin = (lat0 - lat) / dy;
        double col = (lon - lon0) / dx;
        lin = clamp(lin, height - 1.000001);
        col = clamp(col, width - 1.000001);
        int i0 = (int) lin;
        int j0 = (int) col;
        double fi = lin - i0;
        double fj = col - j0;
        int k = i0 * width + j0;
        double a = z[k];
        double b = z[k + 1];
        double c = z[k + width];
        double d = z[k + width + 1];
        return (a * (1 - fj) + b * fj) * (1 - fi) + (c * (1 - fj) + d * fj) * fi;
    }

    @Override
    public double sampleNearest(double lat, double lon) {
        int i = (int) Math.min(Math.max(Math.rint((lat0 - lat) / dy), 0), height - 1);
        int j = (int) Math.min(Math.max(Math.rint((lon - lon0) / dx), 0), width - 1);
        return z[i * width + j];
    }

    private static double clamp(double v, double hi) {
        if (v < 0) return 0;
        return Math.min(v, hi);
    }

    @Override
    public String source() {
        return source;
    }

    @Override
    public double minElevation() {
        return min;
    }

    @Override
    public double maxElevation() {
        return max;
    }

    public int height() { return height; }
    public int width() { return width; }
    public double lon0() { return lon0; }
    public double lat0() { return lat0; }
    public double dx() { return dx; }
    public double dy() { return dy; }
    float[] data() { return z; }
}
