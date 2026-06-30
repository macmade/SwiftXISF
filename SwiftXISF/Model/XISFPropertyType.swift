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

/// The declared type of an XISF property, as carried by a `<Property>`
/// element's `type` attribute.
///
/// The raw value of each case is the exact spec type string. XISF 1.0 defines
/// scalar types (`Boolean`, the signed and unsigned integers, the floats),
/// `Complex32`/`Complex64`, `String`, `TimePoint`, the homogeneous vector and
/// matrix families, and `ByteArray`. There are deliberately no 128-bit complex
/// or 128-bit scalar types: XISF 1.0 stops at `Complex64` / `C64*`.
public enum XISFPropertyType: String, CaseIterable, Sendable
{
    /// The broad category a property type belongs to, which determines how its
    /// value is represented and parsed.
    public enum Category: Sendable
    {
        /// A boolean, integer or floating-point scalar, carried in the `value`
        /// attribute.
        case scalar

        /// A complex number, carried in the `value` attribute as `(real,imaginary)`.
        case complex

        /// A character string, carried as the element's character content.
        case string

        /// A date/time instant, carried in the `value` attribute.
        case timePoint

        /// A homogeneous vector (or `ByteArray`), carried in a data block.
        case vector

        /// A homogeneous matrix, carried in a data block.
        case matrix
    }

    /// A boolean value.
    case boolean = "Boolean"

    /// An 8-bit signed integer.
    case int8 = "Int8"

    /// An 8-bit unsigned integer.
    case uint8 = "UInt8"

    /// A 16-bit signed integer.
    case int16 = "Int16"

    /// A 16-bit unsigned integer.
    case uint16 = "UInt16"

    /// A 32-bit signed integer.
    case int32 = "Int32"

    /// A 32-bit unsigned integer.
    case uint32 = "UInt32"

    /// A 64-bit signed integer.
    case int64 = "Int64"

    /// A 64-bit unsigned integer.
    case uint64 = "UInt64"

    /// A 32-bit (single-precision) floating-point value.
    case float32 = "Float32"

    /// A 64-bit (double-precision) floating-point value.
    case float64 = "Float64"

    /// A complex number with two 32-bit floating-point components.
    case complex32 = "Complex32"

    /// A complex number with two 64-bit floating-point components.
    case complex64 = "Complex64"

    /// A character string.
    case string = "String"

    /// A date/time instant.
    case timePoint = "TimePoint"

    /// A vector of bytes (equivalent to a `UI8Vector`).
    case byteArray = "ByteArray"

    /// A vector of 8-bit signed integers.
    case i8Vector = "I8Vector"

    /// A vector of 8-bit unsigned integers.
    case ui8Vector = "UI8Vector"

    /// A vector of 16-bit signed integers.
    case i16Vector = "I16Vector"

    /// A vector of 16-bit unsigned integers.
    case ui16Vector = "UI16Vector"

    /// A vector of 32-bit signed integers.
    case i32Vector = "I32Vector"

    /// A vector of 32-bit unsigned integers.
    case ui32Vector = "UI32Vector"

    /// A vector of 64-bit signed integers.
    case i64Vector = "I64Vector"

    /// A vector of 64-bit unsigned integers.
    case ui64Vector = "UI64Vector"

    /// A vector of 32-bit floating-point values.
    case f32Vector = "F32Vector"

    /// A vector of 64-bit floating-point values.
    case f64Vector = "F64Vector"

    /// A vector of 32-bit-component complex numbers.
    case c32Vector = "C32Vector"

    /// A vector of 64-bit-component complex numbers.
    case c64Vector = "C64Vector"

    /// A matrix of 8-bit signed integers.
    case i8Matrix = "I8Matrix"

    /// A matrix of 8-bit unsigned integers.
    case ui8Matrix = "UI8Matrix"

    /// A matrix of 16-bit signed integers.
    case i16Matrix = "I16Matrix"

    /// A matrix of 16-bit unsigned integers.
    case ui16Matrix = "UI16Matrix"

    /// A matrix of 32-bit signed integers.
    case i32Matrix = "I32Matrix"

    /// A matrix of 32-bit unsigned integers.
    case ui32Matrix = "UI32Matrix"

    /// A matrix of 64-bit signed integers.
    case i64Matrix = "I64Matrix"

    /// A matrix of 64-bit unsigned integers.
    case ui64Matrix = "UI64Matrix"

    /// A matrix of 32-bit floating-point values.
    case f32Matrix = "F32Matrix"

    /// A matrix of 64-bit floating-point values.
    case f64Matrix = "F64Matrix"

    /// A matrix of 32-bit-component complex numbers.
    case c32Matrix = "C32Matrix"

    /// A matrix of 64-bit-component complex numbers.
    case c64Matrix = "C64Matrix"

    /// The category this type belongs to, determining how its value is
    /// represented and parsed.
    public var category: Category
    {
        switch self
        {
            case .boolean,
                 .int8, .uint8, .int16, .uint16, .int32, .uint32, .int64, .uint64,
                 .float32, .float64:
                return .scalar

            case .complex32, .complex64:
                return .complex

            case .string:
                return .string

            case .timePoint:
                return .timePoint

            case .byteArray,
                 .i8Vector, .ui8Vector, .i16Vector, .ui16Vector, .i32Vector, .ui32Vector,
                 .i64Vector, .ui64Vector, .f32Vector, .f64Vector, .c32Vector, .c64Vector:
                return .vector

            case .i8Matrix, .ui8Matrix, .i16Matrix, .ui16Matrix, .i32Matrix, .ui32Matrix,
                 .i64Matrix, .ui64Matrix, .f32Matrix, .f64Matrix, .c32Matrix, .c64Matrix:
                return .matrix
        }
    }
}
