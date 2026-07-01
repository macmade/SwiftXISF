/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Foundation

/// The pixel sample format of an XISF image, from its `sampleFormat` attribute.
///
/// The raw value of each case is the exact spec string. XISF 1.0 defines eight
/// formats: the unsigned integers, the two floating-point formats, and the two
/// complex formats.
public enum XISFSampleFormat: String, Equatable, Sendable, CaseIterable
{
    /// 8-bit unsigned integer samples.
    case uInt8 = "UInt8"

    /// 16-bit unsigned integer samples.
    case uInt16 = "UInt16"

    /// 32-bit unsigned integer samples.
    case uInt32 = "UInt32"

    /// 64-bit unsigned integer samples.
    case uInt64 = "UInt64"

    /// 32-bit (single-precision) floating-point samples.
    case float32 = "Float32"

    /// 64-bit (double-precision) floating-point samples.
    case float64 = "Float64"

    /// Complex samples with two 32-bit floating-point components.
    case complex32 = "Complex32"

    /// Complex samples with two 64-bit floating-point components.
    case complex64 = "Complex64"

    /// The size, in bytes, of a single sample in this format.
    ///
    /// A complex sample is two floating-point components, so `Complex32` is
    /// 8 bytes and `Complex64` is 16 bytes.
    public var bytesPerSample: Int
    {
        switch self
        {
            case .uInt8:     return 1
            case .uInt16:    return 2
            case .uInt32:    return 4
            case .uInt64:    return 8
            case .float32:   return 4
            case .float64:   return 8
            case .complex32: return 8
            case .complex64: return 16
        }
    }

    /// A Boolean value indicating whether the format is real floating-point
    /// (`Float32` or `Float64`).
    public var isFloatingPoint: Bool
    {
        self == .float32 || self == .float64
    }

    /// A Boolean value indicating whether the format is complex (`Complex32` or
    /// `Complex64`).
    public var isComplex: Bool
    {
        self == .complex32 || self == .complex64
    }
}
