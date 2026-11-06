package com.tecsys.domain.decision.engine;

import com.google.ortools.Loader;
import com.google.ortools.linearsolver.MPConstraint;
import com.google.ortools.linearsolver.MPObjective;
import com.google.ortools.linearsolver.MPSolver;
import com.google.ortools.linearsolver.MPVariable;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;

/**
 * Menor conjunto de gateways que cobre todos os pontos cobríveis (cobertura de conjuntos).
 * <ol>
 *   <li>Guloso preguiçoso: escolhe quem cobre mais pontos novos (ponderado pelo nº de pontos de cada local).</li>
 *   <li>Remoção de redundantes: tira gateways cujos pontos já são cobertos pelos outros.</li>
 *   <li>Busca local 2→1: troca dois gateways vizinhos por um que cubra os pontos só deles.</li>
 *   <li>Solver exato (HiGHS, via OR-Tools) na instância reduzida: prova o ótimo ou dá um limite inferior.</li>
 *   <li>Instâncias grandes: LNS (remove k gateways vizinhos e recobre os órfãos de forma exata)
 *       e relaxação lagrangiana para o limite inferior.</li>
 * </ol>
 */
public final class SetCover {

    private static volatile boolean nativeLoaded;

    private SetCover() {
    }

    private static void loadNative() {
        if (!nativeLoaded) {
            synchronized (SetCover.class) {
                if (!nativeLoaded) {
                    Loader.loadNativeLibraries();
                    nativeLoaded = true;
                }
            }
        }
    }

    // ------------------------------------------------------------------ guloso

    public record Greedy(int[] cols, long[] gains) {
    }

    /** Guloso com avaliação preguiçosa. Em empate de ganho, vence o menor índice. */
    public static Greedy greedy(CoverageMatrix a, long[] w) {
        boolean[] covered = new boolean[a.nRows];
        LongHeap heap = new LongHeap(a.nCols);
        for (int c = 0; c < a.nCols; c++) {
            long g = 0;
            for (int k = a.colPtr[c]; k < a.colPtr[c + 1]; k++) g += w[a.rows[k]];
            if (g > 0) heap.push(LongHeap.key(g, c));
        }
        List<Integer> chosen = new ArrayList<>();
        List<Long> gains = new ArrayList<>();
        while (!heap.isEmpty()) {
            long key = heap.pop();
            int c = LongHeap.col(key);
            long real = 0;
            for (int k = a.colPtr[c]; k < a.colPtr[c + 1]; k++) {
                int r = a.rows[k];
                if (!covered[r]) real += w[r];
            }
            if (real <= 0) continue;
            if (!heap.isEmpty() && real < LongHeap.gain(heap.peek())) {
                heap.push(LongHeap.key(real, c));
                continue;
            }
            chosen.add(c);
            gains.add(real);
            for (int k = a.colPtr[c]; k < a.colPtr[c + 1]; k++) covered[a.rows[k]] = true;
        }
        return new Greedy(chosen.stream().mapToInt(Integer::intValue).toArray(),
                gains.stream().mapToLong(Long::longValue).toArray());
    }

    /** Guloso restrito às colunas {@code sel}: dá a ordem final e o ganho de cada gateway. */
    public static Greedy orderSelection(CoverageMatrix a, int[] sel, long[] w) {
        int[][] cols = new int[sel.length][];
        for (int i = 0; i < sel.length; i++) {
            cols[i] = Arrays.copyOfRange(a.rows, a.colPtr[sel[i]], a.colPtr[sel[i] + 1]);
        }
        Greedy g = greedy(CoverageMatrix.fromColumns(a.nRows, cols), w);
        int[] mapped = new int[g.cols().length];
        for (int i = 0; i < mapped.length; i++) mapped[i] = sel[g.cols()[i]];
        return new Greedy(mapped, g.gains());
    }

    // ------------------------------------------------------- redundância e busca local

    static int[] coverCount(CoverageMatrix a, int[] sel) {
        int[] cont = new int[a.nRows];
        for (int c : sel) {
            for (int k = a.colPtr[c]; k < a.colPtr[c + 1]; k++) cont[a.rows[k]]++;
        }
        return cont;
    }

    public static int[] removeRedundant(CoverageMatrix a, int[] sel) {
        int[] cont = coverCount(a, sel);
        // tenta remover primeiro os que contribuem menos
        long[][] keys = new long[sel.length][];
        for (int i = 0; i < sel.length; i++) {
            int c = sel[i];
            long exclusive = 0;
            for (int k = a.colPtr[c]; k < a.colPtr[c + 1]; k++) if (cont[a.rows[k]] == 1) exclusive++;
            keys[i] = new long[]{exclusive, a.colSize(c), c};
        }
        Arrays.sort(keys, (x, y) -> x[0] != y[0] ? Long.compare(x[0], y[0])
                : x[1] != y[1] ? Long.compare(x[1], y[1]) : Long.compare(x[2], y[2]));
        Set<Integer> removed = new HashSet<>();
        for (long[] key : keys) {
            int c = (int) key[2];
            boolean redundant = true;
            for (int k = a.colPtr[c]; k < a.colPtr[c + 1] && redundant; k++) redundant = cont[a.rows[k]] >= 2;
            if (redundant) {
                for (int k = a.colPtr[c]; k < a.colPtr[c + 1]; k++) cont[a.rows[k]]--;
                removed.add(c);
            }
        }
        return Arrays.stream(sel).filter(c -> !removed.contains(c)).toArray();
    }

    /** Troca pares de gateways próximos (≤ 2·raio) por um candidato que cubra os pontos exclusivos deles. */
    public static int[] localSearch2for1(CoverageMatrix a, int[] selection, double[] cx, double[] cy,
                                         double radius, double limitSeconds) {
        long deadline = System.nanoTime() + (long) (limitSeconds * 1e9);
        int[] rowPtr = a.rowPtr();
        int[] rowCols = a.cols();
        int[] markA = new int[a.nRows];
        int[] markB = new int[a.nRows];
        int[] colCount = new int[a.nCols];
        int stamp = 0;
        List<Integer> sel = new ArrayList<>(Arrays.stream(selection).boxed().toList());
        boolean improved = true;
        while (improved && System.nanoTime() < deadline) {
            improved = false;
            int[] cont = coverCount(a, sel.stream().mapToInt(Integer::intValue).toArray());
            outer:
            for (int ia = 0; ia < sel.size(); ia++) {
                for (int ib = ia + 1; ib < sel.size(); ib++) {
                    if (System.nanoTime() > deadline) break outer;
                    int ga = sel.get(ia);
                    int gb = sel.get(ib);
                    if (Math.hypot(cx[ga] - cx[gb], cy[ga] - cy[gb]) > 2 * radius) continue;
                    stamp++;
                    for (int k = a.colPtr[ga]; k < a.colPtr[ga + 1]; k++) markA[a.rows[k]] = stamp;
                    for (int k = a.colPtr[gb]; k < a.colPtr[gb + 1]; k++) markB[a.rows[k]] = stamp;
                    List<Integer> orphans = new ArrayList<>();
                    for (int k = a.colPtr[ga]; k < a.colPtr[ga + 1]; k++) {
                        int r = a.rows[k];
                        if (cont[r] - 1 - (markB[r] == stamp ? 1 : 0) == 0) orphans.add(r);
                    }
                    for (int k = a.colPtr[gb]; k < a.colPtr[gb + 1]; k++) {
                        int r = a.rows[k];
                        if (markA[r] != stamp && cont[r] - 1 == 0) orphans.add(r);
                    }
                    int replacement = -1;
                    if (!orphans.isEmpty()) {
                        List<Integer> touched = new ArrayList<>();
                        for (int r : orphans) {
                            for (int k = rowPtr[r]; k < rowPtr[r + 1]; k++) {
                                int c = rowCols[k];
                                if (colCount[c]++ == 0) touched.add(c);
                            }
                        }
                        int best = Integer.MAX_VALUE;
                        for (int c : touched) {
                            if (colCount[c] == orphans.size() && c != ga && c != gb) best = Math.min(best, c);
                            colCount[c] = 0;
                        }
                        if (best == Integer.MAX_VALUE) continue;
                        replacement = best;
                    }
                    sel.remove(Integer.valueOf(ga));
                    sel.remove(Integer.valueOf(gb));
                    if (replacement >= 0) sel.add(replacement);
                    improved = true;
                    break outer;
                }
            }
        }
        return sel.stream().mapToInt(Integer::intValue).toArray();
    }

    // ------------------------------------------------------------ limites inferiores

    /** Pontos com conjuntos de candidatos disjuntos: cada um exige um gateway diferente. */
    public static int packingBound(CoverageMatrix a) {
        int[] rowPtr = a.rowPtr();
        int[] rowCols = a.cols();
        Integer[] order = new Integer[a.nRows];
        for (int r = 0; r < a.nRows; r++) order[r] = r;
        Arrays.sort(order, (x, y) -> Integer.compare(rowPtr[x + 1] - rowPtr[x], rowPtr[y + 1] - rowPtr[y]));
        boolean[] used = new boolean[a.nCols];
        int lb = 0;
        for (int r : order) {
            if (rowPtr[r + 1] == rowPtr[r]) continue;
            boolean free = true;
            for (int k = rowPtr[r]; k < rowPtr[r + 1] && free; k++) free = !used[rowCols[k]];
            if (free) {
                for (int k = rowPtr[r]; k < rowPtr[r + 1]; k++) used[rowCols[k]] = true;
                lb++;
            }
        }
        return lb;
    }

    /** Limite inferior por relaxação lagrangiana com subgradiente (Beasley, 1990). */
    public static int lagrangianBound(CoverageMatrix a, int upperBound, double limitSeconds, int maxIters) {
        long deadline = System.nanoTime() + (long) (limitSeconds * 1e9);
        Reduced red = reduce(a);
        CoverageMatrix c = red.matrix();
        if (c.nRows == 0) return 0;
        int[] rowPtr = c.rowPtr();
        int[] rowCols = c.cols();
        double[] u = new double[c.nRows];
        for (int r = 0; r < c.nRows; r++) {
            double best = 0;
            for (int k = rowPtr[r]; k < rowPtr[r + 1]; k++) {
                best = Math.max(best, 1.0 / Math.max(1, c.colSize(rowCols[k])));
            }
            u[r] = best;
        }
        double[] cost = new double[c.nCols];
        boolean[] x = new boolean[c.nCols];
        double[] g = new double[c.nRows];
        double bestL = Double.NEGATIVE_INFINITY;
        double lambda = 2.0;
        int stall = 0;
        for (int it = 0; it < maxIters && System.nanoTime() < deadline; it++) {
            double l = 0;
            for (double v : u) l += v;
            for (int j = 0; j < c.nCols; j++) {
                double s = 1.0;
                for (int k = c.colPtr[j]; k < c.colPtr[j + 1]; k++) s -= u[c.rows[k]];
                cost[j] = s;
                x[j] = s < 0;
                if (x[j]) l += s;
            }
            if (l > bestL + 1e-6) {
                bestL = l;
                stall = 0;
            } else if (++stall >= 30) {
                lambda /= 2;
                stall = 0;
                if (lambda < 1e-4) break;
            }
            double n2 = 0;
            for (int r = 0; r < c.nRows; r++) {
                double gi = 1.0;
                for (int k = rowPtr[r]; k < rowPtr[r + 1]; k++) if (x[rowCols[k]]) gi -= 1.0;
                if (u[r] <= 0 && gi < 0) gi = 0;
                g[r] = gi;
                n2 += gi * gi;
            }
            if (n2 <= 1e-12) break;
            double stepSize = lambda * (1.05 * upperBound - l) / n2;
            for (int r = 0; r < c.nRows; r++) u[r] = Math.max(0, u[r] + stepSize * g[r]);
        }
        return (int) Math.ceil(bestL - 1e-6);
    }

    // ------------------------------------------------------------------ redução

    /**
     * Instância sem linhas vazias e sem linhas/colunas repetidas.
     *
     * @param cols     coluna original de cada coluna reduzida
     * @param colToRed coluna reduzida que representa cada coluna original (−1 se vazia)
     */
    public record Reduced(CoverageMatrix matrix, int[] cols, int[] colToRed) {
    }

    public static Reduced reduce(CoverageMatrix a) {
        int[] rowPtr = a.rowPtr();
        int[] rowCols = a.cols();
        Map<Key, Integer> seenRows = new HashMap<>();
        List<Integer> keptRows = new ArrayList<>();
        for (int r = 0; r < a.nRows; r++) {
            if (rowPtr[r + 1] == rowPtr[r]) continue;
            if (seenRows.putIfAbsent(new Key(rowCols, rowPtr[r], rowPtr[r + 1]), r) == null) keptRows.add(r);
        }
        int[] colLen = new int[a.nCols];
        for (int r : keptRows) for (int k = rowPtr[r]; k < rowPtr[r + 1]; k++) colLen[rowCols[k]]++;
        int[][] byCol = new int[a.nCols][];
        for (int c = 0; c < a.nCols; c++) byCol[c] = new int[colLen[c]];
        int[] fill = new int[a.nCols];
        for (int nr = 0; nr < keptRows.size(); nr++) {
            int r = keptRows.get(nr);
            for (int k = rowPtr[r]; k < rowPtr[r + 1]; k++) {
                int c = rowCols[k];
                byCol[c][fill[c]++] = nr;
            }
        }
        Map<Key, Integer> seenCols = new HashMap<>();
        List<Integer> keptCols = new ArrayList<>();
        int[] colToRed = new int[a.nCols];
        Arrays.fill(colToRed, -1);
        for (int c = 0; c < a.nCols; c++) {
            if (byCol[c].length == 0) continue;
            Integer prev = seenCols.putIfAbsent(new Key(byCol[c], 0, byCol[c].length), keptCols.size());
            if (prev == null) {
                colToRed[c] = keptCols.size();
                keptCols.add(c);
            } else {
                colToRed[c] = prev;
            }
        }
        int[][] cols = new int[keptCols.size()][];
        for (int j = 0; j < cols.length; j++) cols[j] = byCol[keptCols.get(j)];
        return new Reduced(CoverageMatrix.fromColumns(keptRows.size(), cols),
                keptCols.stream().mapToInt(Integer::intValue).toArray(), colToRed);
    }

    private record Key(int[] data, int from, int to) {
        @Override
        public boolean equals(Object o) {
            return o instanceof Key k && Arrays.equals(data, from, to, k.data, k.from, k.to);
        }

        @Override
        public int hashCode() {
            int h = 1;
            for (int i = from; i < to; i++) h = 31 * h + data[i];
            return h;
        }
    }

    // ------------------------------------------------------------------ exato

    /**
     * @param cols  colunas escolhidas (originais), ou null se o solver não achou solução
     * @param bound limite inferior provado, ou null
     */
    public record Exact(int[] cols, Integer bound, String status, int rows, int columns, long nnz) {
    }

    /** Cobertura exata com HiGHS (o mesmo solver do motor de referência em Python). */
    public static Exact exact(CoverageMatrix a, double limitSeconds, long maxNnz, int threads) {
        Reduced red = reduce(a);
        CoverageMatrix ar = red.matrix();
        if (ar.nRows == 0) {
            return new Exact(new int[0], 0, "vazio", 0, 0, 0);
        }
        if (ar.nnz() > maxNnz) {
            return new Exact(null, null, "grande demais (> " + maxNnz + " pares)", ar.nRows, ar.nCols, ar.nnz());
        }
        int[] rowPtr = ar.rowPtr();
        int[] rowCols = ar.cols();
        double[] cost = new double[ar.nCols];
        Arrays.fill(cost, 1.0);
        MipResult res = solveCover(ar.nCols, ar.nRows, rowPtr, rowCols, null, null, cost, limitSeconds, threads);

        int[] sel = null;
        if (res.chosen() != null) {
            sel = Arrays.stream(res.chosen()).map(j -> red.cols()[j]).toArray();
        }
        Integer bound = res.bound() == null ? null : (int) Math.ceil(res.bound() - 1e-6);
        if (res.optimal() && sel != null) bound = sel.length;
        return new Exact(sel, bound, res.status(), ar.nRows, ar.nCols, ar.nnz());
    }

    private record MipResult(int[] chosen, Double bound, boolean optimal, String status) {
    }

    /**
     * min Σ cost·x  s.a.  cada linha coberta por ao menos uma coluna escolhida, x binário.
     *
     * @param rowList linhas a cobrir (índices em rowPtr), ou null para todas as {@code nRows}
     * @param colOf   coluna global → variável local; null = identidade
     *
     * <p>Não passa solução inicial: {@code setHint} derruba a JVM com o HiGHS do OR-Tools 9.14 (SIGSEGV).
     */
    private static MipResult solveCover(int nVars, int nRows, int[] rowPtr, int[] rowCols, int[] rowList,
                                        Map<Integer, Integer> colOf, double[] cost,
                                        double seconds, int threads) {
        loadNative();
        MPSolver solver = MPSolver.createSolver("HIGHS");
        if (solver == null) throw new IllegalStateException("Solver HiGHS indisponível no OR-Tools.");
        solver.suppressOutput();
        try {
            MPVariable[] x = solver.makeBoolVarArray(nVars);
            MPObjective obj = solver.objective();
            for (int j = 0; j < nVars; j++) obj.setCoefficient(x[j], cost[j]);
            obj.setMinimization();
            int n = rowList == null ? nRows : rowList.length;
            for (int i = 0; i < n; i++) {
                int r = rowList == null ? i : rowList[i];
                MPConstraint ct = solver.makeConstraint(1.0, MPSolver.infinity());
                for (int k = rowPtr[r]; k < rowPtr[r + 1]; k++) {
                    int v = colOf == null ? rowCols[k] : colOf.get(rowCols[k]);
                    ct.setCoefficient(x[v], 1.0);
                }
            }
            solver.setTimeLimit(Math.max(1L, (long) (seconds * 1000)));
            if (threads > 1) solver.setNumThreads(threads);
            MPSolver.ResultStatus st = solver.solve();

            int[] chosen = null;
            if (st == MPSolver.ResultStatus.OPTIMAL || st == MPSolver.ResultStatus.FEASIBLE) {
                List<Integer> out = new ArrayList<>();
                for (int j = 0; j < nVars; j++) if (x[j].solutionValue() > 0.5) out.add(j);
                chosen = out.stream().mapToInt(Integer::intValue).toArray();
            }
            Double bound = null;
            double b = obj.bestBound();
            if (chosen != null && Double.isFinite(b) && b > 0 && b <= obj.value() + 1e-6) bound = b;
            String status = switch (st) {
                case OPTIMAL -> "ótimo";
                case FEASIBLE -> "limite de tempo";
                default -> st.name().toLowerCase();
            };
            return new MipResult(chosen, bound, st == MPSolver.ResultStatus.OPTIMAL, status);
        } finally {
            solver.delete();
        }
    }

    // ------------------------------------------------------------------ LNS

    public record LnsStats(int attempts, int improvements, double seconds) {
    }

    public record LnsResult(int[] cols, LnsStats stats) {
    }

    /** Busca em vizinhança grande: remove k gateways vizinhos e recobre os órfãos de forma exata. */
    public static LnsResult lns(CoverageMatrix a, int[] selection, double[] cx, double[] cy,
                                double limitSeconds, long seed, int kMin, int kMax, double subSeconds) {
        long t0 = System.nanoTime();
        long deadline = t0 + (long) (limitSeconds * 1e9);
        Random rng = new Random(seed);
        int[] rowPtr = a.rowPtr();
        int[] rowCols = a.cols();
        List<Integer> sel = new ArrayList<>(Arrays.stream(selection).boxed().toList());
        int[] cont = coverCount(a, selection);
        int attempts = 0;
        int improvements = 0;
        while (System.nanoTime() < deadline && sel.size() > 1) {
            attempts++;
            int lo = Math.min(kMin, sel.size());
            int hi = Math.min(kMax, sel.size());
            int k = lo + rng.nextInt(hi - lo + 1);
            int g = sel.get(rng.nextInt(sel.size()));
            Integer[] byDist = sel.toArray(new Integer[0]);
            Arrays.sort(byDist, (p, q) -> Double.compare(
                    Math.hypot(cx[p] - cx[g], cy[p] - cy[g]), Math.hypot(cx[q] - cx[g], cy[q] - cy[g])));
            List<Integer> removed = Arrays.asList(byDist).subList(0, k);

            int[] c2 = cont.clone();
            for (int c : removed) for (int i = a.colPtr[c]; i < a.colPtr[c + 1]; i++) c2[a.rows[i]]--;
            List<Integer> orphans = new ArrayList<>();
            for (int c : removed) {
                for (int i = a.colPtr[c]; i < a.colPtr[c + 1]; i++) {
                    int r = a.rows[i];
                    if (c2[r] == 0 && cont[r] > 0) {
                        c2[r] = -1; // marca para não repetir
                        orphans.add(r);
                    }
                }
            }
            for (int r : orphans) c2[r] = 0;

            int[] fresh;
            if (orphans.isEmpty()) {
                fresh = new int[0];
            } else {
                fresh = recoverExactly(orphans, rowPtr, rowCols, subSeconds, rng);
                if (fresh == null) continue;
            }
            Set<Integer> remSet = new HashSet<>(removed);
            boolean better = fresh.length < removed.size();
            boolean sideways = fresh.length == removed.size()
                    && !remSet.equals(new HashSet<>(Arrays.stream(fresh).boxed().toList()))
                    && rng.nextDouble() < 0.3;
            if (better || sideways) {
                if (better) improvements++;
                sel.removeIf(remSet::contains);
                for (int c : fresh) sel.add(c);
                cont = c2;
                for (int c : fresh) for (int i = a.colPtr[c]; i < a.colPtr[c + 1]; i++) cont[a.rows[i]]++;
            }
        }
        return new LnsResult(sel.stream().mapToInt(Integer::intValue).toArray(),
                new LnsStats(attempts, improvements, (System.nanoTime() - t0) / 1e9));
    }

    private static int[] recoverExactly(List<Integer> orphans, int[] rowPtr, int[] rowCols, double seconds, Random rng) {
        Map<Integer, Integer> local = new HashMap<>();
        List<Integer> cols = new ArrayList<>();
        for (int r : orphans) {
            for (int k = rowPtr[r]; k < rowPtr[r + 1]; k++) {
                if (local.putIfAbsent(rowCols[k], cols.size()) == null) cols.add(rowCols[k]);
            }
        }
        double[] cost = new double[cols.size()];
        for (int j = 0; j < cost.length; j++) cost[j] = 1.0 + rng.nextDouble() * 1e-3; // desempate aleatório pequeno
        int[] rowList = orphans.stream().mapToInt(Integer::intValue).toArray();
        MipResult res = solveCover(cols.size(), rowList.length, rowPtr, rowCols, rowList, local, cost, seconds, 1);
        if (res.chosen() == null) return null;
        return Arrays.stream(res.chosen()).map(cols::get).toArray();
    }

    // ------------------------------------------------------------------ heap

    /** Heap mínimo de longs. A chave codifica (maior ganho primeiro, depois menor coluna). */
    static final class LongHeap {
        private static final long MAX_GAIN = (1L << 32) - 1;
        private long[] h;
        private int n;

        LongHeap(int capacity) {
            h = new long[Math.max(16, capacity)];
        }

        static long key(long gain, int col) {
            return ((MAX_GAIN - Math.min(gain, MAX_GAIN)) << 31) | col;
        }

        static long gain(long key) {
            return MAX_GAIN - (key >>> 31);
        }

        static int col(long key) {
            return (int) (key & ((1L << 31) - 1));
        }

        boolean isEmpty() {
            return n == 0;
        }

        long peek() {
            return h[0];
        }

        void push(long v) {
            if (n == h.length) h = Arrays.copyOf(h, n * 2);
            int i = n++;
            h[i] = v;
            while (i > 0) {
                int p = (i - 1) >>> 1;
                if (h[p] <= h[i]) break;
                long t = h[p];
                h[p] = h[i];
                h[i] = t;
                i = p;
            }
        }

        long pop() {
            long top = h[0];
            h[0] = h[--n];
            int i = 0;
            while (true) {
                int l = 2 * i + 1;
                if (l >= n) break;
                int m = (l + 1 < n && h[l + 1] < h[l]) ? l + 1 : l;
                if (h[i] <= h[m]) break;
                long t = h[m];
                h[m] = h[i];
                h[i] = t;
                i = m;
            }
            return top;
        }
    }
}
