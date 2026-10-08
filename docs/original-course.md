# 30 original lessons

These puzzles were independently designed from the public H language and board rules, not adapted from the community archive. Original layouts, names, objectives, hints, generation code and reference programs are released under MIT.

Six chapters of five lessons move from orientation and obstacles to reuse, recursion, instruction arguments and composition. Each new concept starts with a small example and is transferred to a larger pattern. All lessons are unlocked. Objectives appear first; two hints are revealed individually. Alternative valid solutions are welcome.

Byte limits are verified achievable learning budgets, not claimed optimal scores or a numeric difficulty scale. Reference programs are test-only and excluded from app bundles. Names, goals and hints are localized in English, Chinese and Japanese.

| Lesson | Chapter | Name | Learning objective | Byte limit |
| --- | --- | --- | --- | --- |
| 10001 / L01 | Read the path | First light | Move one cell forward. The robot starts facing up. | 1 |
| 10002 / L02 | Read the path | Four lanterns | Count cells and light a straight row of four targets. | 4 |
| 10003 / L03 | Read the path | Right at the corner | Separate moving from turning: r turns without moving. | 7 |
| 10004 / L04 | Read the path | A turn to the left | Use l and keep track of the robot’s own heading. | 8 |
| 10005 / L05 | Read the path | Turn back | Visit both sides of the start using a half turn. | 8 |
| 10006 / L06 | Plan around obstacles | Around the block | Plan a detour around a wall; blocked moves stay in place. | 9 |
| 10007 / L07 | Plan around obstacles | Two bends ahead | Plan several waypoints before writing the whole route. | 15 |
| 10008 / L08 | Plan around obstacles | Keep the lights | Avoid a trap so the targets you already lit stay lit. | 13 |
| 10009 / L09 | Plan around obstacles | Light it again | Recover from a trap by revisiting any target it erased. | 17 |
| 10010 / L10 | Plan around obstacles | Perimeter patrol | Combine counting and turns to patrol a square boundary. | 28 |
| 10011 / L11 | Name a repeated idea | A name for three steps | Name three steps as a procedure and call it repeatedly. | 10 |
| 10012 / L12 | Name a repeated idea | Square stamp | Reuse a side-and-turn procedure four times. | 10 |
| 10013 / L13 | Name a repeated idea | Stair tiles | Find a repeated stair tile that ends facing up. | 12 |
| 10014 / L14 | Name a repeated idea | Four compass arms | Make an out-and-back procedure rotate toward the next arm. | 14 |
| 10015 / L15 | Name a repeated idea | Rhythm within rhythm | Group repeated procedure calls into a second procedure. | 14 |
| 10016 / L16 | Control recursion | A self-repeating stair | Use a procedure that calls itself after one stair tile. | 7 |
| 10017 / L17 | Control recursion | A counted corner | Use a numeric parameter to walk two different distances. | 11 |
| 10018 / L18 | Control recursion | Rectangle recipe | Compose a rectangle from one reusable counted walk. | 15 |
| 10019 / L19 | Control recursion | Growing spiral | Increase a numeric distance after each right turn. | 16 |
| 10020 / L20 | Control recursion | Descending staircase | Walk equal vertical and horizontal legs, then reduce both. | 19 |
| 10021 / L21 | Pass instructions | Pass a pattern | Pass a side-and-turn instruction sequence as a parameter. | 11 |
| 10022 / L22 | Pass instructions | A reusable repeater | Combine a repetition count with an instruction parameter. | 16 |
| 10023 / L23 | Pass instructions | Alternating rows | Alternate two instruction patterns to sweep parallel rows. | 29 |
| 10024 / L24 | Pass instructions | A growing thread | Grow an instruction parameter by appending two steps. | 11 |
| 10025 / L25 | Pass instructions | Expanding compass | Reuse a growing instruction sequence for both outward and return travel. | 12 |
| 10026 / L26 | Compose a small program | Twin towers | Combine a counted walk, a return trip and a connecting bridge. | 22 |
| 10027 / L27 | Compose a small program | Woven field | Use a finite row count and alternate the connector’s turn direction. | 25 |
| 10028 / L28 | Compose a small program | Rising comb | Grow each branch, return to the baseline, then shift one cell. | 22 |
| 10029 / L29 | Compose a small program | Nested windows | Nest a counted walk inside a fourfold instruction repeater. | 24 |
| 10030 / L30 | Compose a small program | Clockwork garden | Combine counted repetition, shrinking squares and fourfold rotation. | 31 |

`scripts/check.sh` replays all references with the real H compiler and game engine, checking byte limits, boards, distinct IDs, translations and save compatibility. App Store targets link HerbertCore only; the archive lives in optional HerbertCommunity.

Spoilers: [test-only references](../Tests/HerbertCoreTests/Fixtures/original-solutions.json). Design source: [generator](../scripts/generate_original_problems.py).
