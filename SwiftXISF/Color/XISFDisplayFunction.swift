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

/// A parsed XISF `<DisplayFunction>` element: the parameters of a display
/// function (DF) associated with an image.
///
/// A display function has five parameter vectors — midtones balance, shadows
/// clipping, highlights clipping, shadows dynamic range expansion, and
/// highlights dynamic range expansion — each carrying one value per image
/// component (red/gray, green, blue, and lightness). When no `DisplayFunction`
/// element is associated with an image, the default is the identity function.
public struct XISFDisplayFunction: Equatable, Sendable, CustomStringConvertible
{
    /// One value of a display-function parameter vector for each image
    /// component.
    public struct Components: Equatable, Sendable, CustomStringConvertible
    {
        /// The value for the red/gray component.
        public let rk: Double

        /// The value for the green component.
        public let g: Double

        /// The value for the blue component.
        public let b: Double

        /// The value for the lightness component.
        public let l: Double

        /// Creates a per-component parameter vector.
        ///
        /// - Parameters:
        ///   - rk: The value for the red/gray component.
        ///   - g: The value for the green component.
        ///   - b: The value for the blue component.
        ///   - l: The value for the lightness component.
        public init( rk: Double, g: Double, b: Double, l: Double )
        {
            self.rk = rk
            self.g  = g
            self.b  = b
            self.l  = l
        }

        /// A single-line, human-readable summary of the per-component values.
        public var description: String
        {
            "( rk: \( self.rk ), g: \( self.g ), b: \( self.b ), l: \( self.l ) )"
        }
    }

    /// The midtones balance parameters (the `m` attribute).
    public let midtonesBalance: Components

    /// The shadows clipping-point parameters (the `s` attribute).
    public let shadowsClipping: Components

    /// The highlights clipping-point parameters (the `h` attribute).
    public let highlightsClipping: Components

    /// The shadows dynamic-range expansion parameters (the `l` attribute).
    public let shadowsExpansion: Components

    /// The highlights dynamic-range expansion parameters (the `r` attribute).
    public let highlightsExpansion: Components

    /// The optional, human-readable name identifying the display function.
    public let name: String?

    /// Parses a `<DisplayFunction>` element.
    ///
    /// - Parameters:
    ///   - element: The `<DisplayFunction>` element.
    ///   - options: The parsing options to apply. (No strict-only validation is
    ///     currently applied beyond the presence and shape of the mandatory
    ///     attributes.)
    /// - Throws: ``XISFError/invalidElement(reason:)`` if a mandatory attribute
    ///   is missing or is not four colon-separated real numbers.
    internal init( element: XISFElement, options: XISFParsingOptions ) throws
    {
        self.midtonesBalance     = try XISFDisplayFunction.components( element, "m" )
        self.shadowsClipping     = try XISFDisplayFunction.components( element, "s" )
        self.highlightsClipping  = try XISFDisplayFunction.components( element, "h" )
        self.shadowsExpansion    = try XISFDisplayFunction.components( element, "l" )
        self.highlightsExpansion = try XISFDisplayFunction.components( element, "r" )
        self.name                = element.attributes[ "name" ]
    }

    /// Parses a `rk:g:b:l` parameter-vector attribute into ``Components``.
    ///
    /// - Parameters:
    ///   - element: The `<DisplayFunction>` element.
    ///   - name: The attribute name (`m`, `s`, `h`, `l` or `r`).
    /// - Returns: The parsed per-component values.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the attribute is
    ///   missing or is not four colon-separated real numbers.
    private static func components( _ element: XISFElement, _ name: String ) throws -> Components
    {
        guard let raw = element.attributes[ name ]
        else
        {
            throw XISFError.invalidElement( reason: "DisplayFunction is missing the '\( name )' attribute" )
        }

        let parts = raw.split( separator: ":", omittingEmptySubsequences: false )

        guard parts.count == 4, let rk = Double( parts[ 0 ] ), let g = Double( parts[ 1 ] ), let b = Double( parts[ 2 ] ), let l = Double( parts[ 3 ] )
        else
        {
            throw XISFError.invalidElement( reason: "DisplayFunction '\( name )' is not four colon-separated numbers: '\( raw )'" )
        }

        return Components( rk: rk, g: g, b: b, l: l )
    }

    /// A single-line, human-readable summary of the display function.
    public var description: String
    {
        "XISFDisplayFunction { m: \( self.midtonesBalance ), s: \( self.shadowsClipping ), h: \( self.highlightsClipping ), l: \( self.shadowsExpansion ), r: \( self.highlightsExpansion ), name: \( self.name ?? "<nil>" ) }"
    }
}
