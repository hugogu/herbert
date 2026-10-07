import Foundation

public struct HError: Error, Equatable, LocalizedError, Sendable {
    public let message: String
    public let line: Int?

    public init(_ message: String, line: Int? = nil) {
        self.message = message
        self.line = line
    }

    public var errorDescription: String? {
        if let line { return "第 \(line) 行：\(message)" }
        return message
    }
}

public enum HCommand: Character, Sendable {
    case straight = "s"
    case left = "l"
    case right = "r"
}

struct HProcedure: Sendable {
    let parameters: [Character]
    let body: [HInstruction]
}

indirect enum HInstruction: Sendable {
    case command(HCommand)
    case parameter(Character)
    case call(Character, [HArgument])
}

indirect enum HArgument: Sendable {
    case code([HInstruction])
    case number([NumericTerm])
}

struct NumericTerm: Sendable {
    enum Value: Sendable {
        case constant(Int)
        case parameter(Character)
    }
    let sign: Int
    let value: Value
}

public struct HProgram: Sendable {
    let procedures: [Character: HProcedure]
    let main: [HInstruction]
    public let byteCount: Int

    public static func countBytes(_ source: String) -> Int {
        var count = 0
        var inNumber = false
        for character in source {
            if character.isASCIIDigit {
                if !inNumber { count += 1 }
                inNumber = true
            } else {
                if character.isASCIIAlpha { count += 1 }
                if !character.isWhitespace { inNumber = false }
            }
        }
        return count
    }

    public static func compile(_ source: String) throws -> HProgram {
        guard source.utf8.count <= 16_384 else { throw HError("代码过长，请缩短至 16 KB 以内。") }
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var procedures: [Character: HProcedure] = [:]
        var main: [HInstruction]?
        for (offset, raw) in lines.enumerated() {
            let line = offset + 1
            let text = raw.filter { !$0.isWhitespace }
            if text.isEmpty { continue }
            guard main == nil else { throw HError("执行行必须是最后一个非空行。", line: line) }
            if let colon = text.firstIndex(of: ":") {
                let signature = Array(text[..<colon])
                guard let name = signature.first, name.isASCIILower, HCommand(rawValue: name) == nil else {
                    throw HError("过程名须是 s、l、r 以外的单个小写字母。", line: line)
                }
                guard procedures[name] == nil else { throw HError("过程 \(name) 重复定义。", line: line) }
                var parameters: [Character] = []
                if signature.count > 1 {
                    guard signature.count >= 4, signature[1] == "(", signature.last == ")" else {
                        throw HError("参数声明应写成 a(X,Y):。", line: line)
                    }
                    let pieces = String(signature[2..<(signature.count - 1)]).split(
                        separator: ",", omittingEmptySubsequences: false)
                    for piece in pieces {
                        guard piece.count == 1, let p = piece.first, p.isASCIIUpper, !parameters.contains(p) else {
                            throw HError("参数须是互不重复的单个大写字母。", line: line)
                        }
                        parameters.append(p)
                    }
                }
                var parser = HParser(text: String(text[text.index(after: colon)...]), line: line)
                let body = try parser.sequence()
                guard parser.atEnd else { throw HError("过程体含有多余符号。", line: line) }
                procedures[name] = HProcedure(parameters: parameters, body: body)
            } else {
                var parser = HParser(text: text, line: line)
                main = try parser.sequence()
                guard parser.atEnd else { throw HError("执行行含有多余符号。", line: line) }
            }
        }
        guard let main, !main.isEmpty else { throw HError("在最后一行输入要执行的指令，例如 ssss。") }
        let program = HProgram(procedures: procedures, main: main, byteCount: countBytes(source))
        try program.validate(main, parameters: [])
        for procedure in procedures.values {
            try program.validate(procedure.body, parameters: Set(procedure.parameters))
        }
        return program
    }

    private func validate(_ instructions: [HInstruction], parameters: Set<Character>) throws {
        for instruction in instructions {
            switch instruction {
            case .command: break
            case .parameter(let name):
                guard parameters.contains(name) else { throw HError("参数 \(name) 未声明。") }
            case .call(let name, let arguments):
                guard let procedure = procedures[name] else { throw HError("过程 \(name) 未定义。") }
                let arity =
                    arguments.count == 1 && arguments.isSingleEmptyCode && procedure.parameters.isEmpty
                    ? 0 : arguments.count
                guard arity == procedure.parameters.count else {
                    throw HError("过程 \(name) 需要 \(procedure.parameters.count) 个参数，收到了 \(arity) 个。")
                }
                for argument in arguments {
                    switch argument {
                    case .code(let code): try validate(code, parameters: parameters)
                    case .number(let terms):
                        for term in terms {
                            if case .parameter(let p) = term.value, !parameters.contains(p) {
                                throw HError("参数 \(p) 未声明。")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct HParser {
    let characters: [Character]
    let line: Int
    var index = 0
    var depth = 0
    var atEnd: Bool { index == characters.count }
    var current: Character? { atEnd ? nil : characters[index] }

    init(text: String, line: Int) {
        characters = Array(text)
        self.line = line
    }

    mutating func sequence() throws -> [HInstruction] {
        var result: [HInstruction] = []
        while let character = current, character != ",", character != ")" {
            index += 1
            if let command = HCommand(rawValue: character) {
                result.append(.command(command))
            } else if character.isASCIIUpper {
                result.append(.parameter(character))
            } else if character.isASCIILower {
                var arguments: [HArgument] = []
                if current == "(" {
                    depth += 1
                    guard depth <= 64 else { throw HError("参数嵌套过深。", line: line) }
                    index += 1
                    while true {
                        arguments.append(try argument())
                        if current == "," {
                            index += 1
                            continue
                        }
                        guard current == ")" else { throw HError("缺少右括号 )。", line: line) }
                        index += 1
                        depth -= 1
                        break
                    }
                }
                result.append(.call(character, arguments))
            } else {
                throw HError("无法识别 \(character)，使用 s、l、r 或过程调用。", line: line)
            }
        }
        return result
    }

    mutating func argument() throws -> HArgument {
        // A lone uppercase parameter can carry either code or a number at runtime.
        let start = index
        var nesting = 0
        var numeric = false
        for character in characters[index...] {
            if nesting == 0 && (character == "," || character == ")") { break }
            if character == "(" { nesting += 1 }
            if character == ")" { nesting -= 1 }
            if nesting == 0 && (character.isASCIIDigit || character == "+" || character == "-") { numeric = true }
        }
        if !numeric { return .code(try sequence()) }
        var terms: [NumericTerm] = []
        var sign = 1
        if current == "-" || current == "+" {
            sign = current == "-" ? -1 : 1
            index += 1
        }
        while true {
            guard let character = current else { throw HError("数值表达式不完整。", line: line) }
            let value: NumericTerm.Value
            if character.isASCIIDigit {
                let numberStart = index
                while let c = current, c.isASCIIDigit { index += 1 }
                guard let number = Int(String(characters[numberStart..<index])), number <= 255 else {
                    throw HError("数值的绝对值不能超过 255。", line: line)
                }
                value = .constant(number)
            } else if character.isASCIIUpper {
                index += 1
                value = .parameter(character)
            } else {
                throw HError("数值参数只支持整数、参数以及 + 和 -。", line: line)
            }
            terms.append(NumericTerm(sign: sign, value: value))
            if current == "+" || current == "-" {
                sign = current == "-" ? -1 : 1
                index += 1
                continue
            }
            break
        }
        guard index > start, current == "," || current == ")" else {
            throw HError("数值与命令不能混写在同一个参数中。", line: line)
        }
        return .number(terms)
    }
}

extension Character {
    var isASCIIDigit: Bool { self >= "0" && self <= "9" }
    var isASCIILower: Bool { self >= "a" && self <= "z" }
    var isASCIIUpper: Bool { self >= "A" && self <= "Z" }
    var isASCIIAlpha: Bool { isASCIILower || isASCIIUpper }
}

extension Array where Element == HArgument {
    fileprivate var isSingleEmptyCode: Bool {
        if count == 1, case .code(let code) = self[0] { return code.isEmpty }
        return false
    }
}
