//
//  SignalGenerator.swift
//
//
//  Created by Alexey Ivanov on 10/3/24.
//

import Foundation

struct SignalGenerator {
    static func synthesizeSignal(
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

    static func synthesizeSignal(
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
    static func makeComplexSignal(
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
}
