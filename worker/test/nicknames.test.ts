import { describe, expect, it } from "vitest";
import { nicknameAllowed } from "../src/nicknames";

describe("public nickname screening", () => {
    it.each([
        "Hugo",
        "学习者 Alice",
        "ロボット先生",
        "Scunthorpe",
        "笨笨机器人",
        "Learner 1234",
    ])("allows ordinary names: %s", (name) => {
        expect(nicknameAllowed(name)).toBe(true);
    });
    it.each([
        "fuck you",
        "ｆｕｃｋ",
        "操 你 妈",
        "傻-逼",
        "死 ね",
        "kill yourself",
    ])("rejects obvious abuse: %s", (name) => {
        expect(nicknameAllowed(name)).toBe(false);
    });
});
