import {
    englishDataset,
    englishRecommendedTransformers,
    RegExpMatcher,
} from "obscenity";

const english = new RegExpMatcher({
    ...englishDataset.build(),
    ...englishRecommendedTransformers,
});
// A small multilingual baseline, supplemented by user reports and audited moderation.
const abusivePhrases = [
    "操你妈",
    "傻逼",
    "傻屄",
    "去死",
    "死ね",
    "くたばれ",
    "kill yourself",
];
export function nicknameAllowed(name: string): boolean {
    const normalized = name.normalize("NFKC").toLowerCase();
    const compact = normalized.replace(/[\p{White_Space}\p{P}\p{S}]/gu, "");
    return (
        !english.hasMatch(normalized) &&
        !abusivePhrases.some((phrase) =>
            compact.includes(phrase.replace(/ /g, "")),
        )
    );
}
