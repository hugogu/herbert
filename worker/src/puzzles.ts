import type { Puzzle } from "./judge";

export const RULES_VERSION = "herbert-h-v1";

export function puzzleIdentity(puzzle: Puzzle) {
    return `${RULES_VERSION}\n${puzzle.id}\n${puzzle.byteLimit}\n${puzzle.rows.join("\n")}`;
}
