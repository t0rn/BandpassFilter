// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Accelerate

public final class BandpassFilter {
    let setup: vDSP.FFT<DSPSplitComplex>
    
    public init(setup: vDSP.FFT<DSPSplitComplex>) {
        self.setup = setup
    }
    
    public convenience init?(log2n: vDSP_Length) {
        let setup = vDSP.FFT(log2n: log2n,
                             radix: .radix2,
                             ofType: DSPSplitComplex.self)
        guard let setup else { return nil }
        self.init(setup: setup)
    }
    
    public convenience init?(length: Int) {
        let length = vDSP_Length(length)
        let log2n = vDSP_Length(ceil(log2(Float(length))))
        self.init(log2n: log2n)
    }
    
    public func applyZeroing(
        signal: [Float],
        sampleRate: Int,
        lowCutoff: Float,
        highCutoff: Float
    ) -> [Float] {
        let n = signal.count
        let amplificationFactors = Self.zeroingFrequenciesFilter(
            signalLength: n,
            lowCutoff: lowCutoff,
            highCutoff: highCutoff,
            sampleRate: sampleRate
        )
        return apply(
            amplificationFactors: amplificationFactors,
            signal: signal
        )
    }
    
    public func apply(
        ///Half N sized array of values to multiply for frequency domain of input signal
        amplificationFactors: [Float],
        signal: [Float]
    ) -> [Float] {
        let n = signal.count
        let halfN = n / 2
        var (forwardOutputReal, forwardOutputImag) = forwardFFT(
            signal: signal
        )

        for i in 0..<halfN {
            let factor = amplificationFactors[i]
            forwardOutputReal[i] = forwardOutputReal[i] * factor
            forwardOutputImag[i] = forwardOutputImag[i] * factor
        }
        
        //recreate signal after filtering
        let recreated = inverseFFT(
            n: n,
            forwardOutputReal: &forwardOutputReal,
            forwardOutputImag: &forwardOutputImag
        )
        return recreated
    }
    
    public func forwardFFT(
        signal: [Float]
    ) -> (realPart: [Float], imagPart: [Float]) {
        let n = signal.count
        let halfN = n / 2
        
        var forwardInputReal = [Float](
            repeating: 0,
            count: halfN
        )
        var forwardInputImag = [Float](
            repeating: 0,
            count: halfN
        )
        var forwardOutputReal = [Float](
            repeating: 0,
            count: halfN
        )
        var forwardOutputImag = [Float](
            repeating: 0,
            count: halfN
        )
                
        forwardInputReal.withUnsafeMutableBufferPointer { forwardInputRealPtr in
            forwardInputImag.withUnsafeMutableBufferPointer { forwardInputImagPtr in
                forwardOutputReal.withUnsafeMutableBufferPointer { forwardOutputRealPtr in
                    forwardOutputImag.withUnsafeMutableBufferPointer { forwardOutputImagPtr in
                        
                        // Create a `DSPSplitComplex` to contain the signal.
                        var forwardInput = DSPSplitComplex(realp: forwardInputRealPtr.baseAddress!,
                                                           imagp: forwardInputImagPtr.baseAddress!)
                        
                        // Convert the real values in `signal` to complex numbers.
                        signal.withUnsafeBytes {
                            vDSP.convert(interleavedComplexVector: [DSPComplex]($0.bindMemory(to: DSPComplex.self)),
                                         toSplitComplexVector: &forwardInput)
                        }
                        
                        // Create a `DSPSplitComplex` to receive the FFT result.
                        var forwardOutput = DSPSplitComplex(realp: forwardOutputRealPtr.baseAddress!,
                                                            imagp: forwardOutputImagPtr.baseAddress!)
                        
                        // Perform the forward FFT.
                        setup.forward(input: forwardInput,
                                      output: &forwardOutput)
                    }
                }
            }
        }
        return (realPart: forwardOutputReal, 
                imagPart: forwardOutputImag)
    }
    
    //https://developer.apple.com/documentation/accelerate/finding_the_component_frequencies_in_a_composite_sine_wave#3403296
    public func inverseFFT(
        n: Int,
        forwardOutputReal: inout [Float],
        forwardOutputImag: inout [Float]
    ) -> [Float] {
        let halfN = n / 2
        var inverseOutputReal = [Float](repeating: 0,
                                        count: halfN)
        var inverseOutputImag = [Float](repeating: 0,
                                        count: halfN)
        
        let recreatedSignal: [Float] = forwardOutputReal.withUnsafeMutableBufferPointer { forwardOutputRealPtr in
            forwardOutputImag.withUnsafeMutableBufferPointer { forwardOutputImagPtr in
                inverseOutputReal.withUnsafeMutableBufferPointer { inverseOutputRealPtr in
                    inverseOutputImag.withUnsafeMutableBufferPointer { inverseOutputImagPtr in
                        
                        // Create a `DSPSplitComplex` that contains the frequency-domain data.
                        let forwardOutput = DSPSplitComplex(realp: forwardOutputRealPtr.baseAddress!,
                                                            imagp: forwardOutputImagPtr.baseAddress!)
                        
                        // Create a `DSPSplitComplex` structure to receive the FFT result.
                        var inverseOutput = DSPSplitComplex(realp: inverseOutputRealPtr.baseAddress!,
                                                            imagp: inverseOutputImagPtr.baseAddress!)
                        
                        // Perform the inverse FFT.
                        setup.inverse(input: forwardOutput,
                                      output: &inverseOutput)
                        
                        // Return an array of real values from the FFT result.
                        let scale = 1 / Float(n * 2)
                        return [Float](fromSplitComplex: inverseOutput,
                                       scale: scale,
                                       count: Int(n))
                    }
                }
            }
        }
        
        return recreatedSignal
    }
    
    public func frequencyAmplitudePairs(
        signal: [Float]
    ) -> [(frequency: Int, amplitude: Float)] {
        let n = signal.count
        let halfN = n / 2
        
        var (realPart, imagPart) = forwardFFT(
            signal: signal
        )
        let spectrum = autoSpectrum(
            forwardOutputReal: &realPart,
            forwardOutputImag: &imagPart,
            halfN: halfN
        )
        let frequencyAmplitudePairs = frequencyAmplitudePairs(
            autospectrum: spectrum,
            n: n
        )
        return frequencyAmplitudePairs
    }
    
    ///The autospectrum is the sum of squares of the complex and real parts of each complex frequency-domain element.
    public func autoSpectrum(
        forwardOutputReal: inout [Float],
        forwardOutputImag: inout [Float],
        halfN: Int
    ) -> [Float] {
        [Float](unsafeUninitializedCapacity: halfN) {
            autospectrumBuffer, initializedCount in
            // The `vDSP_zaspec` function accumulates its output. Clear the
            // uninitialized `autospectrumBuffer` before computing the spectrum.
            vDSP.clear(&autospectrumBuffer)
            
            forwardOutputReal.withUnsafeMutableBufferPointer { forwardOutputRealPtr in
                forwardOutputImag.withUnsafeMutableBufferPointer { forwardOutputImagPtr in
                    
                    var frequencyDomain = DSPSplitComplex(realp: forwardOutputRealPtr.baseAddress!,
                                                          imagp: forwardOutputImagPtr.baseAddress!)
                    
                    vDSP_zaspec(&frequencyDomain,
                                autospectrumBuffer.baseAddress!,
                                vDSP_Length(halfN))
                }
            }
            initializedCount = halfN
        }
    }
    
    public func frequencyAmplitudePairs(
        autospectrum: [Float],
        n: Int
    ) -> [(frequency: Int, amplitude: Float)] {
        autospectrum
            .enumerated()
            .filter {
                $0.element > 1
            }.map { (offset, element) in
                return (frequency: offset, amplitude: sqrt(element) / Float(n))
            }
    }
}


extension BandpassFilter {
    public class func amplificationFactors(
        inboundFactor: Float,
        outboundFactor: Float,
        lowCutoff: Float,
        highCutoff: Float,
        n: Int,
        halfN: Int,
        sampleRate: Int
    ) -> [Float] {
        var result = [Float](
            repeating: 0,
            count: halfN
        )
        for i in 0..<halfN {
            let frequency = Float(sampleRate) / Float(n) * Float(i)
            if frequency < lowCutoff || frequency > highCutoff {
                result[i] = outboundFactor
            } else {
                result[i] = inboundFactor
            }
        }
        return result
    }
    
    public class func zeroingFrequenciesFilter(
        signalLength: Int,
        lowCutoff: Float,
        highCutoff: Float,
        sampleRate: Int
    ) -> [Float] {
        let n = signalLength
        let halfN = n / 2
        return Self.amplificationFactors(
            inboundFactor: 1,
            outboundFactor: 0,
            lowCutoff: lowCutoff,
            highCutoff: highCutoff,
            n: n,
            halfN: halfN,
            sampleRate: sampleRate
        )
    }
}
