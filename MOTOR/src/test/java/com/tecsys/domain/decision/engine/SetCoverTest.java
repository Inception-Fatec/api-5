package com.tecsys.domain.decision.engine;

import org.junit.jupiter.api.Test;

import java.util.Arrays;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SetCoverTest {

    private static CoverageMatrix matrix(int nRows, int[]... cols) {
        return CoverageMatrix.fromColumns(nRows, cols);
    }

    private static long[] ones(int n) {
        long[] w = new long[n];
        Arrays.fill(w, 1);
        return w;
    }

    private static boolean coversAll(CoverageMatrix a, int[] sel) {
        int[] cont = SetCover.coverCount(a, sel);
        return Arrays.stream(cont).allMatch(c -> c > 0);
    }

    /**
     * Caso clássico: metades A = {0..6} e B = {7..13} (ótimo = 2), mas o guloso pega antes
     * C1 (8 pontos), depois C2 (4) e C3 (2): 3 gateways.
     */
    private static CoverageMatrix classic() {
        return matrix(14,
                new int[]{0, 1, 2, 3, 4, 5, 6},
                new int[]{7, 8, 9, 10, 11, 12, 13},
                new int[]{0, 1, 2, 3, 7, 8, 9, 10},
                new int[]{4, 5, 11, 12},
                new int[]{6, 13});
    }

    @Test
    void gulosoCobreTudoMasNaoEOtimo() {
        CoverageMatrix a = classic();
        SetCover.Greedy g = SetCover.greedy(a, ones(14));
        assertTrue(coversAll(a, g.cols()));
        assertArrayEquals(new int[]{2, 3, 4}, g.cols());
        assertArrayEquals(new long[]{8, 4, 2}, g.gains());
    }

    @Test
    void exatoProvaOOtimo() {
        CoverageMatrix a = classic();
        SetCover.Exact ex = SetCover.exact(a, 10, 1_000_000, 2);
        assertEquals("ótimo", ex.status());
        assertEquals(2, ex.cols().length);
        assertEquals(2, ex.bound());
        assertTrue(coversAll(a, ex.cols()));
    }

    @Test
    void removerRedundantes() {
        CoverageMatrix a = matrix(3, new int[]{0, 1}, new int[]{1, 2}, new int[]{0, 1, 2});
        assertArrayEquals(new int[]{2}, SetCover.removeRedundant(a, new int[]{0, 1, 2}));
    }

    @Test
    void limiteDeEmpacotamento() {
        CoverageMatrix a = matrix(2, new int[]{0}, new int[]{1}, new int[]{0, 1});
        assertEquals(1, SetCover.packingBound(a));
    }

    @Test
    void buscaLocalTrocaDoisPorUm() {
        // 0 e 1 cobrem metades; 2 cobre tudo e fica longe de nenhum dos dois
        CoverageMatrix a = matrix(4, new int[]{0, 1}, new int[]{2, 3}, new int[]{0, 1, 2, 3});
        int[] sel = SetCover.localSearch2for1(a, new int[]{0, 1}, new double[]{0, 100, 50}, new double[]{0, 0, 0}, 1000, 5);
        assertArrayEquals(new int[]{2}, sel);
    }

    @Test
    void reducaoTiraLinhasEColunasRepetidas() {
        // linhas 0 e 1 iguais; colunas 0 e 1 iguais; linha 3 sem candidato
        CoverageMatrix a = matrix(4, new int[]{0, 1}, new int[]{0, 1}, new int[]{2});
        SetCover.Reduced r = SetCover.reduce(a);
        assertEquals(2, r.matrix().nRows);
        assertEquals(2, r.matrix().nCols);
        assertArrayEquals(new int[]{0, 2}, r.cols());
        assertArrayEquals(new int[]{0, 0, 1}, r.colToRed());
    }

    @Test
    void lagrangianoNaoPassaDoOtimoELnsMantemCobertura() {
        // grade 6×6 de pontos; cada candidato cobre um bloco 3×3 a partir de (i, j)
        int side = 6;
        int[][] cols = new int[16][];
        double[] cx = new double[16], cy = new double[16];
        int c = 0;
        for (int i = 0; i <= 3; i++) {
            for (int j = 0; j <= 3; j++) {
                int[] rows = new int[9];
                int k = 0;
                for (int di = 0; di < 3; di++) for (int dj = 0; dj < 3; dj++) rows[k++] = (i + di) * side + j + dj;
                Arrays.sort(rows);
                cols[c] = rows;
                cx[c] = j;
                cy[c] = i;
                c++;
            }
        }
        CoverageMatrix a = CoverageMatrix.fromColumns(side * side, cols);
        int[] greedy = SetCover.greedy(a, ones(36)).cols();
        int optimum = SetCover.exact(a, 10, 1_000_000, 2).cols().length;
        assertEquals(4, optimum);
        assertTrue(SetCover.lagrangianBound(a, greedy.length, 5, 3000) <= optimum);

        SetCover.LnsResult lns = SetCover.lns(a, greedy, cx, cy, 1.0, 7, 3, 8, 1.0);
        assertTrue(coversAll(a, lns.cols()));
        assertTrue(lns.cols().length <= greedy.length);
    }
}
