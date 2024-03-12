import XCTest
@testable import BandpassFilter

final class BandpassFilterTests: XCTestCase {
    func testZeroing() throws {
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
        let result = filter.applyZeroing(
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
    
    func testAmplification() throws {
        let n = 1024 * 4
        let halfN = n / 2
        let sampleRate = n
        let frequency: Float = 2.0
        let amplitude: Float = 0.2
        let input = SignalGenerator.synthesizeSignal(
            nTimes: 1,
            sampleRate: n,
            frequencyAmplitudePairs: [
                (f: Float(7), a: Float(0.7)),
                (f: frequency, a: amplitude),
                (f: Float(50), a: Float(1.2)),
            ]
        )
        let filter = try XCTUnwrap(
            BandpassFilter(
                length: n
            )
        )
        //filter and double frequency domain components 1...4 range
        let factor = Float(2)
        let amplification = BandpassFilter.amplificationFactors(
            inboundFactor: factor,
            outboundFactor: 0,
            lowCutoff: 1,
            highCutoff: 4,
            n: n,
            halfN: halfN,
            sampleRate: sampleRate
        )
        let output = filter.apply(
            amplificationFactors: amplification,
            signal: input
        )
        
        let outputFrequencyAmplitudePairs = filter.frequencyAmplitudePairs(
            signal: output
        )
        let pair = try XCTUnwrap(outputFrequencyAmplitudePairs.first(where: {$0.frequency == Int(frequency) }))
        let distance = abs(pair.amplitude.distance(to: amplitude * factor))
        
        XCTAssertTrue(distance < 0.0001 )
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
