import XCTest
@testable import BandpassFilter

final class BandpassFilterTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
        
        let sampleRate = 256
        let cycles = 4
        let input = makeComplexSignal(
            sampleRate: sampleRate,
            nTimes: cycles
        )
        let filter = try XCTUnwrap(
            BandpassFilter(
                length: input.count
            )
        )
        let result = filter.filter(
            signal: input,
            sampleRate: sampleRate,
            lowCutoff: 20,
            highCutoff: 30
        )
        let twentyFourHzSignal = SignalGenerator.synthesizeSignal(
            nTimes: cycles,
            sampleRate: sampleRate,
            frequencyAmplitudePairs: [(f: 24.0, a: 0.7)]
        )
        
        XCTAssertTrue(result.isNear(to: twentyFourHzSignal, distance: 0.00001))
    }
    
    func makeComplexSignal(
        sampleRate: Int = 256,
        nTimes: Int = 4
    ) -> [Float] {
        let frequencyAmplitudePairs = [
            (f: Float(2), a: Float(0.8)),
            (f: Float(7), a: Float(1.2)),
            (f: Float(24), a: Float(0.7)),
            (f: Float(50), a: Float(1.0))
        ]
        return SignalGenerator.synthesizeSignal(
            nTimes: nTimes,
            sampleRate: sampleRate,
            frequencyAmplitudePairs: frequencyAmplitudePairs
        )
    }
}
