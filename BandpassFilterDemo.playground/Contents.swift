import Foundation
import Accelerate
import BandpassFilter

// see https://developer.apple.com/documentation/accelerate/reducing_spectral_leakage_with_windowing
func synthesizeSignal(
    frequencyAmplitudePairs: [(f: Float, a: Float)],
    count: Int
) -> [Float] {
    let tau: Float = .pi * 2
    let signal: [Float] = (0 ..< count).map { index in
        frequencyAmplitudePairs.reduce(0) { accumulator, frequenciesAmplitudePair in
            let normalizedIndex = Float(index) / Float(count)
            return accumulator + sin(normalizedIndex * frequenciesAmplitudePair.f * tau) * frequenciesAmplitudePair.a
        }
    }
    
    return signal
}

func synthesizeSignal(
    nTimes: Int,
    sampleRate: Int,
    frequencyAmplitudePairs: [(f: Float, a: Float)]
) -> [Float] {
    (1...nTimes).map{ _ in
        synthesizeSignal(
            frequencyAmplitudePairs: frequencyAmplitudePairs,
            count: sampleRate
        )
    }
    .flatMap({$0})
}

func testFilter(
    signal: [Float],
    sampleRate: Int,
    lowCutoff: Float,
    highCutoff: Float
) -> [Float] {
    let length = vDSP_Length(signal.count)
    // The power of two of two times the length of the input.
    // Do not forget this factor 2.
    let log2n = vDSP_Length(ceil(log2(Float(length))))
    let filter = BandpassFilter(log2n: log2n)!
    return filter.filter(
        signal: signal,
        sampleRate: sampleRate,
        lowCutoff: lowCutoff,
        highCutoff: highCutoff
    )
}

let sevenHz = synthesizeSignal(
    nTimes: 4,
    sampleRate: 256,
    frequencyAmplitudePairs: [
        (f: Float(7), a: Float(0.7)),
        (f: Float(1), a: Float(0.7)),
        (f: Float(100), a: Float(0.7)),
    ]
)
sevenHz.map{$0}
testFilter(signal: sevenHz,
           sampleRate: 256,
           lowCutoff: 5,
           highCutoff: 8)
.map{$0}

func makeSquaredSignal(sampleRate: Int, nTimes: Int) -> [Float] {
    let baseFrequency: Float = 5
    let frequencyAmplitudePairs = stride(from: 1, to: 50, by: 2).map { i in
        (f: baseFrequency * Float(i), a: (1 / Float(i)))
    }
    
    return synthesizeSignal(
        nTimes: nTimes,
        sampleRate: sampleRate,
        frequencyAmplitudePairs: frequencyAmplitudePairs
    )
}

let squaredSignal = makeSquaredSignal(
    sampleRate: 1024,
    nTimes: 4
)
squaredSignal.map({$0})

let squaredSignalFiltered = testFilter(
    signal: squaredSignal,
    sampleRate: 1024,
    lowCutoff: 4,
    highCutoff: 6
)
squaredSignalFiltered
    .map{$0}

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
    return synthesizeSignal(
        nTimes: nTimes,
        sampleRate: sampleRate,
        frequencyAmplitudePairs: frequencyAmplitudePairs
    )
}
let complexSignal = makeComplexSignal()
complexSignal.map{$0}

let resultComplexSignal = testFilter(
    signal: complexSignal,
    sampleRate: 256,
    lowCutoff: 1,
    highCutoff: 4
)
resultComplexSignal.map{$0}
 

/// Returns an array that contains a composite sine wave from the
/// specified frequency-amplitude pairs.
func makeCompositeSineWave(
    from frequencyAmplitudePairs: [(f: Float, a: Float)],
    count: Int
) -> [Float] {
    [Float](unsafeUninitializedCapacity: count) {
        buffer, initializedCount in
        
        /// Fill the buffer with zeros.
        vDSP.fill(&buffer, with: 0)
        /// Create a reusable array to store the sine wave for each iteration.
        var iterationValues = [Float](repeating: 0, count: count)
        
        for frequencyAmplitudePair in frequencyAmplitudePairs {
            /// Fill the working array with a ramp in the range `0 ..< frequency`.
            vDSP.formRamp(withInitialValue: 0,
                          increment: frequencyAmplitudePair.f / Float(count / 2),
                          result: &iterationValues)
            /// Compute `sin(x * .pi)` for each element.
            vForce.sinPi(iterationValues, result: &iterationValues)
            if frequencyAmplitudePair.a != 1 {
                /// Mulitply each element by the specified amplitude.
                vDSP.multiply(frequencyAmplitudePair.a, iterationValues,
                              result: &iterationValues)
            }
            /// Add this sine wave iteration to the composite sine wave accumulator.
            vDSP.add(iterationValues, buffer, result: &buffer)
        }
        
        initializedCount = count
    }
}

let compositeSignal = {
    let sampleRate = 256
    let signal0 = makeCompositeSineWave(from: [(f: 1, a: 1),
                                               (f: 5, a: 0.2)],
                                        count: sampleRate)
    
    let signal1 = makeCompositeSineWave(from: [(f: 5, a: 1),
                                               (f: 7, a: 0.3)],
                                        count: sampleRate)
    
    let signal2 = makeCompositeSineWave(from: [(f: 3, a: 1),
                                               (f: 9, a: 0.6)],
                                        count: sampleRate)
    
    let signal3 = makeCompositeSineWave(from: [(f: 7, a: 1)],
                                        count: sampleRate)
    
    return signal0 + signal1 + signal2 + signal3
}()

compositeSignal
    .map{$0}

testFilter(
    signal: compositeSignal,
    sampleRate: 256,
    lowCutoff: 8,
    highCutoff: 10
)
.map{$0}



extension Array where Element == Float {
    func isNear(to other: [Float], distance: Float = 0.001) -> Bool {
        enumerated()
            .map { (index, element) in
                abs(element.distance(to: other[index])) < distance
            }
            .allSatisfy({$0 == true})
    }
}
resultComplexSignal.isNear(to: sevenHz)
