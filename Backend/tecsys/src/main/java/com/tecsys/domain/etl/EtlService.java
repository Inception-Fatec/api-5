package com.tecsys.domain.etl;

import com.tecsys.core.exception.BusinessRuleException;
import com.tecsys.domain.etl.dto.EtlJobResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.regex.Pattern;
import java.util.stream.Stream;

@Service
@RequiredArgsConstructor
public class EtlService {

    private static final Pattern CODIGO_IBGE = Pattern.compile("^\\d{7}$");

    private final EtlJobRepository jobRepository;
    private final EtlRunner etlRunner;

    public EtlJobResponseDto startGdbUpload(MultipartFile file, List<String> municipios,
                                            boolean incluirConsumidores, Long userId) {
        List<String> codigos = validarMunicipios(municipios);
        String filename = validarArquivo(file);

        if (jobRepository.existsByStatusIn(List.of(EtlJobStatus.PENDING, EtlJobStatus.RUNNING))) {
            throw new BusinessRuleException("Já existe um ETL em andamento. Aguarde a conclusão para enviar outro arquivo.");
        }

        Path workDir = salvarUpload(file);

        EtlJob job = jobRepository.save(EtlJob.builder()
                .status(EtlJobStatus.PENDING)
                .originalFilename(filename)
                .municipios(String.join(",", codigos))
                .createdBy(userId)
                .build());

        etlRunner.run(job.getId(), workDir, codigos, incluirConsumidores);
        return EtlJobResponseDto.fromEntity(job);
    }

    public EtlJobResponseDto getJob(Long id) {
        return jobRepository.findById(id)
                .map(EtlJobResponseDto::fromEntity)
                .orElseThrow(() -> new BusinessRuleException("Execução de ETL não encontrada."));
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