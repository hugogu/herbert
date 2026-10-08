import HerbertCore
import SwiftUI

@MainActor
final class GameModel: ObservableObject {
    let problem: Problem
    let isTrial: Bool
    @Published var source: String
    @Published private(set) var session: GameSession
    @Published var message: String?
    @Published var speed: Double = 1
    @Published private(set) var lastEvent: StepEvent = .waiting
    private var task: Task<Void, Never>?
    private let store: AppStore
    private var preparedSource: String?
    private var recordedCompletion = false

    init(problem: Problem, store: AppStore, trialSource: String? = nil) throws {
        self.problem = problem
        self.store = store
        isTrial = trialSource != nil
        source = trialSource ?? store.progress(for: problem.id).draft
        session = try GameSession(problem: problem)
    }

    var bytes: Int { HProgram.countBytes(source) }
    var isRunning: Bool { session.status == .running }
    var isCompleted: Bool { session.status == .completed }

    func edited() {
        pause()
        preparedSource = nil
        recordedCompletion = false
        if let reset = try? GameSession(problem: problem) { session = reset }
        message = nil
        if !isTrial { store.setDraft(source, for: problem.id) }
    }

    private func prepareIfNeeded() -> Bool {
        if preparedSource == source, session.status == .paused { return true }
        do {
            try session.prepare(source: source)
            preparedSource = source
            recordedCompletion = false
            message = nil
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func toggleRun() {
        if isRunning {
            pause()
            return
        }
        guard prepareIfNeeded() else { return }
        session.setRunning(true)
        task = Task { [weak self] in
            while let self, !Task.isCancelled, self.isRunning {
                self.advance(batch: self.speed >= 64 ? 256 : self.speed >= 16 ? 4 : 1)
                if !self.isRunning { break }
                try? await Task.sleep(for: .milliseconds(Int(max(16, 180 / self.speed))))
            }
        }
    }

    func step() {
        pause()
        guard prepareIfNeeded() else { return }
        advance(batch: 1)
    }

    private func advance(batch: Int) {
        var next = session
        var event: StepEvent = .waiting
        for _ in 0..<batch {
            event = next.step()
            if next.status != .running && next.status != .paused { break }
        }
        session = next
        lastEvent = event
        if case .failed(let error) = session.status {
            message = error
            task?.cancel()
        }
        if isCompleted, !recordedCompletion {
            recordedCompletion = true
            if !isTrial {
                store.complete(problem, source: source, bytes: session.programBytes)
                store.flush()
            }
            task?.cancel()
        }
    }

    func pause() {
        task?.cancel()
        task = nil
        session.setRunning(false)
    }

    func reset() {
        pause()
        if let reset = try? GameSession(problem: problem) { session = reset }
        preparedSource = nil
        recordedCompletion = false
        message = nil
        lastEvent = .waiting
    }

    func disappear() {
        pause()
        store.flush()
    }
}
