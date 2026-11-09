package com.tecsys.domain.decision.engine;

/**
 * Parâmetros do cálculo. Nenhum valor de RF fica fixo no código: o perfil dá a base
 * e cada campo pode ser sobrescrito em {@code app.motor.*} (ver {@link MotorProperties}).
 *
 * <p>Perfis:
 * <ul>
 *   <li>{@code tecsys}: modelo do parceiro (doc API_relevo_doc). 915 MHz, 21 dBm, −120 dBm,
 *       gateway a 6 m, sensor a 5 m, viewshed por raios com curvatura da Terra.</li>
 *   <li>{@code compat-preciso}: premissas do motor antigo (4 km, alturas da BDGD) com visada precisa.</li>
 *   <li>{@code compat}: réplica do motor antigo (5 amostras, pixel mais próximo, folga de 1,5 m).</li>
 * </ul>
 */
public record MotorParams(
        String profile,
        Double fixedRangeM,          // se definido, ignora o orçamento de enlace

        double frequencyMhz,
        double txPowerDbm,
        double sensitivityDbm,
        double antennaGainsDb,       // ganho de antenas somado (Tx + Rx)
        double extraLossDb,          // vegetação/obstáculos
        Double maxRangeM,            // teto opcional de alcance, além do horizonte de rádio

        boolean bdgdHeights,         // true = alturas por tipo de estrutura da BDGD
        double gatewayHeightM,
        double sensorHeightM,

        LosMode lineOfSight,
        double losStepM,             // passo do perfil de visada (resolução do Copernicus GLO-30)
        int teamSamples,             // nº de amostras no modo TEAM
        double obstructionToleranceM,
        boolean earthCurvature,
        double kFactor,              // refração atmosférica
        double fresnelFraction,      // 0 = linha direta; 0,6 = 60% da 1ª zona livre

        boolean neighborCandidates,  // trafos fora da área, mas ao alcance dela (#TG-138)
        boolean bairroLikeMap,       // ILIKE '%x%' como o mapa (#TG-98); false = igualdade exata

        boolean localSearch,
        double exactSeconds,         // tempo do solver exato; 0 = desliga
        boolean useTerrain
) {

    public enum LosMode {
        /** Viewshed por raios a partir de cada gateway: custo cresce com a área, não com os pares. */
        RAYS,
        /** Perfil par a par amostrado a cada {@code losStepM}, bilinear. */
        PROFILE,
        /** Réplica do motor antigo: poucas amostras e pixel mais próximo. */
        TEAM
    }

    public static MotorParams profile(String name) {
        String n = name == null ? "tecsys" : name.trim().toLowerCase();
        return switch (n) {
            case "tecsys" -> tecsys();
            case "compat" -> tecsys().toBuilder()
                    .profile("compat").fixedRangeM(4000.0).bdgdHeights(true)
                    .lineOfSight(LosMode.TEAM).teamSamples(5).obstructionToleranceM(1.5)
                    .earthCurvature(false).neighborCandidates(false).bairroLikeMap(false)
                    .build();
            case "compat-preciso" -> tecsys().toBuilder()
                    .profile("compat-preciso").fixedRangeM(4000.0).bdgdHeights(true)
                    .lineOfSight(LosMode.PROFILE).obstructionToleranceM(0.0)
                    .earthCurvature(true).neighborCandidates(true)
                    .build();
            default -> throw new IllegalArgumentException(
                    "Perfil do motor desconhecido: " + name + " (use tecsys, compat-preciso ou compat)");
        };
    }

    private static MotorParams tecsys() {
        return new MotorParams("tecsys", null,
                915.0, 21.0, -120.0, 0.0, 0.0, null,
                false, 6.0, 5.0,
                LosMode.RAYS, 30.0, 5, 0.0, true, 4.0 / 3.0, 0.0,
                true, true,
                true, 180.0, true);
    }

    public Builder toBuilder() {
        return new Builder(this);
    }

    public static final class Builder {
        private String profile;
        private Double fixedRangeM;
        private double frequencyMhz;
        private double txPowerDbm;
        private double sensitivityDbm;
        private double antennaGainsDb;
        private double extraLossDb;
        private Double maxRangeM;
        private boolean bdgdHeights;
        private double gatewayHeightM;
        private double sensorHeightM;
        private LosMode lineOfSight;
        private double losStepM;
        private int teamSamples;
        private double obstructionToleranceM;
        private boolean earthCurvature;
        private double kFactor;
        private double fresnelFraction;
        private boolean neighborCandidates;
        private boolean bairroLikeMap;
        private boolean localSearch;
        private double exactSeconds;
        private boolean useTerrain;

        private Builder(MotorParams p) {
            profile = p.profile;
            fixedRangeM = p.fixedRangeM;
            frequencyMhz = p.frequencyMhz;
            txPowerDbm = p.txPowerDbm;
            sensitivityDbm = p.sensitivityDbm;
            antennaGainsDb = p.antennaGainsDb;
            extraLossDb = p.extraLossDb;
            maxRangeM = p.maxRangeM;
            bdgdHeights = p.bdgdHeights;
            gatewayHeightM = p.gatewayHeightM;
            sensorHeightM = p.sensorHeightM;
            lineOfSight = p.lineOfSight;
            losStepM = p.losStepM;
            teamSamples = p.teamSamples;
            obstructionToleranceM = p.obstructionToleranceM;
            earthCurvature = p.earthCurvature;
            kFactor = p.kFactor;
            fresnelFraction = p.fresnelFraction;
            neighborCandidates = p.neighborCandidates;
            bairroLikeMap = p.bairroLikeMap;
            localSearch = p.localSearch;
            exactSeconds = p.exactSeconds;
            useTerrain = p.useTerrain;
        }

        public Builder profile(String v) { profile = v; return this; }
        public Builder fixedRangeM(Double v) { fixedRangeM = v; return this; }
        public Builder frequencyMhz(double v) { frequencyMhz = v; return this; }
        public Builder txPowerDbm(double v) { txPowerDbm = v; return this; }
        public Builder sensitivityDbm(double v) { sensitivityDbm = v; return this; }
        public Builder antennaGainsDb(double v) { antennaGainsDb = v; return this; }
        public Builder extraLossDb(double v) { extraLossDb = v; return this; }
        public Builder maxRangeM(Double v) { maxRangeM = v; return this; }
        public Builder bdgdHeights(boolean v) { bdgdHeights = v; return this; }
        public Builder gatewayHeightM(double v) { gatewayHeightM = v; return this; }
        public Builder sensorHeightM(double v) { sensorHeightM = v; return this; }
        public Builder lineOfSight(LosMode v) { lineOfSight = v; return this; }
        public Builder losStepM(double v) { losStepM = v; return this; }
        public Builder teamSamples(int v) { teamSamples = v; return this; }
        public Builder obstructionToleranceM(double v) { obstructionToleranceM = v; return this; }
        public Builder earthCurvature(boolean v) { earthCurvature = v; return this; }
        public Builder kFactor(double v) { kFactor = v; return this; }
        public Builder fresnelFraction(double v) { fresnelFraction = v; return this; }
        public Builder neighborCandidates(boolean v) { neighborCandidates = v; return this; }
        public Builder bairroLikeMap(boolean v) { bairroLikeMap = v; return this; }
        public Builder localSearch(boolean v) { localSearch = v; return this; }
        public Builder exactSeconds(double v) { exactSeconds = v; return this; }
        public Builder useTerrain(boolean v) { useTerrain = v; return this; }

        public MotorParams build() {
            if (losStepM <= 0) throw new IllegalArgumentException("los-step-m deve ser maior que zero.");
            if (fixedRangeM != null && fixedRangeM <= 0) throw new IllegalArgumentException("fixed-range-m deve ser maior que zero.");
            return new MotorParams(profile, fixedRangeM, frequencyMhz, txPowerDbm, sensitivityDbm,
                    antennaGainsDb, extraLossDb, maxRangeM, bdgdHeights, gatewayHeightM, sensorHeightM,
                    lineOfSight, losStepM, teamSamples, obstructionToleranceM, earthCurvature, kFactor,
                    fresnelFraction, neighborCandidates, bairroLikeMap, localSearch, exactSeconds, useTerrain);
        }
    }
}
