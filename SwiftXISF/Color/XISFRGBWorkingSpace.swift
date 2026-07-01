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

/// A parsed XISF `<RGBWorkingSpace>` element: the parameters of a
/// colorimetrically-defined RGB working color space (RGBWS).
///
/// All parameters are relative to the standard D50 reference white. When no
/// `RGBWorkingSpace` element is associated with an image, the default working
/// space is sRGB.
public struct XISFRGBWorkingSpace: Equatable, Sendable, CustomStringConvertible
{
    /// A parameter value for each of the three RGB primaries.
    public struct Primaries: Equatable, Sendable, CustomStringConvertible
    {
        /// The value for the red primary.
        public let red: Double

        /// The value for the green primary.
        public let green: Double

        /// The value for the blue primary.
        public let blue: Double

        /// Creates a set of per-primary values.
        ///
        /// - Parameters:
        ///   - red: The value for the red primary.
        ///   - green: The value for the green primary.
        ///   - blue: The value for the blue primary.
        public init( red: Double, green: Double, blue: Double )
        {
            self.red   = red
            self.green = green
            self.blue  = blue
        }

        /// A single-line, human-readable summary of the per-primary values.
        public var description: String
        {
            "( red: \( self.red ), green: \( self.green ), blue: \( self.blue ) )"
        }
    }

    /// The gamma of an RGB working space: either a fixed exponent or the sRGB
    /// gamma function.
    public enum Gamma: Equatable, Sendable, CustomStringConvertible
    {
        /// A fixed gamma exponent (greater than zero).
        case exponent( Double )

        /// The sRGB gamma function (rather than a fixed exponent).
        case sRGB

        /// A single-line, human-readable summary of the gamma.
        public var description: String
        {
            switch self
            {
                case .exponent( let value ): return "exponent(\( value ))"
                case .sRGB:                  return "sRGB"
            }
        }
    }

    /// The gamma exponent, or the sRGB gamma function.
    public let gamma: Gamma

    /// The chromaticity `x` coordinates of the red, green and blue primaries.
    public let x: Primaries

    /// The chromaticity `y` coordinates of the red, green and blue primaries.
    public let y: Primaries

    /// The luminance coefficients (`Y`) of the red, green and blue primaries.
    public let luminance: Primaries

    /// The optional, human-readable name identifying the working space.
    public let name: String?

    /// Parses an `<RGBWorkingSpace>` element.
    ///
    /// - Parameters:
    ///   - element: The `<RGBWorkingSpace>` element.
    ///   - options: The parsing options to apply. Under strict parsing a numeric
    ///     `gamma` must be greater than zero;
    ///     ``XISFParsingOptions/allowSpecDeviations`` relaxes that check.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if a mandatory attribute
    ///   is missing or malformed, or a strict validation check fails.
    internal init( element: XISFElement, options: XISFParsingOptions ) throws
    {
        let lenient = options.contains( .allowSpecDeviations )

        self.x         = try XISFRGBWorkingSpace.primaries( element, "x" )
        self.y         = try XISFRGBWorkingSpace.primaries( element, "y" )
        self.luminance = try XISFRGBWorkingSpace.primaries( element, "Y" )
        self.gamma     = try XISFRGBWorkingSpace.parseGamma( element, lenient: lenient )
        self.name      = element.attributes[ "name" ]
    }

    /// Parses a `red:green:blue` triplet attribute into ``Primaries``.
    ///
    /// - Parameters:
    ///   - element: The `<RGBWorkingSpace>` element.
    ///   - name: The attribute name (`x`, `y` or `Y`).
    /// - Returns: The parsed per-primary values.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the attribute is
    ///   missing or is not three colon-separated real numbers.
    private static func primaries( _ element: XISFElement, _ name: String ) throws -> Primaries
    {
        guard let raw = element.attributes[ name ]
        else
        {
            throw XISFError.invalidElement( reason: "RGBWorkingSpace is missing the '\( name )' attribute" )
        }

        let parts = raw.split( separator: ":", omittingEmptySubsequences: false )

        guard parts.count == 3, let red = Double( parts[ 0 ] ), let green = Double( parts[ 1 ] ), let blue = Double( parts[ 2 ] )
        else
        {
            throw XISFError.invalidElement( reason: "RGBWorkingSpace '\( name )' is not three colon-separated numbers: '\( raw )'" )
        }

        return Primaries( red: red, green: green, blue: blue )
    }

    /// Parses the `gamma` attribute.
    ///
    /// - Parameters:
    ///   - element: The `<RGBWorkingSpace>` element.
    ///   - lenient: Whether the greater-than-zero constraint on a numeric gamma
    ///     is relaxed.
    /// - Returns: The parsed gamma.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the attribute is
    ///   missing, is neither `sRGB` nor a number, or (when not lenient) is a
    ///   number that is not greater than zero.
    private static func parseGamma( _ element: XISFElement, lenient: Bool ) throws -> Gamma
    {
        guard let raw = element.attributes[ "gamma" ]
        else
        {
            throw XISFError.invalidElement( reason: "RGBWorkingSpace is missing the 'gamma' attribute" )
        }

        if raw.lowercased() == "srgb"
        {
            return .sRGB
        }

        guard let value = Double( raw )
        else
        {
            throw XISFError.invalidElement( reason: "RGBWorkingSpace 'gamma' is neither 'sRGB' nor a number: '\( raw )'" )
        }

        if value <= 0, lenient == false
        {
            throw XISFError.invalidElement( reason: "RGBWorkingSpace 'gamma' exponent must be greater than zero, found \( value )" )
        }

        return .exponent( value )
    }

    /// A single-line, human-readable summary of the working space.
    public var description: String
    {
        "XISFRGBWorkingSpace { gamma: \( self.gamma ), x: \( self.x ), y: \( self.y ), luminance: \( self.luminance ), name: \( self.name ?? "<nil>" ) }"
    }
}
