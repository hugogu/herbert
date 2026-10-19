// H semantics mirror HerbertCore. Cross-language fixtures are checked in CI.
type Instruction = { name: string; args?: Argument[] };
type Term = { sign: number; value: number | string };
type Argument = { code: Instruction[] } | { terms: Term[] };
type Value = { code: Instruction[]; size: number } | { number: number };
type Procedure = { parameters: string[]; body: Instruction[] };
export type Puzzle = { id: number; byteLimit: number; rows: string[] };
export type Evaluation = {
    accepted: boolean;
    bytes: number;
    steps: number;
    litTargets: number;
    targetCount: number;
    points: number;
    feedback: string;
};
const assert: (condition: unknown, message: string) => asserts condition = (
    condition,
    message,
) => {
    if (!condition) throw new Error(message);
};
const lower = (c: string) => /^[a-z]$/.test(c);
const upper = (c: string) => /^[A-Z]$/.test(c);
const primitive = (c: string) => "slr".includes(c);
export function countBytes(source: string): number {
    let count = 0,
        inNumber = false;
    for (const c of source) {
        if (/^[0-9]$/.test(c)) {
            if (!inNumber) count++;
            inNumber = true;
        } else {
            if (/^[a-zA-Z]$/.test(c)) count++;
            if (!/\s/u.test(c)) inNumber = false;
        }
    }
    return count;
}
class Parser {
    i = 0;
    depth = 0;
    constructor(readonly text: string) {}
    get c() {
        return this.text[this.i];
    }
    sequence(): Instruction[] {
        const result: Instruction[] = [];
        while (this.c !== undefined && this.c !== "," && this.c !== ")") {
            const name = this.c;
            this.i++;
            assert(lower(name) || upper(name), `Invalid instruction ${name}`);
            const instruction: Instruction = { name };
            if (lower(name) && !primitive(name)) {
                instruction.args = [];
                if (this.c === "(") {
                    assert(++this.depth <= 64, "Argument nesting exceeds 64");
                    this.i++;
                    while (true) {
                        instruction.args.push(this.argument());
                        if (String(this.c) === ",") {
                            this.i++;
                            continue;
                        }
                        assert(String(this.c) === ")", "Missing )");
                        this.i++;
                        this.depth--;
                        break;
                    }
                }
            }
            result.push(instruction);
        }
        return result;
    }
    argument(): Argument {
        let nesting = 0,
            numeric = false;
        for (const c of this.text.slice(this.i)) {
            if (!nesting && ",)".includes(c)) break;
            if (c === "(") nesting++;
            if (c === ")") nesting--;
            if (!nesting && /[0-9+-]/.test(c)) numeric = true;
        }
        if (!numeric) return { code: this.sequence() };
        const terms: Term[] = [];
        let sign = 1;
        if (this.c === "+" || this.c === "-") {
            sign = this.c === "-" ? -1 : 1;
            this.i++;
        }
        while (true) {
            let value: number | string;
            if (/^[0-9]$/.test(this.c ?? "")) {
                const start = this.i;
                while (/^[0-9]$/.test(this.c ?? "")) this.i++;
                value = Number(this.text.slice(start, this.i));
                assert(value <= 255, "Numeric literal exceeds 255");
            } else {
                assert(upper(this.c ?? ""), "Invalid numeric argument");
                value = this.c;
                this.i++;
            }
            terms.push({ sign, value });
            if (this.c === "+" || this.c === "-") {
                sign = this.c === "-" ? -1 : 1;
                this.i++;
            } else break;
        }
        assert(
            this.c === "," || this.c === ")",
            "Mixed numeric and code argument",
        );
        return { terms };
    }
}
export function compile(source: string) {
    assert(
        new TextEncoder().encode(source).length <= 16384,
        "Source exceeds 16 KiB",
    );
    const procedures = new Map<string, Procedure>();
    let main: Instruction[] | undefined;
    const parse = (text: string) => {
        const p = new Parser(text);
        const code = p.sequence();
        assert(p.i === text.length, "Extra punctuation");
        return code;
    };
    for (const raw of source.replace(/\r\n?/g, "\n").split("\n")) {
        const text = raw.replace(/\s/gu, "");
        if (!text) continue;
        assert(main === undefined, "Execution line must be last");
        if (text.includes(":")) {
            const [signature, body, extra] = text.split(":");
            const match = /^([a-z])(?:\(([A-Z](?:,[A-Z])*)\))?$/.exec(
                signature,
            );
            assert(
                match && !primitive(match[1]) && extra === undefined,
                "Invalid procedure signature",
            );
            const parameters = match[2]?.split(",") ?? [];
            assert(
                new Set(parameters).size === parameters.length &&
                    !procedures.has(match[1]),
                "Duplicate declaration",
            );
            procedures.set(match[1], { parameters, body: parse(body) });
        } else main = parse(text);
    }
    assert(main?.length, "Missing final execution line");
    const validate = (code: Instruction[], parameters: string[]) => {
        for (const instruction of code) {
            if (upper(instruction.name))
                assert(
                    parameters.includes(instruction.name),
                    "Undeclared parameter",
                );
            else if (!primitive(instruction.name)) {
                const p = procedures.get(instruction.name);
                assert(p, "Undefined procedure");
                const args = instruction.args ?? [];
                const arity =
                    args.length === 1 &&
                    "code" in args[0] &&
                    !args[0].code.length &&
                    !p.parameters.length
                        ? 0
                        : args.length;
                assert(arity === p.parameters.length, "Wrong argument count");
                for (const a of args) {
                    if ("code" in a) validate(a.code, parameters);
                    else
                        for (const t of a.terms)
                            if (typeof t.value === "string")
                                assert(
                                    parameters.includes(t.value),
                                    "Undeclared numeric parameter",
                                );
                }
            }
        }
    };
    validate(main, []);
    for (const p of procedures.values()) validate(p.body, p.parameters);
    return { procedures, main, bytes: countBytes(source) };
}
export function* commands(source: string, limit = 1000000): Generator<string> {
    const program = compile(source);
    const memoryLimit = 1000000;
    // Bound cumulative copying and validation, including tail calls that retain little memory.
    let expansionWork = 0;
    const charge = (amount: number) => {
        expansionWork += amount;
        assert(expansionWork <= 10000000, "Expansion work limit");
    };
    type Frame = {
        code: Instruction[];
        env: Map<string, Value>;
        i: number;
        footprint: number;
    };
    const frames: Frame[] = [
        {
            code: program.main,
            env: new Map(),
            i: 0,
            footprint: program.main.length,
        },
    ];
    let memory = program.main.length,
        expansions = 0;
    const discard = () => {
        while (frames.length && frames.at(-1)!.i === frames.at(-1)!.code.length)
            memory -= frames.pop()!.footprint;
    };
    const push = (code: Instruction[], env: Map<string, Value>) => {
        discard();
        if (!code.length) return;
        const footprint =
            code.length +
            [...env.values()].reduce(
                (s, v) => s + ("number" in v ? 1 : v.size),
                0,
            );
        assert(memory + footprint <= memoryLimit, "Pending memory limit");
        memory += footprint;
        frames.push({ code, env, i: 0, footprint });
        assert(frames.length <= 4096, "Call frame limit");
    };
    const numberValue = (terms: Term[], env: Map<string, Value>) => {
        let n = 0;
        for (const t of terms) {
            const value =
                typeof t.value === "number" ? t.value : env.get(t.value);
            assert(
                typeof value === "number" || (value && "number" in value),
                "Expected numeric parameter",
            );
            n += t.sign * (typeof value === "number" ? value : value.number);
            assert(Number.isSafeInteger(n), "Numeric overflow");
        }
        assert(n >= -255 && n <= 255, "Numeric result exceeds 255");
        return n;
    };
    const substitute = (
        instructions: Instruction[],
        env: Map<string, Value>,
        size: { n: number },
        depth = 0,
    ): Instruction[] => {
        assert(depth <= 128, "Expanded argument nesting limit");
        const result: Instruction[] = [];
        for (const instruction of instructions) {
            if (upper(instruction.name)) {
                const v = env.get(instruction.name);
                assert(
                    v && "code" in v,
                    "Numeric parameter used as instructions",
                );
                charge(v.size);
                size.n += v.size;
                assert(size.n <= memoryLimit, "Expanded memory limit");
                for (const item of v.code) result.push(item);
            } else if (primitive(instruction.name)) {
                charge(1);
                size.n++;
                result.push(instruction);
            } else {
                charge(1);
                size.n++;
                const args = (instruction.args ?? []).map((a): Argument => {
                    if ("terms" in a) {
                        charge(a.terms.length);
                        size.n += a.terms.length;
                        return {
                            terms: a.terms.map((t) => {
                                if (typeof t.value === "number") return t;
                                const v = env.get(t.value);
                                assert(
                                    v && "number" in v,
                                    "Expected numeric parameter",
                                );
                                return { sign: t.sign, value: v.number };
                            }),
                        };
                    }
                    if (a.code.length === 1 && upper(a.code[0].name)) {
                        const v = env.get(a.code[0].name);
                        if (v && "number" in v) {
                            charge(1);
                            size.n++;
                            return { terms: [{ sign: 1, value: v.number }] };
                        }
                    }
                    return { code: substitute(a.code, env, size, depth + 1) };
                });
                result.push({ name: instruction.name, args });
            }
            assert(size.n <= memoryLimit, "Expanded memory limit");
        }
        return result;
    };
    const resolve = (a: Argument, env: Map<string, Value>): Value => {
        if ("terms" in a) {
            charge(a.terms.length);
            return { number: numberValue(a.terms, env) };
        }
        if (a.code.length === 1 && upper(a.code[0].name)) {
            const v = env.get(a.code[0].name);
            if (v) return v;
        }
        const size = { n: 0 };
        const code = substitute(a.code, env, size);
        // Also check nesting inside already-substituted instruction values.
        const pending = [{ code, depth: 0 }];
        while (pending.length) {
            const p = pending.pop()!;
            assert(p.depth <= 128, "Expanded argument nesting limit");
            charge(p.code.length);
            for (const i of p.code)
                for (const arg of i.args ?? [])
                    if ("code" in arg)
                        pending.push({ code: arg.code, depth: p.depth + 1 });
        }
        return { code, size: size.n };
    };
    while (true) {
        discard();
        if (!frames.length) return;
        assert(++expansions <= limit, "VM expansion limit");
        const frame = frames.at(-1)!;
        const instruction = frame.code[frame.i++];
        if (primitive(instruction.name)) yield instruction.name;
        else if (upper(instruction.name)) {
            const v = frame.env.get(instruction.name);
            assert(v && "code" in v, "Numeric parameter executed");
            push(v.code, new Map());
        } else {
            const p = program.procedures.get(instruction.name)!;
            const values = p.parameters.length
                ? (instruction.args ?? []).map((a) => resolve(a, frame.env))
                : [];
            if (values.some((v) => "number" in v && v.number <= 0)) continue;
            push(
                p.body,
                new Map(p.parameters.map((name, i) => [name, values[i]])),
            );
        }
    }
}
export function evaluate(source: string, puzzle: Puzzle): Evaluation {
    const cells = puzzle.rows.join("");
    const targets = new Set(
        [...cells].flatMap((c, i) => (c === "o" ? [i] : [])),
    );
    const result: Evaluation = {
        accepted: false,
        bytes: countBytes(source),
        steps: 0,
        litTargets: 0,
        targetCount: targets.size,
        points: 0,
        feedback: "",
    };
    let position = cells.indexOf("u"),
        heading = 0;
    const lit = new Set<number>();
    try {
        assert(
            puzzle.rows.length === 25 &&
                puzzle.rows.every((r) => r.length === 25) &&
                position >= 0 &&
                targets.size > 0,
            "Invalid board",
        );
        compile(source);
        assert(
            result.bytes <= puzzle.byteLimit,
            "Program exceeds puzzle byte limit",
        );
        for (const c of commands(source)) {
            assert(result.steps < 1000000, "Robot step limit");
            result.steps++;
            if (c === "l") heading = (heading + 3) % 4;
            else if (c === "r") heading = (heading + 1) % 4;
            else {
                const x = (position % 25) + [0, 1, 0, -1][heading],
                    y = Math.floor(position / 25) + [-1, 0, 1, 0][heading];
                if (
                    x >= 0 &&
                    x < 25 &&
                    y >= 0 &&
                    y < 25 &&
                    cells[y * 25 + x] !== "x"
                ) {
                    position = y * 25 + x;
                    if (cells[position] === "*") lit.clear();
                    if (targets.has(position)) lit.add(position);
                }
            }
            if (lit.size === targets.size) {
                result.accepted = true;
                break;
            }
        }
        result.feedback = result.accepted
            ? "Accepted"
            : "Program ended before all targets were lit";
    } catch (error) {
        result.feedback =
            error instanceof Error ? error.message : "Invalid program";
    }
    result.litTargets = lit.size;
    if (result.bytes > 0 && result.bytes <= puzzle.byteLimit)
        result.points =
            Math.round(
                (lit.size / targets.size) *
                    (result.accepted
                        ? 100 - (20 * result.bytes) / puzzle.byteLimit
                        : 80) *
                    100,
            ) / 100;
    return result;
}
