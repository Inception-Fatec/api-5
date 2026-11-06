package com.tecsys.domain.decision.engine;

/** Projeção local em metros e distância geodésica. */
public final class Geo {

    private Geo() {
    }

    public static double haversineM(double lat1, double lon1, double lat2, double lon2) {
        double p1 = Math.toRadians(lat1);
        double p2 = Math.toRadians(lat2);
        double dp = p2 - p1;
        double dl = Math.toRadians(lon2 - lon1);
        double sp = Math.sin(dp / 2);
        double sl = Math.sin(dl / 2);
        double a = sp * sp + Math.cos(p1) * Math.cos(p2) * sl * sl;
        return 2 * Radio.EARTH_RADIUS_M * Math.asin(Math.sqrt(a));
    }

    /** Equiretangular centrada na área: erro &lt; 0,1% para áreas de dezenas de km. */
    public static final class LocalProjection {
        private final double lat0;
        private final double lon0;
        private final double kx;
        private final double ky;

        public LocalProjection(double lat0, double lon0) {
            this.lat0 = lat0;
            this.lon0 = lon0;
            this.kx = Math.toRadians(1.0) * Radio.EARTH_RADIUS_M * Math.cos(Math.toRadians(lat0));
            this.ky = Math.toRadians(1.0) * Radio.EARTH_RADIUS_M;
        }

        public double x(double lon) {
            return (lon - lon0) * kx;
        }

        public double y(double lat) {
            return (lat - lat0) * ky;
        }

        public double lat(double y) {
            return lat0 + y / ky;
        }

        public double lon(double x) {
            return lon0 + x / kx;
        }
    }
}
