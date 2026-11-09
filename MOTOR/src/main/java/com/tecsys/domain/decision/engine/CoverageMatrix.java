package com.tecsys.domain.decision.engine;

/**
 * Matriz binária esparsa de cobertura, linhas = locais de ponto, colunas = locais de candidato,
 * guardada por coluna (CSC): as linhas da coluna {@code c} estão em
 * {@code rows[colPtr[c] .. colPtr[c+1])}, em ordem crescente.
 */
public final class CoverageMatrix {

    public final int nRows;
    public final int nCols;
    public final int[] colPtr;
    public final int[] rows;

    private int[] rowPtr;
    private int[] cols;

    public CoverageMatrix(int nRows, int nCols, int[] colPtr, int[] rows) {
        this.nRows = nRows;
        this.nCols = nCols;
        this.colPtr = colPtr;
        this.rows = rows;
    }

    public long nnz() {
        return colPtr[nCols];
    }

    public int colSize(int c) {
        return colPtr[c + 1] - colPtr[c];
    }

    /** Ponteiros da representação por linha (CSR), calculada uma vez. Colunas em ordem crescente. */
    public synchronized int[] rowPtr() {
        buildCsr();
        return rowPtr;
    }

    public synchronized int[] cols() {
        buildCsr();
        return cols;
    }

    private void buildCsr() {
        if (rowPtr != null) return;
        int[] ptr = new int[nRows + 1];
        for (int k = 0; k < colPtr[nCols]; k++) ptr[rows[k] + 1]++;
        for (int r = 0; r < nRows; r++) ptr[r + 1] += ptr[r];
        int[] next = ptr.clone();
        int[] c = new int[colPtr[nCols]];
        for (int col = 0; col < nCols; col++) {
            for (int k = colPtr[col]; k < colPtr[col + 1]; k++) {
                c[next[rows[k]]++] = col;
            }
        }
        rowPtr = ptr;
        cols = c;
    }

    /** Monta a matriz a partir das linhas de cada coluna (cada array já ordenado). */
    public static CoverageMatrix fromColumns(int nRows, int[][] columns) {
        int nCols = columns.length;
        int[] ptr = new int[nCols + 1];
        for (int c = 0; c < nCols; c++) ptr[c + 1] = ptr[c] + columns[c].length;
        int[] rows = new int[ptr[nCols]];
        for (int c = 0; c < nCols; c++) System.arraycopy(columns[c], 0, rows, ptr[c], columns[c].length);
        return new CoverageMatrix(nRows, nCols, ptr, rows);
    }
}
