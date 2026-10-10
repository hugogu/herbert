# 30 original lessons

These puzzles were independently designed from the public H language and board rules, not adapted from the community archive. Original layouts, names, objectives, hints, generation code and reference programs are released under MIT.

Ten introductory lessons in two chapters cover movement and obstacles, then reuse, recursion, instruction arguments and composition. Only the first two fit a direct sequence of moves. Four advanced chapters contain twenty open geometric challenges: wall-assisted counting, state and return invariants, nested patterns and recursive systems. L10–L30 use local wall stops, islands and traps rather than enclosing the reference route. L11–L22 have new geometry; L23–L30 retain their target motifs. They introduce parameter swaps, recursive unwinding, mutual recursion, reflection and layered composition. Each new concept starts with a small example and is transferred to a larger pattern. All lessons are unlocked. Objectives appear first; two hints are revealed individually. Alternative valid solutions are welcome.

Byte limits are verified achievable learning budgets, not claimed optimal scores or a numeric difficulty scale. Scored puzzle reference programs are test-only and excluded from app bundles; the AI prompt uses separate public teaching boards. Names, goals and hints are localized in English, Chinese and Japanese.

Display numbers remain continuous L01–L30. Revised L10–L30 use new internal IDs 10053–10073 so old solutions and completions are not applied to changed boards. Retired records remain importable and match history retains its original board snapshots. L01–L09 are unchanged.

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
| 10053 / L10 | Instructions and composition | Clockwork garden | Combine counted repetition, shrinking squares and fourfold rotation. | 33 |
| 10054 / L11 | Landmarks and geometric patterns | Tidal compass | Combine wall-assisted stops with four returning lantern loops. | 37 |
| 10055 / L12 | Landmarks and geometric patterns | Octave beacon | Compose straight rays and diagonal stair rays around a common center. | 39 |
| 10056 / L13 | Landmarks and geometric patterns | Prismatic kites | Build nested diamonds by reusing a diagonal step and shrinking its count. | 42 |
| 10057 / L14 | Landmarks and geometric patterns | Sandglass weave | Use separate shrinking and growing recursions to weave a reflected hourglass. | 55 |
| 10058 / L15 | Landmarks and geometric patterns | Orbital lanterns | Compose an outward trip, a square lantern and an exact return before rotation. | 34 |
| 10059 / L16 | Reason about recursive state | Ribbon wings | Swap two turn arguments while shrinking a folded ribbon, then unwind it. | 45 |
| 10060 / L17 | Reason about recursive state | Argyle constellation | Separate a diagonal walker, one diamond, one row and the complete constellation. | 58 |
| 10061 / L18 | Reason about recursive state | Folding shells | Use recursive unwinding to return from four nested folds and rotate the shell. | 33 |
| 10062 / L19 | Reason about recursive state | Twin coral | Visit both recursive branches, restore their parent pose and reflect the whole tree. | 33 |
| 10063 / L20 | Reason about recursive state | Counterturn medallion | Exchange rectangle dimensions and turn direction through mutual recursion. | 60 |
| 10064 / L21 | Build patterns within patterns | Lantern halo | Nest a centered window routine inside a two-window sector and a fourfold repeater. | 53 |
| 10065 / L22 | Build patterns within patterns | Woven vortices | Exchange two numeric roles and a turn argument while unfolding four returning vortices. | 57 |
| 10066 / L23 | Build patterns within patterns | Recursive lantern | Assemble four rotated subcurves by swapping two turn parameters at each level. | 44 |
| 10067 / L24 | Build patterns within patterns | Snowmelt seal | Grow an instruction motif recursively, then execute only the selected expansion level. | 34 |
| 10068 / L25 | Build patterns within patterns | Lantern atlas | Place four recursive copies at offsets, using depth and spacing as independent parameters. | 43 |
| 10069 / L26 | Compose recursive systems | Dragon gallery | Use two mutually recursive turns to generate a folding curve rather than a repeated tile. | 28 |
| 10070 / L27 | Compose recursive systems | Dragon compass | Construct inverse recursive procedures so a folded curve returns before its next rotation. | 60 |
| 10071 / L28 | Compose recursive systems | Chiral canopy | Combine a branching return invariant with chirality passed through four recursive levels. | 48 |
| 10072 / L29 | Compose recursive systems | Vaulted mosaic | Nest window, row, shrinking tier and rotation routines, each with its own return invariant. | 63 |
| 10073 / L30 | Compose recursive systems | Astral cathedral | Compose a window generator with a chiral branching tree and a higher-order rotation routine. | 56 |

`scripts/check.sh` replays all references with the real H compiler and game engine, checking byte limits, boards, distinct IDs, translations and save compatibility. App Store puzzle resources come only from HerbertCore; both editions also link the resource-free HerbertBattlefield. The archive lives in optional HerbertCommunity.

Spoilers: [test-only references](../Tests/HerbertCoreTests/Fixtures/original-solutions.json). Design source: [generator](../scripts/generate_original_problems.py).
