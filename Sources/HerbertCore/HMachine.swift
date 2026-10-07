import Foundation

private enum HValue {
    case code([HInstruction], size: Int)
    case number(Int)

    var size: Int {
        switch self {
        case .code(_, let size): size
        case .number: 1
        }
    }
}

private struct ExecutionFrame {
    let instructions: [HInstruction]
    let environment: [Character: HValue]
    var index: Int = 0
    var footprint: Int { instructions.count + environment.values.reduce(0) { $0 + $1.size } }
}

/// Resumable VM: one call yields at most one robot instruction. Expansions are
/// also bounded per tick so even a recursion with no movement stays cancellable.
public struct HMachine {
    private let program: HProgram
    private var frames: [ExecutionFrame]
    private var expansionCount = 0
    private var pendingMemory: Int
    public private(set) var finished = false
    public let memoryLimit: Int
    public let expansionLimit: Int

    public init(program: HProgram, memoryLimit: Int = 1_000_000, expansionLimit: Int = 1_000_000) {
        self.program = program
        self.memoryLimit = memoryLimit
        self.expansionLimit = expansionLimit
        frames = [ExecutionFrame(instructions: program.main, environment: [:])]
        pendingMemory = program.main.count
    }

    public mutating func nextCommand(expansionBudget: Int = 512) throws -> HCommand? {
        guard !finished else { return nil }
        for _ in 0..<expansionBudget {
            discardExhaustedFrames()
            guard !frames.isEmpty else {
                finished = true
                return nil
            }
            expansionCount += 1
            guard expansionCount <= expansionLimit else { throw HError(HerbertStrings.text("展开次数达到 100 万次，请调整递归。")) }
            let frameIndex = frames.count - 1
            let frame = frames[frameIndex]
            let instruction = frame.instructions[frame.index]
            frames[frameIndex].index += 1
            switch instruction {
            case .command(let command): return command
            case .parameter(let name):
                guard case .code(let code, _) = frame.environment[name] else {
                    throw HError(HerbertStrings.text("数值参数 %@ 不能直接作为指令执行。", String(name)))
                }
                try push(code, environment: [:])
            case .call(let name, var arguments):
                guard let procedure = program.procedures[name] else {
                    throw HError(HerbertStrings.text("过程 %@ 未定义。", String(name)))
                }
                if procedure.parameters.isEmpty { arguments = [] }
                let values = try arguments.map { try resolve($0, environment: frame.environment) }
                if values.contains(where: {
                    if case .number(let n) = $0 { return n <= 0 }
                    return false
                }) {
                    continue
                }
                let environment = Dictionary(uniqueKeysWithValues: zip(procedure.parameters, values))
                try push(procedure.body, environment: environment)
            }
            guard frames.count <= 4096 else { throw HError(HerbertStrings.text("递归栈过深，请使用尾递归或缩短程序。")) }
        }
        return nil
    }

    private mutating func discardExhaustedFrames() {
        while let last = frames.last, last.index == last.instructions.count {
            pendingMemory -= last.footprint
            frames.removeLast()
        }
    }

    private mutating func push(_ instructions: [HInstruction], environment: [Character: HValue]) throws {
        // Remove exhausted callers before pushing, keeping tail recursion constant-space.
        discardExhaustedFrames()
        if !instructions.isEmpty {
            let frame = ExecutionFrame(instructions: instructions, environment: environment)
            guard pendingMemory + frame.footprint <= memoryLimit else {
                throw HError(HerbertStrings.text("待执行程序超过内存展开上限。"))
            }
            pendingMemory += frame.footprint
            frames.append(frame)
        }
    }

    private func resolve(_ argument: HArgument, environment: [Character: HValue]) throws -> HValue {
        switch argument {
        case .number(let terms):
            var sum = 0
            for term in terms {
                let number: Int
                switch term.value {
                case .constant(let value): number = value
                case .parameter(let name):
                    guard case .number(let value) = environment[name] else {
                        throw HError(HerbertStrings.text("参数 %@ 不是数值。", String(name)))
                    }
                    number = value
                }
                let (result, overflow) = sum.addingReportingOverflow(term.sign * number)
                guard !overflow else { throw HError(HerbertStrings.text("数值的绝对值不能超过 255。")) }
                sum = result
            }
            guard (-255...255).contains(sum) else { throw HError(HerbertStrings.text("数值的绝对值不能超过 255。")) }
            return .number(sum)
        case .code(let instructions):
            if instructions.count == 1, case .parameter(let name) = instructions[0], let value = environment[name] {
                return value
            }
            var size = 0
            let result = try substitute(instructions, environment: environment, size: &size)
            try validateNesting(result)
            return .code(result, size: size)
        }
    }

    private func substitute(_ instructions: [HInstruction], environment: [Character: HValue], size: inout Int) throws
        -> [HInstruction]
    {
        var result: [HInstruction] = []
        for instruction in instructions {
            switch instruction {
            case .command:
                size += 1
                result.append(instruction)
            case .parameter(let name):
                guard case .code(let code, let weight) = environment[name] else {
                    throw HError(HerbertStrings.text("数值参数 %@ 不能拼接为命令。", String(name)))
                }
                size += weight
                guard size <= memoryLimit else { throw HError(HerbertStrings.text("命令展开超过 100 万 byte。")) }
                result.append(contentsOf: code)
            case .call(let name, let arguments):
                size += 1
                let substituted = try arguments.map { argument -> HArgument in
                    switch argument {
                    case .number(let terms):
                        size += terms.count
                        return .number(
                            try terms.map { term in
                                if case .parameter(let p) = term.value {
                                    guard case .number(let n) = environment[p] else {
                                        throw HError(HerbertStrings.text("参数 %@ 不是数值。", String(p)))
                                    }
                                    return NumericTerm(sign: term.sign, value: .constant(n))
                                }
                                return term
                            })
                    case .code(let code):
                        if code.count == 1, case .parameter(let p) = code[0], case .number(let n) = environment[p] {
                            size += 1
                            return .number([NumericTerm(sign: 1, value: .constant(n))])
                        }
                        return .code(try substitute(code, environment: environment, size: &size))
                    }
                }
                result.append(.call(name, substituted))
            }
            guard size <= memoryLimit else { throw HError(HerbertStrings.text("命令展开超过 100 万 byte。")) }
        }
        return result
    }

    private func validateNesting(_ instructions: [HInstruction]) throws {
        var pending: [([HInstruction], Int)] = [(instructions, 0)]
        while let (sequence, depth) = pending.popLast() {
            guard depth <= 128 else { throw HError(HerbertStrings.text("展开后的命令参数嵌套超过 128 层。")) }
            for instruction in sequence {
                if case .call(_, let arguments) = instruction {
                    for argument in arguments {
                        if case .code(let code) = argument { pending.append((code, depth + 1)) }
                    }
                }
            }
        }
    }
}
