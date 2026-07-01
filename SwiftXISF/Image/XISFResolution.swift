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

/// A parsed XISF `<Resolution>` element: the display resolution associated with
/// an image.
///
/// Resolution defines how many pixels are represented per unit of surface on a
/// display medium, measured either in pixels per inch or per centimeter.
public struct XISFResolution: Equatable, Sendable, CustomStringConvertible
{
    /// The unit of length used to express a resolution.
    public enum Unit: String, Equatable, Sendable, CaseIterable
    {
        /// Resolution measured in pixels per inch.
        case inch = "inch"

        /// Resolution measured in pixels per centimeter.
        case centimeter = "cm"

        /// The default unit when the `unit` attribute is absent (`inch`).
        public static let defaultValue: Unit = .inch
    }

    /// The horizontal (X-axis) resolution, in pixels per ``unit``.
    public let horizontal: Double

    /// The vertical (Y-axis) resolution, in pixels per ``unit``.
    public let vertical: Double

    /// The unit the resolution values are expressed in (defaults to `inch`).
    public let unit: Unit

    /// Parses a `<Resolution>` element.
    ///
    /// - Parameters:
    ///   - element: The `<Resolution>` element.
    ///   - options: The parsing options to apply. Under strict parsing both
    ///     resolution values must be present and greater than zero and the
    ///     `unit`, if present, must be a known value;
    ///     ``XISFParsingOptions/allowSpecDeviations`` relaxes the positivity
    ///     check and falls back to the default unit for an unknown value.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if a mandatory attribute
    ///   is missing or not a number, or a strict validation check fails.
    internal init( element: XISFElement, options: XISFParsingOptions ) throws
    {
        let lenient = options.contains( .allowSpecDeviations )

        self.horizontal = try XISFResolution.value( element, "horizontal", lenient: lenient )
        self.vertical   = try XISFResolution.value( element, "vertical",   lenient: lenient )

        guard let raw = element.attributes[ "unit" ]
        else
        {
            self.unit = .defaultValue

            return
        }

        guard let unit = Unit( rawValue: raw )
        else
        {
            if lenient
            {
                self.unit = .defaultValue

                return
            }

            throw XISFError.invalidElement( reason: "Resolution has an unknown 'unit' attribute: '\( raw )'" )
        }

        self.unit = unit
    }

    /// Parses a mandatory, strictly-positive resolution value attribute.
    ///
    /// - Parameters:
    ///   - element: The `<Resolution>` element.
    ///   - name: The attribute name (`horizontal` or `vertical`).
    ///   - lenient: Whether the positivity constraint is relaxed.
    /// - Returns: The parsed resolution value.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the attribute is
    ///   missing, not a number, or (when not lenient) not greater than zero.
    private static func value( _ element: XISFElement, _ name: String, lenient: Bool ) throws -> Double
    {
        guard let raw = element.attributes[ name ], let value = Double( raw )
        else
        {
            throw XISFError.invalidElement( reason: "Resolution has a missing or invalid '\( name )' attribute: '\( element.attributes[ name ] ?? "" )'" )
        }

        if value <= 0, lenient == false
        {
            throw XISFError.invalidElement( reason: "Resolution '\( name )' must be greater than zero, found \( value )" )
        }

        return value
    }

    /// A single-line, human-readable summary of the resolution.
    public var description: String
    {
        "XISFResolution { horizontal: \( self.horizontal ), vertical: \( self.vertical ), unit: \( self.unit.rawValue ) }"
    }
}
