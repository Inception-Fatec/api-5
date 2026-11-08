package com.tecsys.domain.etl;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.etl.dto.EtlJobResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.core.NestedExceptionUtils;
import org.springframework.core.task.TaskRejectedException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.regex.Pattern;
import java.util.stream.Stream;

@Service
@RequiredArgsConstructor
public class EtlService {

    private static final Pattern CODIGO_IBGE = Pattern.compile("^\\d{7}$");
    private static final String INDICE_UM_ATIVO = "uq_etl_jobs_um_ativo";
    private static final String MSG_EM_ANDAMENTO =
            "Já existe um ETL em andamento. Aguarde a conclusão para enviar outro arquivo.";

    private final EtlJobRepository jobRepository;
    private final EtlRunner etlRunner;

    public EtlJobResponseDto startGdbUpload(MultipartFile file, List<String> municipios,
                                            boolean incluirConsumidores, Long userId) {
        List<String> codigos = validarMunicipios(municipios);
        String filename = validarArquivo(file);

        EtlJob job = reservarExecucao(filename, file.getSize(), codigos, userId);

        Path workDir;
        try {
            workDir = salvarUpload(file);
        } catch (RuntimeException e) {
            marcarFalha(job, e.getMessage());
            throw e;
        }

        try {
            etlRunner.run(job.getId(), workDir, codigos, incluirConsumidores);
        } catch (TaskRejectedException e) {
            apagar(workDir);
            marcarFalha(job, MSG_EM_ANDAMENTO);
            throw new BusinessRuleException(MSG_EM_ANDAMENTO);
        } catch (RuntimeException e) {
            apagar(workDir);
            marcarFalha(job, "Não foi possível iniciar o ETL: " + e.getMessage());
            throw new BusinessRuleException("Não foi possível iniciar o ETL. Tente novamente.");
        }
        return EtlJobResponseDto.fromEntity(job);
    }

    public EtlJobResponseDto getJob(Long id) {
        return jobRepository.findById(id)
                .map(EtlJobResponseDto::fromEntity)
                .orElseThrow(() -> new BusinessRuleException("Execução de ETL não encontrada."));
    }

    /**
     * Últimas cargas (de qualquer ADM), mais novas primeiro (#TG-141). O log
     * só vai junto nas que falharam, para a lista não ficar pesada.
     */
    public List<EtlJobResponseDto> listarJobs() {
        return jobRepository.findTop30ByOrderByCreatedAtDescIdDesc().stream()
                .map(job -> job.getStatus() == EtlJobStatus.FAILED
                        ? EtlJobResponseDto.fromEntity(job)
                        : EtlJobResponseDto.semLog(job))
                .toList();
    }

    private EtlJob reservarExecucao(String filename, long tamanho, List<String> codigos, Long userId) {
        try {
            return jobRepository.saveAndFlush(EtlJob.builder()
                    .status(EtlJobStatus.PENDING)
                    .originalFilename(filename)
                    .fileSizeBytes(tamanho)
                    .municipios(String.join(",", codigos))
                    .createdBy(userId)
                    .build());
        } catch (DataIntegrityViolationException e) {
            String causa = NestedExceptionUtils.getMostSpecificCause(e).getMessage();
            if (causa != null && causa.contains(INDICE_UM_ATIVO)) {
                throw new BusinessRuleException(MSG_EM_ANDAMENTO);
            }
            throw e;
        }
    }

    private void marcarFalha(EtlJob job, String mensagem) {
        job.setStatus(EtlJobStatus.FAILED);
        job.setErrorMessage(mensagem);
        job.setFinishedAt(Instant.now());
        jobRepository.save(job);
    }

    private List<String> validarMunicipios(List<String> municipios) {
        if (municipios == null || municipios.isEmpty()) {
            throw new BusinessRuleException("Informe ao menos um código IBGE de município.");
        }
        List<String> codigos = municipios.stream()
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(java.util.stream.Collectors.collectingAndThen(
                        java.util.stream.Collectors.toCollection(LinkedHashSet::new), List::copyOf));

        if (codigos.isEmpty()) {
            throw new BusinessRuleException("Informe ao menos um código IBGE de município.");
        }
        List<String> invalidos = codigos.stream().filter(c -> !CODIGO_IBGE.matcher(c).matches()).toList();
        if (!invalidos.isEmpty()) {
            throw new BusinessRuleException("Códigos IBGE inválidos (esperado 7 dígitos): " + invalidos);
        }
        return codigos;
    }

    private String validarArquivo(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessRuleException("Envie um arquivo .zip contendo a pasta .gdb.");
        }
        String filename = StringUtils.cleanPath(file.getOriginalFilename() == null ? "" : file.getOriginalFilename());
        if (!filename.toLowerCase().endsWith(".zip")) {
            throw new BusinessRuleException("Formato inválido: compacte a pasta .gdb em um arquivo .zip.");
        }
        return filename;
    }

    private Path salvarUpload(MultipartFile file) {
        Path workDir = null;
        try {
            workDir = Files.createTempDirectory("etl-gdb-");
            file.transferTo(workDir.resolve("upload.zip"));
            return workDir;
        } catch (IOException e) {
            apagar(workDir);
            throw new BusinessRuleException("Falha ao salvar o arquivo enviado.");
        }
    }

    private void apagar(Path dir) {
        if (dir == null) {
            return;
        }
        try (Stream<Path> paths = Files.walk(dir)) {
            paths.sorted(Comparator.reverseOrder()).forEach(p -> p.toFile().delete());
        } catch (IOException ignored) {
        }
    }
}