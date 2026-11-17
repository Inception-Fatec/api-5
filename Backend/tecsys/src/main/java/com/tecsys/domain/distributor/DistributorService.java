package com.tecsys.domain.distributor;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.distributor.dto.DistributorCreateRequestDto;

import com.tecsys.domain.distributor.dto.DistributorResponseDto;
import com.tecsys.domain.distributor.dto.DistributorResumoProjection;
import com.tecsys.domain.distributor.dto.MunicipioResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class DistributorService {

    private final DistributorRepository distributorRepository;

    @Transactional(readOnly = true)
    public List<DistributorResponseDto> listarDistribuidoras() {
        return listarDistribuidoras(false);
    }

    @Transactional(readOnly = true)
    public List<DistributorResponseDto> listarDistribuidoras(boolean incluirCadastradas) {
        return distributorRepository.findDistribuidorasResumo(incluirCadastradas).stream()
                .map(proj -> new DistributorResponseDto(
                        proj.getDist(),
                        proj.getDistName(),
                        proj.getTotalSub()
                ))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<MunicipioResponseDto> listarMunicipiosPorDist(String dist) {
        return distributorRepository.findMunicipiosByDist(dist).stream()
                .map(proj -> new MunicipioResponseDto(
                        proj.getIbgeCode(),
                        proj.getLatitude(),
                        proj.getLongitude(),
                        Boolean.TRUE.equals(proj.getTemRede()),
                        Boolean.TRUE.equals(proj.getTemCsv())
                ))
                .toList();
    }

    /**
     * Cadastra uma distribuidora sem BDGD (#TG-151). Código repetido (já
     * cadastrado ou já usado pela rede carregada) é recusado com mensagem.
     */
    @Transactional
    public DistributorResponseDto cadastrar(DistributorCreateRequestDto request) {
        String codigo = request.codigo().trim();
        String nome = request.nome().trim();
        if (distributorRepository.existsById(codigo) || distributorRepository.temRede(codigo)) {
            throw new BusinessRuleException("Já existe uma distribuidora com o código " + codigo + ".");
        }
        distributorRepository.save(Distributor.builder().dist(codigo).distName(nome).build());
        return new DistributorResponseDto(codigo, nome, 0L);
    }
}
