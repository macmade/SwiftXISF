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

/// An XISF `<FITSKeyword>`: an embedded FITS header card.
///
/// XISF carries legacy FITS keywords verbatim, so the value is kept as the raw
/// FITS-formatted string rather than a typed value. A keyword has an 8-character
/// `name`, an optional `value` (empty for `HISTORY`/`COMMENT` cards), and an
/// optional `comment`.
public struct XISFFITSKeyword: Equatable, Sendable, CustomStringConvertible
{
    /// The FITS keyword name (up to 8 characters).
    public let name: String

    /// The raw FITS value string, or `nil` when the keyword carries no value
    /// (for example `HISTORY` or `COMMENT`).
    public let value: String?

    /// The keyword's optional comment.
    public let comment: String?

    /// The characters permitted in a FITS keyword name: uppercase letters,
    /// digits, the hyphen and the underscore.
    private static let allowedNameCharacters = CharacterSet( charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" )

    /// Parses a FITS keyword from a `<FITSKeyword>` element.
    ///
    /// - Parameters:
    ///   - element: The `<FITSKeyword>` element.
    ///   - options: The parsing options to apply. Under strict parsing the name
    ///     must be at most 8 characters drawn from the FITS keyword character
    ///     set; ``XISFParsingOptions/allowSpecDeviations`` relaxes that check.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the `name` attribute is
    ///   missing or, under strict parsing, invalid.
    internal init( element: XISFElement, options: XISFParsingOptions ) throws
    {
        guard let name = element.attributes[ "name" ], name.isEmpty == false
        else
        {
            throw XISFError.invalidElement( reason: "FITSKeyword is missing a 'name' attribute" )
        }

        if options.contains( .allowSpecDeviations ) == false
        {
            guard name.count <= 8, name.unicodeScalars.allSatisfy( { XISFFITSKeyword.allowedNameCharacters.contains( $0 ) } )
            else
            {
                throw XISFError.invalidElement( reason: "Invalid FITS keyword name: '\( name )'" )
            }
        }

        let value = element.attributes[ "value" ]

        self.name    = name
        self.value   = ( value?.isEmpty ?? true ) ? nil : value
        self.comment = element.attributes[ "comment" ]
    }

    /// A single-line, human-readable summary of the keyword.
    public var description: String
    {
        "XISFFITSKeyword { name: \( self.name ), value: \( self.value ?? "<nil>" ), comment: \( self.comment ?? "<nil>" ) }"
    }
}
