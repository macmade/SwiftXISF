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

/// The typed value of an XISF property.
///
/// This models the scalar value categories — boolean, signed and unsigned
/// integers, floating-point, complex, string and time-point — plus ``data(_:)``,
/// the opaque decoded bytes of a vector-, matrix- or `ByteArray`-typed value
/// carried in a data block.
///
/// Equality treats two floating-point payloads of `NaN` as equal, departing
/// from IEEE 754, so comparing or diffing headers does not report a spurious
/// change; this applies to ``float(_:)`` and to either component of
/// ``complex(real:imaginary:)``. ``hash(into:)`` is kept consistent, hashing
/// every `NaN` to one constant so equal-`NaN` values share a bucket.
public enum XISFValue: Equatable, Hashable, Sendable
{
    /// A boolean value.
    case boolean( Bool )

    /// A signed integer value (any of `Int8`…`Int64`), widened to `Int64`.
    case integer( Int64 )

    /// An unsigned integer value (any of `UInt8`…`UInt64`), widened to `UInt64`.
    case unsignedInteger( UInt64 )

    /// A floating-point value (`Float32` or `Float64`), stored as `Double`.
    case float( Double )

    /// A complex value (`Complex32` or `Complex64`), with its components stored
    /// as `Double`.
    case complex( real: Double, imaginary: Double )

    /// A character string value.
    case string( String )

    /// A date/time instant.
    case timePoint( Date )

    /// The opaque decoded bytes of a vector-, matrix- or `ByteArray`-typed value
    /// carried in a data block. The property's type and dimensions describe how
    /// to interpret them.
    case data( Data )

    /// The type discriminator of an ``XISFValue``, independent of any payload.
    public enum Kind: CustomStringConvertible, Sendable
    {
        /// The kind of ``XISFValue/boolean(_:)``.
        case boolean

        /// The kind of ``XISFValue/integer(_:)``.
        case integer

        /// The kind of ``XISFValue/unsignedInteger(_:)``.
        case unsignedInteger

        /// The kind of ``XISFValue/float(_:)``.
        case float

        /// The kind of ``XISFValue/complex(real:imaginary:)``.
        case complex

        /// The kind of ``XISFValue/string(_:)``.
        case string

        /// The kind of ``XISFValue/timePoint(_:)``.
        case timePoint

        /// The kind of ``XISFValue/data(_:)``.
        case data

        /// A human-readable name for the kind.
        public var description: String
        {
            switch self
            {
                case .boolean:         return "Boolean"
                case .integer:         return "Integer"
                case .unsignedInteger: return "Unsigned Integer"
                case .float:           return "Float"
                case .complex:         return "Complex"
                case .string:          return "String"
                case .timePoint:       return "Time Point"
                case .data:            return "Data"
            }
        }
    }

    /// The ``Kind`` discriminator matching this value's case.
    public var kind: Kind
    {
        switch self
        {
            case .boolean:         return .boolean
            case .integer:         return .integer
            case .unsignedInteger: return .unsignedInteger
            case .float:           return .float
            case .complex:         return .complex
            case .string:          return .string
            case .timePoint:       return .timePoint
            case .data:            return .data
        }
    }

    /// Returns whether two values are equal.
    ///
    /// Matching cases compare their payloads, except floating-point payloads of
    /// `NaN` are treated as equal (unlike IEEE 754), both for ``float(_:)`` and
    /// for each component of ``complex(real:imaginary:)``. Differing cases are
    /// never equal.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    /// - Returns: `true` if the two values are equal.
    public static func == ( lhs: XISFValue, rhs: XISFValue ) -> Bool
    {
        switch ( lhs, rhs )
        {
            case ( .boolean(         let a ), .boolean(         let b ) ): return a == b
            case ( .integer(         let a ), .integer(         let b ) ): return a == b
            case ( .unsignedInteger( let a ), .unsignedInteger( let b ) ): return a == b
            case ( .float(           let a ), .float(           let b ) ): return XISFValue.floatsEqual( a, b )
            case ( .string(          let a ), .string(          let b ) ): return a == b
            case ( .timePoint(       let a ), .timePoint(       let b ) ): return a == b
            case ( .data(            let a ), .data(            let b ) ): return a == b

            case ( .complex( let aReal, let aImaginary ), .complex( let bReal, let bImaginary ) ):
                return XISFValue.floatsEqual( aReal, bReal ) && XISFValue.floatsEqual( aImaginary, bImaginary )

            default: return false
        }
    }

    /// Feeds the value into a hasher consistently with ``==``.
    ///
    /// Each case mixes in a distinct discriminator before its payload. Because
    /// ``==`` treats any two `NaN` floats as equal, every `NaN` is hashed to a
    /// single fixed constant so equal-`NaN` values share a bucket.
    ///
    /// - Parameter hasher: The hasher to feed.
    public func hash( into hasher: inout Hasher )
    {
        switch self
        {
            case .boolean( let value ):         hasher.combine( 0 )
                hasher.combine( value )
            case .integer( let value ):         hasher.combine( 1 )
                hasher.combine( value )
            case .unsignedInteger( let value ): hasher.combine( 2 )
                hasher.combine( value )
            case .float( let value ):           hasher.combine( 3 )
                XISFValue.hashFloat( value, into: &hasher )
            case .complex( let real, let imaginary ): hasher.combine( 4 )
                XISFValue.hashFloat( real, into: &hasher )
                XISFValue.hashFloat( imaginary, into: &hasher )
            case .string( let value ):          hasher.combine( 5 )
                hasher.combine( value )
            case .timePoint( let value ):       hasher.combine( 6 )
                hasher.combine( value )
            case .data( let value ):            hasher.combine( 7 )
                hasher.combine( value )
        }
    }

    /// Compares two doubles, treating any two `NaN` values as equal.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    /// - Returns: `true` if the values are equal or both `NaN`.
    private static func floatsEqual( _ lhs: Double, _ rhs: Double ) -> Bool
    {
        lhs == rhs || ( lhs.isNaN && rhs.isNaN )
    }

    /// Feeds a double into a hasher, hashing every `NaN` to one constant so that
    /// equal-`NaN` values share a bucket, consistent with ``floatsEqual(_:_:)``.
    ///
    /// - Parameters:
    ///   - value: The value to hash.
    ///   - hasher: The hasher to feed.
    private static func hashFloat( _ value: Double, into hasher: inout Hasher )
    {
        if value.isNaN
        {
            hasher.combine( Double.nan.bitPattern )
        }
        else
        {
            hasher.combine( value )
        }
    }

    /// The boolean payload, or `nil` if this is not a ``boolean(_:)`` value.
    public var boolean: Bool?
    {
        if case .boolean( let value ) = self { value } else { nil }
    }

    /// The signed-integer payload, or `nil` if this is not an ``integer(_:)``
    /// value.
    public var integer: Int64?
    {
        if case .integer( let value ) = self { value } else { nil }
    }

    /// The unsigned-integer payload, or `nil` if this is not an
    /// ``unsignedInteger(_:)`` value.
    public var unsignedInteger: UInt64?
    {
        if case .unsignedInteger( let value ) = self { value } else { nil }
    }

    /// The floating-point payload, or `nil` if this is not a ``float(_:)`` value.
    public var float: Double?
    {
        if case .float( let value ) = self { value } else { nil }
    }

    /// The complex payload, or `nil` if this is not a
    /// ``complex(real:imaginary:)`` value.
    public var complex: ( real: Double, imaginary: Double )?
    {
        if case .complex( let real, let imaginary ) = self { ( real, imaginary ) } else { nil }
    }

    /// The string payload, or `nil` if this is not a ``string(_:)`` value.
    public var string: String?
    {
        if case .string( let value ) = self { value } else { nil }
    }

    /// The time-point payload, or `nil` if this is not a ``timePoint(_:)`` value.
    public var timePoint: Date?
    {
        if case .timePoint( let value ) = self { value } else { nil }
    }

    /// The opaque bytes payload, or `nil` if this is not a ``data(_:)`` value.
    public var data: Data?
    {
        if case .data( let value ) = self { value } else { nil }
    }

    /// Parses a value from a `<Property>` element's `value` attribute string,
    /// for a value-attribute type.
    ///
    /// Handles the types XISF carries in the `value` attribute: booleans,
    /// integers (range-checked against the declared width), floating-point,
    /// complex (`(real,imaginary)`), and time points (ISO 8601). String values
    /// (carried as element content) and vector/matrix values (carried in data
    /// blocks) are not value-attribute types and are rejected.
    ///
    /// - Parameters:
    ///   - string: The raw `value` attribute string. Surrounding whitespace is
    ///     ignored.
    ///   - type: The declared property type.
    /// - Returns: The parsed value.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the string is not a
    ///   valid value for `type`, or if `type` is not carried in a `value`
    ///   attribute.
    public static func value( fromAttribute string: String, type: XISFPropertyType ) throws -> XISFValue
    {
        let trimmed = string.trimmingCharacters( in: .whitespaces )

        switch type
        {
            case .boolean:   return try XISFValue.parseBoolean( trimmed )
            case .int8:      return .integer( Int64( try XISFValue.parseInteger( trimmed, as: Int8.self,   type: type ) ) )
            case .int16:     return .integer( Int64( try XISFValue.parseInteger( trimmed, as: Int16.self,  type: type ) ) )
            case .int32:     return .integer( Int64( try XISFValue.parseInteger( trimmed, as: Int32.self,  type: type ) ) )
            case .int64:     return .integer( try XISFValue.parseInteger( trimmed, as: Int64.self,  type: type ) )
            case .uint8:     return .unsignedInteger( UInt64( try XISFValue.parseInteger( trimmed, as: UInt8.self,  type: type ) ) )
            case .uint16:    return .unsignedInteger( UInt64( try XISFValue.parseInteger( trimmed, as: UInt16.self, type: type ) ) )
            case .uint32:    return .unsignedInteger( UInt64( try XISFValue.parseInteger( trimmed, as: UInt32.self, type: type ) ) )
            case .uint64:    return .unsignedInteger( try XISFValue.parseInteger( trimmed, as: UInt64.self, type: type ) )
            case .float32,
                 .float64:   return try XISFValue.parseFloat( trimmed, type: type )
            case .complex32,
                 .complex64: return try XISFValue.parseComplex( trimmed, type: type )
            case .timePoint: return try XISFValue.parseTimePoint( trimmed, type: type )

            case .string, .byteArray,
                 .i8Vector, .ui8Vector, .i16Vector, .ui16Vector, .i32Vector, .ui32Vector,
                 .i64Vector, .ui64Vector, .f32Vector, .f64Vector, .c32Vector, .c64Vector,
                 .i8Matrix, .ui8Matrix, .i16Matrix, .ui16Matrix, .i32Matrix, .ui32Matrix,
                 .i64Matrix, .ui64Matrix, .f32Matrix, .f64Matrix, .c32Matrix, .c64Matrix:
                throw XISFError.invalidElement( reason: "Type \( type.rawValue ) is not represented by a value attribute" )
        }
    }

    /// Parses a boolean value.
    ///
    /// Accepts `1`/`true` and `0`/`false`, case-insensitively for the words.
    ///
    /// - Parameter string: The trimmed value string.
    /// - Returns: The parsed boolean value.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the string is not a
    ///   recognized boolean literal.
    private static func parseBoolean( _ string: String ) throws -> XISFValue
    {
        switch string.lowercased()
        {
            case "1", "true":  return .boolean( true )
            case "0", "false": return .boolean( false )
            default:           throw XISFError.invalidElement( reason: "Invalid Boolean value: '\( string )'" )
        }
    }

    /// Parses an integer of a given fixed width.
    ///
    /// - Parameters:
    ///   - string: The trimmed value string.
    ///   - integerType: The fixed-width integer type to parse, whose range the
    ///     value must fit.
    ///   - type: The declared property type, for error reporting.
    /// - Returns: The parsed integer.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the string is not a
    ///   valid integer or does not fit the type's range.
    private static func parseInteger<T: FixedWidthInteger>( _ string: String, as integerType: T.Type, type: XISFPropertyType ) throws -> T
    {
        guard let value = T( string )
        else
        {
            throw XISFError.invalidElement( reason: "Invalid \( type.rawValue ) value: '\( string )'" )
        }

        return value
    }

    /// Parses a floating-point value.
    ///
    /// - Parameters:
    ///   - string: The trimmed value string.
    ///   - type: The declared property type, for error reporting.
    /// - Returns: The parsed floating-point value.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the string is not a
    ///   valid floating-point literal.
    private static func parseFloat( _ string: String, type: XISFPropertyType ) throws -> XISFValue
    {
        guard let value = Double( string )
        else
        {
            throw XISFError.invalidElement( reason: "Invalid \( type.rawValue ) value: '\( string )'" )
        }

        return .float( value )
    }

    /// Parses a complex value of the form `(real,imaginary)`.
    ///
    /// - Parameters:
    ///   - string: The trimmed value string.
    ///   - type: The declared property type, for error reporting.
    /// - Returns: The parsed complex value.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the string is not a
    ///   valid `(real,imaginary)` literal.
    private static func parseComplex( _ string: String, type: XISFPropertyType ) throws -> XISFValue
    {
        guard string.hasPrefix( "(" ), string.hasSuffix( ")" )
        else
        {
            throw XISFError.invalidElement( reason: "Invalid \( type.rawValue ) value: '\( string )'" )
        }

        let inner      = string.dropFirst().dropLast()
        let components = inner.split( separator: ",", maxSplits: 1, omittingEmptySubsequences: false )

        guard components.count == 2,
              let real      = Double( components[ 0 ].trimmingCharacters( in: .whitespaces ) ),
              let imaginary = Double( components[ 1 ].trimmingCharacters( in: .whitespaces ) )
        else
        {
            throw XISFError.invalidElement( reason: "Invalid \( type.rawValue ) value: '\( string )'" )
        }

        return .complex( real: real, imaginary: imaginary )
    }

    /// Parses a time-point value as an ISO 8601 date/time.
    ///
    /// The XISF specification leaves the representation of time points
    /// implementation-defined; PixInsight emits ISO 8601, so both the
    /// fractional-seconds and whole-second internet date-time forms are
    /// accepted.
    ///
    /// - Parameters:
    ///   - string: The trimmed value string.
    ///   - type: The declared property type, for error reporting.
    /// - Returns: The parsed time-point value.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the string is not a
    ///   recognized ISO 8601 date/time.
    private static func parseTimePoint( _ string: String, type: XISFPropertyType ) throws -> XISFValue
    {
        let withFractional      = ISO8601DateFormatter()
        withFractional.formatOptions = [ .withInternetDateTime, .withFractionalSeconds ]

        let withoutFractional   = ISO8601DateFormatter()
        withoutFractional.formatOptions = [ .withInternetDateTime ]

        guard let date = withFractional.date( from: string ) ?? withoutFractional.date( from: string )
        else
        {
            throw XISFError.invalidElement( reason: "Invalid \( type.rawValue ) value: '\( string )'" )
        }

        return .timePoint( date )
    }
}
