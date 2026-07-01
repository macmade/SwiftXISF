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

/// A parsed XISF `<ColorFilterArray>` element: the color filter array (CFA),
/// such as a Bayer filter, of a mosaiced two-dimensional image.
///
/// The CFA is described by a ``pattern`` string whose characters, read from top
/// to bottom and left to right, give the color of each element of a
/// ``width`` × ``height`` matrix.
public struct XISFColorFilterArray: Equatable, Sendable, CustomStringConvertible
{
    /// A single element of a color filter array pattern.
    ///
    /// The raw value is the ASCII character used in the `pattern` attribute.
    public enum Element: Character, Equatable, Sendable, CaseIterable
    {
        /// A nonexistent or undefined CFA element.
        case none = "0"

        /// A red filter element.
        case red = "R"

        /// A green filter element.
        case green = "G"

        /// A blue filter element.
        case blue = "B"

        /// A white or panchromatic filter element.
        case white = "W"

        /// A cyan filter element.
        case cyan = "C"

        /// A magenta filter element.
        case magenta = "M"

        /// A yellow filter element.
        case yellow = "Y"
    }

    /// The raw CFA pattern string, ordered top to bottom and left to right.
    public let pattern: String

    /// The width, in pixels, of the CFA matrix (greater than zero).
    public let width: Int

    /// The height, in pixels, of the CFA matrix (greater than zero).
    public let height: Int

    /// The optional, human-readable name identifying the CFA type or model.
    public let name: String?

    /// The pattern decoded into typed elements.
    ///
    /// A character that is not a valid ``Element`` is dropped; under strict
    /// parsing every character is validated at initialization, so this then has
    /// exactly `width × height` entries.
    public var elements: [ Element ]
    {
        self.pattern.compactMap { Element( rawValue: $0 ) }
    }

    /// Parses a `<ColorFilterArray>` element.
    ///
    /// - Parameters:
    ///   - element: The `<ColorFilterArray>` element.
    ///   - options: The parsing options to apply. Under strict parsing the
    ///     `pattern` characters must all be valid, the dimensions must be
    ///     greater than zero, and the pattern length must equal `width × height`;
    ///     ``XISFParsingOptions/allowSpecDeviations`` skips those checks.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if a mandatory attribute
    ///   is missing or invalid, or a strict validation check fails.
    internal init( element: XISFElement, options: XISFParsingOptions ) throws
    {
        let lenient = options.contains( .allowSpecDeviations )

        guard let pattern = element.attributes[ "pattern" ]
        else
        {
            throw XISFError.invalidElement( reason: "ColorFilterArray is missing a 'pattern' attribute" )
        }

        let width  = try XISFColorFilterArray.dimension( element, "width",  lenient: lenient )
        let height = try XISFColorFilterArray.dimension( element, "height", lenient: lenient )

        if lenient == false
        {
            if let invalid = pattern.first( where: { Element( rawValue: $0 ) == nil } )
            {
                throw XISFError.invalidElement( reason: "ColorFilterArray pattern contains an invalid character: '\( invalid )'" )
            }

            if pattern.count != width * height
            {
                throw XISFError.invalidElement( reason: "ColorFilterArray pattern length (\( pattern.count )) does not match width × height (\( width * height ))" )
            }
        }

        self.pattern = pattern
        self.width   = width
        self.height  = height
        self.name    = element.attributes[ "name" ]
    }

    /// Parses a mandatory CFA dimension attribute.
    ///
    /// - Parameters:
    ///   - element: The `<ColorFilterArray>` element.
    ///   - name: The attribute name (`width` or `height`).
    ///   - lenient: Whether the greater-than-zero constraint is relaxed.
    /// - Returns: The parsed dimension.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the attribute is
    ///   missing, not an integer, or (when not lenient) not greater than zero.
    private static func dimension( _ element: XISFElement, _ name: String, lenient: Bool ) throws -> Int
    {
        guard let raw = element.attributes[ name ], let value = Int( raw )
        else
        {
            throw XISFError.invalidElement( reason: "ColorFilterArray has a missing or invalid '\( name )' attribute: '\( element.attributes[ name ] ?? "" )'" )
        }

        if value <= 0, lenient == false
        {
            throw XISFError.invalidElement( reason: "ColorFilterArray '\( name )' must be greater than zero, found \( value )" )
        }

        return value
    }

    /// A single-line, human-readable summary of the color filter array.
    public var description: String
    {
        "XISFColorFilterArray { pattern: \( self.pattern ), width: \( self.width ), height: \( self.height ), name: \( self.name ?? "<nil>" ) }"
    }
}
