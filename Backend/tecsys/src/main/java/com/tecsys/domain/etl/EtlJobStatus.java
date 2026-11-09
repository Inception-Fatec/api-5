package com.tecsys.domain.etl;

public enum EtlJobStatus {
    /** Arquivo recebido; o backend está descompactando e lendo a .gdb (#TG-143). */
    INSPECTING,
    /** .gdb inspecionada; aguardando o ADM escolher os municípios (#TG-143). */
    AWAITING_SELECTION,
    PENDING,
    RUNNING,
    SUCCESS,
    FAILED,
    /** Upload descartado antes de iniciar a carga (cancelado ou expirado). */
    CANCELED
}
