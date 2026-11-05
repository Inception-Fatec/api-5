package com.tecsys.domain.decision.engine;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Configuração do motor em {@code app.motor.*}. {@code profile} escolhe a base
 * ({@link MotorParams#profile(String)}); qualquer outro campo preenchido sobrescreve o perfil.
 * Campos vazios mantêm o valor do perfil.
 */
@Component
@ConfigurationProperties(prefix = "app.motor")
public class MotorProperties {

    private String profile = "tecsys";
    /** Threads da visada e do solver. 0 = nº de núcleos − 1. */
    private int threads = 0;

    private Double fixedRangeM;
    private Double frequencyMhz;
    private Double txPowerDbm;
    private Double sensitivityDbm;
    private Double antennaGainsDb;
    private Double extraLossDb;
    private Double maxRangeM;
    private Boolean bdgdHeights;
    private Double gatewayHeightM;
    private Double sensorHeightM;
    private MotorParams.LosMode lineOfSight;
    private Double losStepM;
    private Integer teamSamples;
    private Double obstructionToleranceM;
    private Boolean earthCurvature;
    private Double refractionK;
    private Double fresnelFraction;
    private Boolean neighborCandidates;
    private Boolean bairroLikeMap;
    private Boolean localSearch;
    private Double exactSeconds;
    private Boolean useTerrain;

    public MotorParams toParams() {
        MotorParams.Builder b = MotorParams.profile(profile).toBuilder();
        if (fixedRangeM != null) b.fixedRangeM(fixedRangeM <= 0 ? null : fixedRangeM);
        if (frequencyMhz != null) b.frequencyMhz(frequencyMhz);
        if (txPowerDbm != null) b.txPowerDbm(txPowerDbm);
        if (sensitivityDbm != null) b.sensitivityDbm(sensitivityDbm);
        if (antennaGainsDb != null) b.antennaGainsDb(antennaGainsDb);
        if (extraLossDb != null) b.extraLossDb(extraLossDb);
        if (maxRangeM != null) b.maxRangeM(maxRangeM <= 0 ? null : maxRangeM);
        if (bdgdHeights != null) b.bdgdHeights(bdgdHeights);
        if (gatewayHeightM != null) b.gatewayHeightM(gatewayHeightM);
        if (sensorHeightM != null) b.sensorHeightM(sensorHeightM);
        if (lineOfSight != null) b.lineOfSight(lineOfSight);
        if (losStepM != null) b.losStepM(losStepM);
        if (teamSamples != null) b.teamSamples(teamSamples);
        if (obstructionToleranceM != null) b.obstructionToleranceM(obstructionToleranceM);
        if (earthCurvature != null) b.earthCurvature(earthCurvature);
        if (refractionK != null) b.kFactor(refractionK);
        if (fresnelFraction != null) b.fresnelFraction(fresnelFraction);
        if (neighborCandidates != null) b.neighborCandidates(neighborCandidates);
        if (bairroLikeMap != null) b.bairroLikeMap(bairroLikeMap);
        if (localSearch != null) b.localSearch(localSearch);
        if (exactSeconds != null) b.exactSeconds(exactSeconds);
        if (useTerrain != null) b.useTerrain(useTerrain);
        return b.build();
    }

    public int effectiveThreads() {
        return threads > 0 ? threads : Math.max(1, Runtime.getRuntime().availableProcessors() - 1);
    }

    public String getProfile() { return profile; }
    public void setProfile(String profile) { this.profile = profile; }
    public int getThreads() { return threads; }
    public void setThreads(int threads) { this.threads = threads; }
    public Double getFixedRangeM() { return fixedRangeM; }
    public void setFixedRangeM(Double v) { fixedRangeM = v; }
    public Double getFrequencyMhz() { return frequencyMhz; }
    public void setFrequencyMhz(Double v) { frequencyMhz = v; }
    public Double getTxPowerDbm() { return txPowerDbm; }
    public void setTxPowerDbm(Double v) { txPowerDbm = v; }
    public Double getSensitivityDbm() { return sensitivityDbm; }
    public void setSensitivityDbm(Double v) { sensitivityDbm = v; }
    public Double getAntennaGainsDb() { return antennaGainsDb; }
    public void setAntennaGainsDb(Double v) { antennaGainsDb = v; }
    public Double getExtraLossDb() { return extraLossDb; }
    public void setExtraLossDb(Double v) { extraLossDb = v; }
    public Double getMaxRangeM() { return maxRangeM; }
    public void setMaxRangeM(Double v) { maxRangeM = v; }
    public Boolean getBdgdHeights() { return bdgdHeights; }
    public void setBdgdHeights(Boolean v) { bdgdHeights = v; }
    public Double getGatewayHeightM() { return gatewayHeightM; }
    public void setGatewayHeightM(Double v) { gatewayHeightM = v; }
    public Double getSensorHeightM() { return sensorHeightM; }
    public void setSensorHeightM(Double v) { sensorHeightM = v; }
    public MotorParams.LosMode getLineOfSight() { return lineOfSight; }
    public void setLineOfSight(MotorParams.LosMode v) { lineOfSight = v; }
    public Double getLosStepM() { return losStepM; }
    public void setLosStepM(Double v) { losStepM = v; }
    public Integer getTeamSamples() { return teamSamples; }
    public void setTeamSamples(Integer v) { teamSamples = v; }
    public Double getObstructionToleranceM() { return obstructionToleranceM; }
    public void setObstructionToleranceM(Double v) { obstructionToleranceM = v; }
    public Boolean getEarthCurvature() { return earthCurvature; }
    public void setEarthCurvature(Boolean v) { earthCurvature = v; }
    public Double getRefractionK() { return refractionK; }
    public void setRefractionK(Double v) { refractionK = v; }
    public Double getFresnelFraction() { return fresnelFraction; }
    public void setFresnelFraction(Double v) { fresnelFraction = v; }
    public Boolean getNeighborCandidates() { return neighborCandidates; }
    public void setNeighborCandidates(Boolean v) { neighborCandidates = v; }
    public Boolean getBairroLikeMap() { return bairroLikeMap; }
    public void setBairroLikeMap(Boolean v) { bairroLikeMap = v; }
    public Boolean getLocalSearch() { return localSearch; }
    public void setLocalSearch(Boolean v) { localSearch = v; }
    public Double getExactSeconds() { return exactSeconds; }
    public void setExactSeconds(Double v) { exactSeconds = v; }
    public Boolean getUseTerrain() { return useTerrain; }
    public void setUseTerrain(Boolean v) { useTerrain = v; }
}
