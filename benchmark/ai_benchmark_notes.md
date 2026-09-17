# SnakeAI benchmark

Run: `/opt/homebrew/bin/flutter test --no-pub benchmark/ai_benchmark.dart --reporter expanded`

Recorded using Flutter 3.44.4, Dart 3.12.2, native Flutter test/JIT on macOS.
24 seeded fixtures per size, three obstacle snakes (up to eight cells each),
five-cell controlled snake, two foods except every fourth fixture has no food.
960 warm-up decisions per implementation; five rotating-order samples of 960
decisions each. Fixture creation is untimed. Same seeded RNG and fixture order.
Includes legacy, allocation-heavy behavior-corrected reference, and optimized.
Complete real output is in `ai_benchmark_run.json`.

Median microseconds per decision (one run; not web/WASM or game FPS):

| Grid | Level | Legacy | Corrected | Optimized |
|---|---|---:|---:|---:|
| 20x28 | easy | 4.12 | 4.02 | 3.03 |
| 20x28 | medium | 53.24 | 54.08 | 5.29 |
| 20x28 | hard | 125.13 | 153.60 | 12.07 |
| 20x28 | expert | 770.10 | 346.21 | 26.91 |
| 40x40 | easy | 2.31 | 2.33 | 1.02 |
| 40x40 | medium | 162.73 | 171.05 | 13.09 |
| 40x40 | hard | 292.23 | 374.72 | 26.16 |
| 40x40 | expert | 2391.23 | 960.06 | 81.98 |

Decisions: easy/medium/hard match legacy on all 48 benchmark fixtures; expert
changes 9/24 and 7/24 respectively. All optimized decisions match the corrected
reference on these walled fixtures. Tests also compare 640 seeded varying-size
fixtures against the corrected reference, and 300 against legacy for the first
three difficulties. These are finite regression samples, not a proof of global
policy equivalence or guaranteed survival.

Behavior corrections are separate from allocation improvements: wrapping moves,
wrapped heading inference, opening the simulated tail as a reachability target,
retaining the previous head in simulated occupancy, allowing flood-fill to start
at the new head, retaining the tail on growth, and handling one-segment snakes.
All optimized traversals, including flood-fill, use wrapping neighbors when walls
are disabled. The corrected allocation-heavy reference retains bounded flood-fill
as an additional historical limitation; randomized equivalence does not assert
that every toroidal topology is equivalent to that reference.

Allocation design: BFS/flood-fill traversal allocates no per-visited-cell objects;
integer occupancy, scratch occupancy, neighbors, FIFO, visited generations,
distance and first-direction arrays are reused. Direction lists and a bounded
number of decision-level Points still allocate. Easy intentionally uses local
body scans rather than clearing a grid; the first benchmark identified that as
a regression and the final benchmark includes the corrected fast path. No heap
allocation profiler was used, so no measured allocated-byte/GC claims are made.

Integration limitation: at inspection, production files imported only
AiDifficulty, not SnakeAI; VsAiGame has its own private AI implementation. This
work improves the reusable SnakeAI class, not that separate live decision path.
