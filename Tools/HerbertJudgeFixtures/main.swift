import Foundation
import HerbertCore

// Produce differential fixtures directly from the native VM, not the Worker port.
struct Reference: Decodable {
    let id: Int
    let source: String
    let alternateSources: [String]?
}
struct Input: Codable {
    let id: Int
    let source: String
    let accepted: Bool
    let bytes: Int
    let steps: Int
    let litTargets: Int
}
let references = try JSONDecoder().decode(
    [Reference].self,
    from: Data(contentsOf: URL(fileURLWithPath: "Tests/HerbertCoreTests/Fixtures/original-solutions.json")))
let puzzles = try ProblemCatalog.bundled()
var results: [Input] = []
for reference in references {
    let problem = puzzles.first { $0.id == reference.id }!
    for source in [reference.source] + (reference.alternateSources ?? []) + ["s", "a:sa\na", "a:a\na"] {
        var session = try GameSession(problem: problem)
        do {
            try session.prepare(source: source)
            while session.status == .paused { session.step() }
        } catch {}
        results.append(
            Input(
                id: problem.id, source: source, accepted: session.isAccepted, bytes: HProgram.countBytes(source),
                steps: session.steps, litTargets: session.visitedTargets.count))
    }
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
FileHandle.standardOutput.write(try encoder.encode(results))
