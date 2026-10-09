import Foundation

/// Provider-aware defaults are merged beneath explicit advanced JSON overrides.
public enum ReasoningDefaults {
    public static func parameters(for entrant: Entrant) -> [String: Any] {
        guard entrant.preset.parameters.automaticReasoning else { return [:] }
        let model = entrant.preset.model
        let supported = Set(model.supportedParameters ?? [])
        let effort = model.supportedReasoningEfforts?.first(where: { $0 != "none" })
        if entrant.kind == .gemini {
            let name = model.id.split(separator: "/").last.map(String.init) ?? model.id
            return name.hasPrefix("gemini-2.5-") || name.hasPrefix("gemini-3")
                ? ["reasoning_effort": "high"] : [:]
        }
        if entrant.kind == .openRouter {
            guard supported.contains("reasoning") || supported.contains("reasoning_effort") || effort != nil else {
                return [:]
            }
            return ["reasoning": ["enabled": true, "effort": effort ?? "max"]]
        }
        var parameters: [String: Any] = [:]
        if entrant.kind == .siliconFlow || supported.contains("enable_thinking") {
            parameters["enable_thinking"] = true
        }
        // SiliconFlow documents effort control for these models; other models may only expose thinking.
        let siliconFlowEffortModels: Set<String> = [
            "Pro/deepseek-ai/DeepSeek-V4", "deepseek-ai/DeepSeek-V4-Flash", "Pro/zai-org/GLM-5.2",
        ]
        let siliconFlowEffort = entrant.kind == .siliconFlow && siliconFlowEffortModels.contains(model.id)
        if siliconFlowEffort || supported.contains("reasoning_effort") || effort != nil {
            parameters["reasoning_effort"] = effort ?? (entrant.kind == .siliconFlow ? "max" : "high")
        }
        return parameters
    }

    static func applying(to body: [String: Any], entrant: Entrant) -> [String: Any] {
        var defaults = parameters(for: entrant)
        // An explicit reasoning family overrides the automatic reasoning family as a whole.
        let reasoningKeys: Set<String> = [
            "reasoning", "reasoning_effort", "enable_thinking", "thinking", "thinking_budget",
        ]
        if !reasoningKeys.isDisjoint(with: body.keys) { defaults = [:] }
        return defaults.merging(body) { _, explicit in explicit }
    }
}
