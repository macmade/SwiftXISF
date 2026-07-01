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

/// An XISF `<Property>`: a typed, identified piece of metadata.
///
/// A property has a hierarchical, colon-separated identifier (for example
/// `Observation:Time:Start`), a declared ``XISFPropertyType``, a typed
/// ``XISFValue``, and optional `comment` and `format` attributes. Scalar,
/// complex and time-point values are carried in the element's `value`
/// attribute; a string value is the element's character content (or, when a
/// `location` is present, a data block decoded as UTF-8). Vector, matrix and
/// `ByteArray` values are carried in a data block and exposed as opaque bytes
/// (``XISFValue/data(_:)``), with their shape in ``length`` / ``rows`` /
/// ``columns``.
public struct XISFProperty: Equatable, Sendable, CustomStringConvertible
{
    /// The property's hierarchical identifier (colon-separated components).
    public let id: String

    /// The property's declared type.
    public let type: XISFPropertyType

    /// The property's typed value.
    public let value: XISFValue

    /// The property's optional comment.
    public let comment: String?

    /// The property's optional format specifier.
    public let format: String?

    /// The element count of a vector- or `ByteArray`-typed value, or `nil` for
    /// other types.
    public let length: Int?

    /// The row count of a matrix-typed value, or `nil` for other types.
    public let rows: Int?

    /// The column count of a matrix-typed value, or `nil` for other types.
    public let columns: Int?

    /// Parses a property from a `<Property>` element.
    ///
    /// Handles the value-attribute types (scalar, complex, time point), string
    /// values (inline content or a UTF-8 data block), and the data-block-backed
    /// vector, matrix and `ByteArray` types (exposed as opaque bytes).
    ///
    /// - Parameters:
    ///   - element: The `<Property>` element.
    ///   - fileData: The complete file bytes, used to resolve an `attachment`
    ///     data block for a vector/matrix/`ByteArray`/data-block string value.
    ///   - baseURL: The directory of the XISF header file, used to resolve
    ///     `@header_dir` relative external data blocks; `nil` when the unit was
    ///     opened from raw data.
    ///   - options: The parsing options to apply. Under strict parsing the `id`
    ///     must be a valid colon-separated identifier and the dimension
    ///     attributes must be present; ``XISFParsingOptions/allowSpecDeviations``
    ///     relaxes those checks.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if a required attribute is
    ///   missing, the type is unknown, the `id` is invalid, or the value cannot
    ///   be parsed; or any error raised while resolving a data block.
    internal init( element: XISFElement, fileData: Data, baseURL: URL?, options: XISFParsingOptions ) throws
    {
        guard let id = element.attributes[ "id" ], id.isEmpty == false
        else
        {
            throw XISFError.invalidElement( reason: "Property is missing an 'id' attribute" )
        }

        let lenient = options.contains( .allowSpecDeviations )

        if lenient == false, XISFProperty.isValidIdentifier( id ) == false
        {
            throw XISFError.invalidElement( reason: "Invalid property id: '\( id )'" )
        }

        guard let typeString = element.attributes[ "type" ]
        else
        {
            throw XISFError.invalidElement( reason: "Property '\( id )' is missing a 'type' attribute" )
        }

        guard let type = XISFPropertyType( rawValue: typeString )
        else
        {
            throw XISFError.invalidElement( reason: "Property '\( id )' has unknown type '\( typeString )'" )
        }

        self.id      = id
        self.type    = type
        self.comment = element.attributes[ "comment" ]
        self.format  = element.attributes[ "format" ]

        switch type.category
        {
            case .scalar, .complex, .timePoint:
                guard let raw = element.attributes[ "value" ]
                else
                {
                    throw XISFError.invalidElement( reason: "Property '\( id )' of type \( type.rawValue ) is missing a 'value' attribute" )
                }

                self.value   = try XISFValue.value( fromAttribute: raw, type: type )
                self.length  = nil
                self.rows    = nil
                self.columns = nil

            case .string:
                self.length  = nil
                self.rows    = nil
                self.columns = nil

                if element.attributes[ "location" ] != nil
                {
                    // A String value stored in a data block is decoded as UTF-8.
                    let bytes = try XISFDataBlock( element: element, fileData: fileData, baseURL: baseURL, options: options ).data

                    guard let string = String( data: bytes, encoding: .utf8 )
                    else
                    {
                        throw XISFError.invalidElement( reason: "Property '\( id )' String data block is not valid UTF-8" )
                    }

                    self.value = .string( string )
                }
                else
                {
                    self.value = .string( element.content )
                }

            case .vector:
                self.length  = try XISFProperty.dimension( element, "length", id: id, required: lenient == false )
                self.rows    = nil
                self.columns = nil
                self.value   = .data( try XISFDataBlock( element: element, fileData: fileData, baseURL: baseURL, options: options ).data )

            case .matrix:
                self.length  = nil
                self.rows    = try XISFProperty.dimension( element, "rows", id: id, required: lenient == false )
                self.columns = try XISFProperty.dimension( element, "columns", id: id, required: lenient == false )
                self.value   = .data( try XISFDataBlock( element: element, fileData: fileData, baseURL: baseURL, options: options ).data )
        }
    }

    /// Parses a non-negative integer dimension attribute (`length`/`rows`/`columns`).
    ///
    /// - Parameters:
    ///   - element: The `<Property>` element.
    ///   - name: The attribute name to read.
    ///   - id: The property identifier, for error reporting.
    ///   - required: Whether a missing attribute is an error.
    /// - Returns: The parsed dimension, or `nil` if absent and not required.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the attribute is
    ///   required and missing, or present but not a non-negative integer.
    private static func dimension( _ element: XISFElement, _ name: String, id: String, required: Bool ) throws -> Int?
    {
        guard let raw = element.attributes[ name ]
        else
        {
            if required
            {
                throw XISFError.invalidElement( reason: "Property '\( id )' is missing the '\( name )' attribute" )
            }

            return nil
        }

        guard let value = Int( raw ), value >= 0
        else
        {
            throw XISFError.invalidElement( reason: "Property '\( id )' has an invalid '\( name )' attribute: '\( raw )'" )
        }

        return value
    }

    /// Parses the direct-child `<Property>` elements of an element.
    ///
    /// All property types are parsed, including the data-block-backed vector,
    /// matrix and `ByteArray` values. Under strict parsing a property with a
    /// missing or unknown type — or one that otherwise fails to parse — is an
    /// error; ``XISFParsingOptions/allowSpecDeviations`` skips it instead, so a
    /// single malformed property does not fail the whole unit.
    ///
    /// - Parameters:
    ///   - element: The element whose `<Property>` children to parse.
    ///   - fileData: The complete file bytes, used to resolve data-block-backed
    ///     property values.
    ///   - baseURL: The directory of the XISF header file, used to resolve
    ///     `@header_dir` relative external data blocks; `nil` when the unit was
    ///     opened from raw data.
    ///   - options: The parsing options to apply.
    /// - Returns: The parsed properties, in document order.
    /// - Throws: Any ``XISFError`` raised while parsing a property, under strict
    ///   parsing.
    internal static func parseList( from element: XISFElement, fileData: Data, baseURL: URL?, options: XISFParsingOptions ) throws -> [ XISFProperty ]
    {
        try element.children( named: "Property" ).compactMap
        {
            child in

            guard let typeString = child.attributes[ "type" ], XISFPropertyType( rawValue: typeString ) != nil
            else
            {
                if options.contains( .allowSpecDeviations )
                {
                    return nil
                }

                throw XISFError.invalidElement( reason: "Property has a missing or unknown type: '\( child.attributes[ "type" ] ?? "" )'" )
            }

            do
            {
                return try XISFProperty( element: child, fileData: fileData, baseURL: baseURL, options: options )
            }
            catch
            {
                if options.contains( .allowSpecDeviations )
                {
                    return nil
                }

                throw error
            }
        }
    }

    /// Returns whether a string is a valid XISF property identifier.
    ///
    /// A property identifier is a non-empty, colon-separated sequence of simple
    /// identifiers, each matching `[_a-zA-Z][_a-zA-Z0-9]*` (for example
    /// `Instrument:Telescope:FocalLength`).
    ///
    /// - Parameter id: The identifier to validate.
    /// - Returns: `true` if `id` is a valid property identifier.
    private static func isValidIdentifier( _ id: String ) -> Bool
    {
        let components = id.split( separator: ":", omittingEmptySubsequences: false )

        return components.isEmpty == false && components.allSatisfy { String( $0 ).isValidXISFIdentifier }
    }

    /// A single-line, human-readable summary of the property.
    public var description: String
    {
        "XISFProperty { id: \( self.id ), type: \( self.type.rawValue ), kind: \( self.value.kind ), value: \( String( describing: self.value ) ), comment: \( self.comment ?? "<nil>" ), format: \( self.format ?? "<nil>" ) }"
    }
}
