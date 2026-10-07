import XCTest

@testable import HerbertCore

final class HLanguageTests: XCTestCase {
    private func commands(_ source: String, maximum: Int = 100) throws -> String {
        var machine = HMachine(program: try HProgram.compile(source))
        var output = ""
        for _ in 0..<max(10_000, maximum * 2) {
            if let command = try machine.nextCommand() { output.append(command.rawValue) }
            if machine.finished || output.count >= maximum { return output }
        }
        XCTFail("VM did not yield or terminate")
        return output
    }

    func testOfficialByteCounting() throws {
        XCTAssertEqual(HProgram.countBytes("a:sa\na"), 4)
        XCTAssertEqual(HProgram.countBytes("a(X):sa(X-1)\na(12)"), 8)
        XCTAssertEqual(HProgram.countBytes("a(X,Y):Ya(X-1,Y)\na(4,s)"), 11)
        XCTAssertEqual(try HProgram.compile(" s s s s \n").byteCount, 4)
    }

    func testPrimitivesAndProcedures() throws {
        XCTAssertEqual(try commands("a:ssss\nb:srsl\nab"), "sssssrs l".replacingOccurrences(of: " ", with: ""))
        XCTAssertEqual(try commands("a:s\na()"), "s")
    }

    func testNumericRecursionAndZeroSuppression() throws {
        XCTAssertEqual(try commands("a(X):sa(X-1)\na(4)"), "ssss")
        XCTAssertEqual(try commands("a(X,Y):Ya(X-1,Y)\na(4,s)"), "ssss")
        XCTAssertEqual(try commands("a(X):s\na(0)a(-1)r"), "r")
        XCTAssertEqual(try commands("a(X,Y):s\na(1,0)r"), "r")
    }

    func testInstructionParametersCaptureCallerValues() throws {
        XCTAssertEqual(try commands("a(X):Xra(Xs)\na(l)", maximum: 14), "lrlsrlssrlsssr")
        XCTAssertEqual(try commands("a(X):Xrra(sX)\na()", maximum: 11), "rrsrrssrrss")
        XCTAssertEqual(try commands("a(X,Y):Xra(sX,Y-1)\na(s,3)"), "srssrsssr")
        XCTAssertEqual(try commands("a(X):b(X)\nb(Y):s b(Y-1)\na(3)"), "sss")
    }

    func testNestedCallsInsideInstructionArgumentsRemainLazy() throws {
        XCTAssertEqual(try commands("a(X,Y):X\nb(Z):sb(Z-1)\na(b(3),1)"), "sss")
        XCTAssertEqual(try commands("a(X):b(a(X-1))s\nb(Y):Y\na(3)"), "sss")
    }

    func testTailRecursionAndCancellableNonProductiveRecursion() throws {
        XCTAssertEqual(try commands("a:sa\na", maximum: 15_000).count, 15_000)
        var machine = HMachine(program: try HProgram.compile("a:a\na"), expansionLimit: 100)
        XCTAssertNil(try machine.nextCommand(expansionBudget: 50))
        XCTAssertThrowsError(try machine.nextCommand(expansionBudget: 60))
    }

    func testRejectsMalformedPrograms() {
        let invalid = [
            "", "u", "a:s", "ss\na:s", "s:s\ns", "a:s\na:r\na", "a(X,X):s\na(s,s)",
            "a(X):X\na", "a(X):X\na(s,s)", "a(X):X\na(256)", "a(X):X\na(1s)",
            "a(X):X\na(s", "a(X):Y\na(s)", "a(X):s\na(1*)", "a(X):s\na(1+)",
        ]
        for source in invalid { XCTAssertThrowsError(try HProgram.compile(source), source) }
    }

    func testRuntimeTypeAndMemoryErrors() throws {
        var numeric = HMachine(program: try HProgram.compile("a(X):X\na(1)"))
        XCTAssertThrowsError(try numeric.nextCommand())
        var overflow = HMachine(program: try HProgram.compile("a(X):a(X+1)\na(255)"))
        XCTAssertThrowsError(try overflow.nextCommand())
        var growth = HMachine(program: try HProgram.compile("a(X):a(XX)\na(s)"), memoryLimit: 32)
        XCTAssertThrowsError(try growth.nextCommand())
        var nested = HMachine(program: try HProgram.compile("a(X):a(a(X))\na(s)"))
        XCTAssertThrowsError(try nested.nextCommand())
        var retained = HMachine(program: try HProgram.compile("a(X):a(sX)X\na(s)"), memoryLimit: 64)
        XCTAssertThrowsError(try retained.nextCommand())
    }
}
