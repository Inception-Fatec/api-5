package com.tecsys.domain.gateway;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.gateway.dto.GatewayProfileRequestDto;
import com.tecsys.domain.gateway.dto.GatewayProfileResponseDto;
import com.tecsys.domain.project.ProjectHistoryRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class GatewayProfileService {

    private final GatewayProfileRepository repository;
    private final ProjectHistoryRepository projectHistoryRepository;

    @Transactional
    public GatewayProfileResponseDto create(GatewayProfileRequestDto request) {
        GatewayProfile profile = GatewayProfile.builder()
                .name(request.name())
                .frequencyMhz(request.frequencyMhz())
                .txPowerDbm(request.txPowerDbm())
                .antennaGainDbi(request.antennaGainDbi())
                .rxSensitivityDbm(request.rxSensitivityDbm())
                .antennaHeightM(request.antennaHeightM())
                .maxDevices(request.maxDevices())
                .build();
        return toDto(repository.save(profile));
    }

    @Transactional(readOnly = true)
    public List<GatewayProfileResponseDto> findAll() {
        return repository.findAllByActiveTrue().stream().map(this::toDto).toList();
    }

    @Transactional(readOnly = true)
    public GatewayProfileResponseDto findById(Long id) {
        return toDto(getProfileOrThrow(id));
    }

    @Transactional
    public GatewayProfileResponseDto update(Long id, GatewayProfileRequestDto request) {
        GatewayProfile profile = getProfileOrThrow(id);

        profile.setName(request.name());
        profile.setFrequencyMhz(request.frequencyMhz());
        profile.setTxPowerDbm(request.txPowerDbm());
        profile.setAntennaGainDbi(request.antennaGainDbi());
        profile.setRxSensitivityDbm(request.rxSensitivityDbm());
        profile.setAntennaHeightM(request.antennaHeightM());
        profile.setMaxDevices(request.maxDevices());

        return toDto(repository.save(profile));
    }

    @Transactional
    public void delete(Long id) {
        if (projectHistoryRepository.existsByGatewayProfileIdInFilterParams(id)) {
            throw new BusinessRuleException("Não é possível excluir o perfil, pois já está em uso por um projeto.");
        }
        GatewayProfile profile = getProfileOrThrow(id);
        profile.setActive(false);
        repository.save(profile);
    }

    private GatewayProfile getProfileOrThrow(Long id) {
        return repository.findByIdAndActiveTrue(id)
                .orElseThrow(() -> new EntityNotFoundException("Perfil técnico não encontrado."));
    }

    private GatewayProfileResponseDto toDto(GatewayProfile entity) {
        return new GatewayProfileResponseDto(
                entity.getId(), entity.getName(), entity.getFrequencyMhz(),
                entity.getTxPowerDbm(), entity.getAntennaGainDbi(),
                entity.getRxSensitivityDbm(), entity.getAntennaHeightM(),
                entity.getMaxDevices(), entity.isActive()
        );
    }
}