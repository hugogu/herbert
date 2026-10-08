# Advanced course design and community study

[详细中文分析](advanced-course-design.zh-CN.md)

On 2026-10-08, we inspected community #0001–#0020, checked safe-cell connectivity, and tried fixed cycles, growing command arguments and two-command-argument templates. Eight independently found solutions fit the archived limits and pass both the native engine and the pinned HOJ Ruby judge. The other twelve have not been solved within their byte budgets in this study. Visual observations about those boards are not claims of a solved algorithm or a minimum program size.

| Community problem | Verified bytes / archived limit |
| --- | --- |
| #0001 | 4 / 4 |
| #0002 | 4 / 4 |
| #0003 | 12 / 19 |
| #0004 | 9 / 20 |
| #0005 | 12 / 12 |
| #0006 | 10 / 16 |
| #0009 | 15 / 28 |
| #0014 | 8 / 8 |

The [study programs](../Tests/HerbertCoreTests/Fixtures/community-study-solutions.json) are independently authored, test-only fixtures. `swift test` checks their archived budgets and completion. The optional `ruby scripts/check_hoj_reference.rb /path/to/hoj` also replays them in the reference judge. All targets in each of the twenty boards are reachable without crossing a trap; finding a route is much easier than compressing it into the allowed program size.

The important findings are about structure, not counts. #0006 and #0014 use wall stops to adapt one growing action to unequal corridors. #0005 places traps beyond targets, making exact return behavior matter. #0009 has 312 targets, yet a two-command-argument growth program covers them in 15 bytes (the archived best is 11, which this study does not reproduce). #0011 has just twelve targets but exposes positioning, orientation and return-trip costs. #0020 has 262 walls and only 34 targets: doors and chambers carry both clues and constraints.

For #0014, `a(X):Xra(Xs)` followed by `a()` starts with an empty instruction argument; it is not a numeric countdown. For #0009, `a(X,Y):XXa(XY,Y)` followed by `a(l,srsl)` executes a growing composite twice, then appends another tile. These examples informed the learning goals, not the new layouts. No community board was renamed, rotated or assembled into an original lesson.

## Twenty new challenges

L01–L30 retain their IDs, layouts and budgets. L31–L50 add four chapters of five lessons:

| Lessons | Increasing reasoning burden | Spatial clues |
| --- | --- | --- |
| L31–L35 | Wall-assisted synchronization, finite counts, alternating turns, paired dimensions and final heading | Retreating locks, organ pipes, contracting cloisters, counterpoised arms, gated pinwheel |
| L36–L40 | Argument swaps, opposing numeric changes, recursive unwinding, two children and mutual recursion | Braided stairs, four return stairs, hinged rosette, lantern boughs, contrary courts |
| L41–L45 | Higher-order repeaters, exchanged numeric roles, four recursive subcurves and selective expansion | Lattice atelier, shifting registers, recursive lantern, snowmelt seal, lantern atlas |
| L46–L50 | Mutual folds, inverse procedures, depth/distance/chirality, nested return contracts and composition | Dragon gallery/compass, chiral canopy, vaulted mosaic, astral cathedral |

Every new board has walls bordering its safe route. L31/L32 deliberately overrun wall stops; removing the walls breaks their reference programs. Other walls separate neighboring layers, rooms and branches. Four symmetric trap caps in L44 forbid overshooting its folds. Byte limits are achievable practice budgets, not proven minima or a numeric difficulty scale. Alternative algorithms are accepted; human difficulty still needs playtesting.

## Testing the intended challenge

Independent primitive geometric routes generate the boards. Native tests replay the H references and compare completion, bytes, position, heading, instruction count, wall bumps and trap resets against those routes. The geometry generator does not interpret H. All fifty references also pass the pinned Ruby judge.

A bounded fixed-cycle probe found two overly easy drafts. `a:srsla` / `a` solved the original L37; `a:ssslslsla` / `a` solved the original L44. L37 now requires returning and rotating four opposing staircases. L44 now has four symmetric trap caps. Regression tests verify the known shortcuts enter an unsolved repeated state, rather than treating a fixed-step timeout as a proof. Template searches are not exhaustive and do not establish optimality.

README selections favor clear silhouettes, symmetry, continuous walls and legibility at thumbnail size. L49 Vaulted mosaic is the hero; L38 Hinged rosette, L44 Snowmelt seal and L50 Astral cathedral form the advanced gallery. Dense L45 and the small L47 are not promoted merely because their programs use more procedures. All published captures come from the running native app, with English UI in the English README and Chinese UI in the Chinese README.
