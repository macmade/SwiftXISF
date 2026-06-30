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
/// attribute; a string value is the element's character content. Vector and
/// matrix values, which are carried in data blocks, are completed once the
/// data-block pipeline exists.
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

    /// Parses a property from a `<Property>` element.
    ///
    /// Handles the value-attribute types (scalar, complex, time point) and the
    /// inline-string type. Vector and matrix types, whose values live in data
    /// blocks, are not handled here.
    ///
    /// - Parameters:
    ///   - element: The `<Property>` element.
    ///   - options: The parsing options to apply. Under strict parsing the `id`
    ///     must be a valid colon-separated identifier; ``XISFParsingOptions/allowSpecDeviations``
    ///     relaxes that check.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if a required attribute is
    ///   missing, the type is unknown or not value-attribute/inline-string, the
    ///   `id` is invalid, or the value cannot be parsed.
    internal init( element: XISFElement, options: XISFParsingOptions ) throws
    {
        guard let id = element.attributes[ "id" ], id.isEmpty == false
        else
        {
            throw XISFError.invalidElement( reason: "Property is missing an 'id' attribute" )
        }

        if options.contains( .allowSpecDeviations ) == false, XISFProperty.isValidIdentifier( id ) == false
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

                self.value = try XISFValue.value( fromAttribute: raw, type: type )

            case .string:
                self.value = .string( element.content )

            case .vector, .matrix:
                throw XISFError.invalidElement( reason: "Property '\( id )' of type \( type.rawValue ) is data-block-backed and not handled here" )
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
