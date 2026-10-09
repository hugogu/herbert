# 30 original lessons

These puzzles were independently designed from the public H language and board rules, not adapted from the community archive. Original layouts, names, objectives, hints, generation code and reference programs are released under MIT.

Ten introductory lessons in two chapters cover movement and obstacles, then reuse, recursion, instruction arguments and composition. Only the first two fit a direct sequence of moves. Four advanced chapters retain twenty walled challenges: wall-assisted counting, state and return invariants, nested patterns and recursive systems. They introduce parameter swaps, recursive unwinding, mutual recursion, reflection and layered composition. Each new concept starts with a small example and is transferred to a larger pattern. All lessons are unlocked. Objectives appear first; two hints are revealed individually. Alternative valid solutions are welcome.

Byte limits are verified achievable learning budgets, not claimed optimal scores or a numeric difficulty scale. Scored puzzle reference programs are test-only and excluded from app bundles; the AI prompt uses separate public teaching boards. Names, goals and hints are localized in English, Chinese and Japanese.

v0.3.3 uses continuous L01–L30 display numbers. L07/L08 are redesigned as Turning rose and Tandem lanterns; other boards are retained. Display numbers are separate from internal save IDs, and retired records and historical match snapshots remain readable.

| Lesson | Chapter | Name | Learning objective | Byte limit |
| --- | --- | --- | --- | --- |
| 10001 / L01 | Movement, reuse and recursion | First light | Move one cell forward. The robot starts facing up. | 1 |
| 10006 / L02 | Movement, reuse and recursion | Around the block | Plan a detour around a wall; blocked moves stay in place. | 9 |
| 10012 / L03 | Movement, reuse and recursion | Square stamp | Reuse a side-and-turn procedure four times. | 10 |
| 10017 / L04 | Movement, reuse and recursion | A counted corner | Use a numeric parameter to walk two different distances. | 11 |
| 10022 / L05 | Movement, reuse and recursion | A reusable repeater | Combine a repetition count with an instruction parameter. | 16 |
| 10024 / L06 | Instructions and composition | A growing thread | Grow an instruction parameter by appending two steps. | 11 |
| 10051 / L07 | Instructions and composition | Turning rose | Grow a folded out-and-back instruction and rotate three sizes into four petals. | 34 |
| 10052 / L08 | Instructions and composition | Tandem lanterns | Compose a counted walk, a fourfold repeater, two lantern frames and their bridge. | 23 |
| 10027 / L09 | Instructions and composition | Woven field | Use a finite row count and alternate the connector’s turn direction. | 25 |
| 10030 / L10 | Instructions and composition | Clockwork garden | Combine counted repetition, shrinking squares and fourfold rotation. | 31 |
| 10031 / L11 | Let walls do the counting | Tidal locks | Synchronize unequal lanes against walls, with a finite count and alternating turns. | 25 |
| 10032 / L12 | Let walls do the counting | Resonant organ | Reuse one out-and-back routine in six unequal walled pipes. | 23 |
| 10033 / L13 | Let walls do the counting | Stepped cloister | Track two dimensions while a rectangular route contracts inward. | 31 |
| 10034 / L14 | Let walls do the counting | Counterpoise | Grow branches while alternating chirality and preserving a shared spine. | 32 |
| 10035 / L15 | Let walls do the counting | Gated pinwheel | Compose a bent arm that returns home facing the next rotated arm. | 30 |
| 10036 / L16 | Reason about recursive state | Braided stair | Swap two instruction arguments while the horizontal reach shrinks. | 25 |
| 10037 / L17 | Reason about recursive state | Counterweight stair | Change two numeric parameters in opposite directions, retrace the stair and rotate it four ways. | 39 |
| 10038 / L18 | Reason about recursive state | Hinged rosette | Use work after a recursive call to retrace a nested arm, then rotate it. | 29 |
| 10039 / L19 | Reason about recursive state | Lantern boughs | Visit both recursive children and restore the parent’s position and heading. | 26 |
| 10040 / L20 | Reason about recursive state | Contrary courts | Use mutually recursive procedures that exchange dimensions and turn direction. | 51 |
| 10041 / L21 | Build patterns within patterns | Lattice atelier | Nest a fourfold instruction repeater inside finite rows of reusable window tiles. | 40 |
| 10042 / L22 | Build patterns within patterns | Shifting registers | Exchange two numeric roles while alternating the connector’s turn. | 32 |
| 10043 / L23 | Build patterns within patterns | Recursive lantern | Assemble four rotated subcurves by swapping two turn parameters at each level. | 44 |
| 10044 / L24 | Build patterns within patterns | Snowmelt seal | Grow an instruction motif recursively, then execute only the selected expansion level. | 34 |
| 10045 / L25 | Build patterns within patterns | Lantern atlas | Place four recursive copies at offsets, using depth and spacing as independent parameters. | 43 |
| 10046 / L26 | Compose recursive systems | Dragon gallery | Use two mutually recursive turns to generate a folding curve rather than a repeated tile. | 28 |
| 10047 / L27 | Compose recursive systems | Dragon compass | Construct inverse recursive procedures so a folded curve returns before its next rotation. | 60 |
| 10048 / L28 | Compose recursive systems | Chiral canopy | Combine a branching return invariant with chirality passed through four recursive levels. | 48 |
| 10049 / L29 | Compose recursive systems | Vaulted mosaic | Nest window, row, shrinking tier and rotation routines, each with its own return invariant. | 63 |
| 10050 / L30 | Compose recursive systems | Astral cathedral | Compose a window generator with a chiral branching tree and a higher-order rotation routine. | 56 |

`scripts/check.sh` replays all references with the real H compiler and game engine, checking byte limits, boards, distinct IDs, translations and save compatibility. App Store puzzle resources come only from HerbertCore; both editions also link the resource-free HerbertBattlefield. The archive lives in optional HerbertCommunity.

Spoilers: [test-only references](../Tests/HerbertCoreTests/Fixtures/original-solutions.json). Design source: [generator](../scripts/generate_original_problems.py).
