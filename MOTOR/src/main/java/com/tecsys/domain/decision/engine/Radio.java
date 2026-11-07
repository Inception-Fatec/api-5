package com.tecsys.domain.decision.engine;

/** Modelo de rádio: perda em espaço livre, orçamento de enlace, horizonte e Fresnel. */
public final class Radio {

    public static final double EARTH_RADIUS_M = 6_371_000.0;
    private static final double SPEED_OF_LIGHT = 299_792_458.0;

    private Radio() {
    }

    /** FSPL = 20·log10(d_km) + 20·log10(f_MHz) + 32,44 (fórmula do doc da Tecsys). */
    public static double fsplDb(double distM, double freqMhz) {
        double dKm = Math.max(distM, 1.0) / 1000.0;
        return 20.0 * Math.log10(dKm) + 20.0 * Math.log10(freqMhz) + 32.44;
    }

    public static double budgetDb(MotorParams p) {
        return p.txPowerDbm() - p.sensitivityDbm() + p.antennaGainsDb() - p.extraLossDb();
    }

    /** Maior distância em que FSPL ≤ orçamento de enlace. */
    public static double budgetRangeM(MotorParams p) {
        double exp = (budgetDb(p) - 20.0 * Math.log10(p.frequencyMhz()) - 32.44) / 20.0;
        return 1000.0 * Math.pow(10.0, exp);
    }

    /** Distância máxima com visada sobre Terra lisa: √(2kR)·(√h1 + √h2). */
    public static double radioHorizonM(double h1, double h2, double k) {
        return Math.sqrt(2.0 * k * EARTH_RADIUS_M) * (Math.sqrt(Math.max(h1, 0.0)) + Math.sqrt(Math.max(h2, 0.0)));
    }

    public static double fresnelRadiusM(double d1, double d2, double freqMhz) {
        double lambda = SPEED_OF_LIGHT / (freqMhz * 1e6);
        return Math.sqrt(lambda * d1 * d2 / Math.max(d1 + d2, 1e-9));
    }

    /** Raio usado para procurar pares candidato × ponto. */
    public static double searchRangeM(MotorParams p, double maxGatewayHeight, double maxPointHeight) {
        if (p.fixedRangeM() != null) {
            return p.fixedRangeM();
        }
        double r = budgetRangeM(p);
        if (p.useTerrain() || p.earthCurvature()) {
            r = Math.min(r, radioHorizonM(maxGatewayHeight, maxPointHeight, p.kFactor()));
        }
        if (p.maxRangeM() != null) {
            r = Math.min(r, p.maxRangeM());
        }
        return r;
    }
}
