import { describe, expect, it } from "vitest";
import puzzles from "../../Sources/HerbertCore/Resources/original-problems.json";
import compatibility from "../../Tests/HerbertCoreTests/Fixtures/hoj-compatibility.json";
import references from "./native-fixtures.json";
import { commands, countBytes, evaluate } from "../src/judge";

describe("native H compatibility", () => {
    for (const fixture of compatibility)
        it(fixture.name, () => {
            const iterator = commands(fixture.source);
            let actual = "";
            while (actual.length < fixture.commands.length) {
                const next = iterator.next();
                if (next.done) break;
                actual += next.value;
            }
            expect(actual).toBe(fixture.commands);
            expect(countBytes(fixture.source)).toBe(fixture.bytes);
        });
    for (const [index, fixture] of references.entries())
        it(`Swift judge ${index}: ${fixture.id}`, () => {
            const puzzle = puzzles.find((p) => p.id === fixture.id)!;
            const actual = evaluate(fixture.source, puzzle);
            expect({
                accepted: actual.accepted,
                bytes: actual.bytes,
                steps: actual.steps,
                litTargets: actual.litTargets,
            }).toEqual({
                accepted: fixture.accepted,
                bytes: fixture.bytes,
                steps: fixture.steps,
                litTargets: fixture.litTargets,
            });
        });
    it("rejects malformed and oversized programs", () => {
        for (const source of [
            "s4",
            "a(X):s\na",
            "a:s\na:s\na",
            "a(X):X\na(256)",
            "s\ns",
            "s".repeat(16385),
        ]) {
            expect(evaluate(source, puzzles[0]).accepted).toBe(false);
        }
    });
    it("bounds silent recursion and excessive nesting", () => {
        expect(() => [...commands("a:a\na", 100)]).toThrow(
            "VM expansion limit",
        );
        expect(
            evaluate("a(X):X\na(".repeat(65) + "s" + ")".repeat(65), puzzles[0])
                .accepted,
        ).toBe(false);
    });
    it("bounds cumulative copying in growing tail-recursive arguments", () => {
        expect(() => [...commands("b(X):b(Xs)\nb(s)")]).toThrow(
            "Expansion work limit",
        );
    });
    it.each([21, 41, 81])(
        "bounds repeated numeric expressions with %i terms",
        (terms) => {
            const expression =
                Array((terms - 1) / 2)
                    .fill("A-A")
                    .join("+") + "+A";
            expect(() => [...commands(`a(A):a(${expression})\na(1)`)]).toThrow(
                "Expansion work limit",
            );
        },
    );
    it.each([13, 26])(
        "bounds pass-through recursion with %i parameters",
        (arity) => {
            const parameters = Array.from({ length: arity }, (_, i) =>
                String.fromCharCode(65 + i),
            ).join(",");
            const initial = Array(arity).fill("s").join(",");
            expect(() => [
                ...commands(`a(${parameters}):a(${parameters})\na(${initial})`),
            ]).toThrow("Expansion work limit");
        },
    );
    it("reserves compression bonuses for complete answers", () => {
        const rows = Array(25).fill(".".repeat(25));
        rows[12] = "............uoo..........";
        const partial = evaluate("rs", { id: 1, byteLimit: 20, rows });
        expect(partial.accepted).toBe(false);
        expect(partial.points).toBe(40);
        expect(
            evaluate("rss", { id: 1, byteLimit: 20, rows }).points,
        ).toBeGreaterThanOrEqual(80);
    });
    it("walls block and traps reset lights", () => {
        const rows = Array(25).fill(".".repeat(25));
        rows[12] = "............uo*o.........";
        const puzzle = { id: 1, byteLimit: 20, rows };
        expect(evaluate("rsss", puzzle).litTargets).toBe(1);
        expect(evaluate("rssslslssls", puzzle).accepted).toBe(true);
        rows[12] = "............uxo..........";
        expect(evaluate("rssss", puzzle).litTargets).toBe(0);
    });
});
