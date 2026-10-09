# HOJ compatibility audit

[简体中文](hoj-compatibility.zh-CN.md)

Audited on 2026-10-08 against [quolc/hoj](https://github.com/quolc/hoj), pinned to
[`f5d1ee4`](https://github.com/quolc/hoj/tree/f5d1ee4e3616c1b2cf79e70a0ccee267b5f09ea3),
and the [published rules](http://herbert.tealang.info/rule.php).

The repository describes itself as fragments of Herbert Online Judge. It contains a Ruby
interpreter and sample judge; it does not contain the Flash UI, ranking server, or the
complete original Microsoft/Wild Noodle application. Findings about these fragments do
not establish the behavior of every deployed version. No reference code or assets were
copied into this independently implemented MIT project.

## Results

| Behavior | Reference evidence | Native app |
| --- | --- | --- |
| Board encoding | `judge/judge.rb`: `x` blocks entry, `*` resets pressed targets | Fixed reversed decoding; community JSON preserved byte for byte. Original lesson generator now uses the same encoding. |
| Initial heading | North | Matches |
| Wall / board edge | `s` leaves position unchanged; execution continues | Matches; blocked commands count as a robot step and add no trail segment. |
| Movement after a block | Subsequent turns and moves execute normally | Matches; tested with community #0001's corridor. |
| Trap | All targets become unpressed; robot stays on the trap | Matches; trail remains visible, since it is a visualization of movement rather than target state. |
| Revisit | A pressed target is not counted again; erased targets can be pressed again | Matches |
| Completion | Stop immediately on the last target, before further instructions | Matches, including trailing infinite recursion |
| Numeric branching | A nonpositive numeric argument skips that procedure call; execution returns to the caller | Matches for valid in-range arguments. There is no sensor branch or wall-triggered conditional in H. |
| Instruction parameters | Substitute the caller's arguments, including nested calls; recurse and concatenate | Matches the differential fixtures, including growing command arguments and captured numbers. |
| Code size | Letters count individually; a sequence of digits is one byte; syntax punctuation is free | Matches for normalized valid programs. Formatting differences below. |
| Puzzle length | Rules require `bytes <= limit`; sample judge reads `@limit` but never uses it | Native app checks before execution. The fragment alone cannot prove the server omitted this check. |
| Ranking | Rules rank by smaller byte count, then earlier submission for ties | Local shortest solution uses byte count only. No online ranking or composite points formula is implemented or present in this repository. |

The earlier native decoder incorrectly treated community walls as traps and community
traps as walls. Existing drafts and progress files are preserved. Old completions are not
silently deleted or automatically replayed on startup; replay a saved solution to verify
it under the corrected rules. Imported completion backups are replayed and rejected if
invalid. The 30 original lessons retain their intended layouts and solutions after their
symbols were corrected together with the decoder.

## Deliberate differences and recommendations

1. **Whitespace:** the Ruby parser rejects spaces, tabs and CRLF; raw `CountSrc` also
   counts spaces and `\r`. Native code accepts common formatting and excludes whitespace
   from byte counts, following the rules' definition in terms of letters and numbers.
   For example, `a(X):s a(X-1)\r\na(12)` counts 8 bytes here, 10 in raw `CountSrc`.
   Keeping formatting free is more suitable for a mobile editor and does not shorten
   the effective program.
2. **Numbers:** the rules prohibit magnitudes above 255, but the Ruby fragment accepts
   `a(X):sa(X-1)\na(256)`. Native literals and evaluated arguments enforce ±255. Keep
   this check. Unary signs such as `a(-1)` are accepted as a small native syntax extension;
   Ruby requires a subtraction expression such as `a(0-1)` instead.
3. **Typing:** Ruby infers parameter types before running and can reject an unused command
   argument, such as `a(X):s\na(s)`. Native code accepts it and checks types when a parameter
   is consumed. Errors in unused or skipped branches may consequently remain unreported.
   Retain this predictable behavior for now; static type diagnostics would be a separate
   editor improvement, rather than reproducing accidental inference failures.
4. **Short-circuit diagnostics:** Ruby stops evaluating numeric arguments at the first
   nonpositive argument. Native code resolves all arguments before deciding to skip.
   This can report an out-of-range later argument even if an earlier argument is zero.
   This does not change valid in-range program traces; it keeps the ±255 rule consistent.
5. **Execution budget:** Ruby counts primitive instructions and procedure expansions
   together toward 1,000,000 interpreter turns. Native UI steps count robot instructions;
   the VM independently limits expansion to 1,000,000 (including lazy parameter frames).
   These are not identical for parameter-heavy programs or at limit boundaries. Successful
   completion takes precedence over later work in both. Do not compare UI step counts as
   scores or claim identical timeout thresholds.
6. **Memory:** Ruby checks the eagerly expanded character buffer against 2,000,000 characters,
   while the rules describe 1,000,000 bytes. Native code uses a bounded lazy representation,
   with additional source, nesting and stack guards. It keeps tail recursion cancellable
   without freezing the UI. Preserve these protections, and make the differences explicit;
   exact acceptance of pathological resource-limit programs is not promised.
7. **Scoring:** keep shortest-code scoring and immediate completion. Do not add a movement
   efficiency penalty: wall bumps and extra turns can be intentional parts of a compact
   solution. A future online tie-break should use a server timestamp; local device time
   is insufficient for a competitive leaderboard.

Adjacent wall cells are now rendered as one outlined region in both board styles.
Classic uses solid black square edges; Modern rounds the outline. Holes and separate
diagonal wall groups remain distinct. This is a visual improvement only, without changing
which cells block the robot. The reference repository contains no wall renderer to compare.

## Reproduce

`swift test` runs the 17 independently authored command/byte fixtures against the native VM,
plus board, completion, trap and persistence integration tests. The optional Ruby check also
replays the community #0001 corridor after a wall collision (using an enlarged test-only
byte budget, leaving the archived four-byte limit unchanged). The same fixtures and all
30 current original lesson solutions (including the redesigned L07/L08 in 0.3.3) and eight independently found community #0001–#0020
study solutions were also replayed successfully against the pinned Ruby judge, within
their original byte budgets. See the [advanced course study](advanced-course-design.md).

Optional reference verification (requires Ruby and Git; runs a separate public checkout):

```sh
git clone https://github.com/quolc/hoj.git /tmp/hoj-reference
git -C /tmp/hoj-reference checkout f5d1ee4e3616c1b2cf79e70a0ccee267b5f09ea3
ruby scripts/check_hoj_reference.rb /tmp/hoj-reference
```

The script pins the commit and bounds interpreter turns. It does not download the reference
or bundle it into either app. Passing these fixtures demonstrates the tested semantics,
not exhaustive equivalence of every possible H program or the live judge.
