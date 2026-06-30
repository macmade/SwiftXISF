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

/// Decoding and validation helpers for the textual parts of an XISF header.
public extension String
{
    /// A Boolean value indicating whether the string is a valid XISF identifier.
    ///
    /// XISF identifiers (property and image `id` attributes, for instance) match
    /// the grammar `[_a-zA-Z][_a-zA-Z0-9]*`: a non-empty string starting with an
    /// ASCII letter or underscore, followed by letters, digits or underscores.
    var isValidXISFIdentifier: Bool
    {
        guard let first = self.unicodeScalars.first,
              CharacterSet.xisfIdentifierStart.contains( first )
        else
        {
            return false
        }

        return self.unicodeScalars.dropFirst().allSatisfy { CharacterSet.xisfIdentifierBody.contains( $0 ) }
    }

    /// Decodes the string as lowercase base16 (hexadecimal) bytes.
    ///
    /// Whitespace is ignored, so hex content wrapped across lines in the XML
    /// header decodes correctly. Although the XISF specification emits lowercase
    /// digits, uppercase digits are also accepted.
    ///
    /// - Returns: The decoded bytes; an empty string yields empty data.
    /// - Throws: ``XISFError/dataError(reason:)`` if, after removing whitespace,
    ///           the string has an odd number of digits or contains a character
    ///           that is not a hexadecimal digit.
    func xisfHexDecodedData() throws -> Data
    {
        let digits = Array( self.filter { $0.isWhitespace == false } )

        if digits.count % 2 != 0
        {
            throw XISFError.dataError( reason: "Hex string has an odd number of digits" )
        }

        let bytes = try stride( from: 0, to: digits.count, by: 2 ).map
        {
            ( index ) -> UInt8 in

            guard let high = digits[ index ].hexDigitValue,
                  let low  = digits[ index + 1 ].hexDigitValue
            else
            {
                throw XISFError.dataError( reason: "Invalid hexadecimal digit" )
            }

            return UInt8( ( high << 4 ) | low )
        }

        return Data( bytes )
    }

    /// Decodes the string as base64 bytes.
    ///
    /// Unknown characters, including the whitespace used to wrap base64 content
    /// across lines in the XML header, are ignored.
    ///
    /// - Returns: The decoded bytes.
    /// - Throws: ``XISFError/dataError(reason:)`` if the string is not valid
    ///           base64.
    func xisfBase64DecodedData() throws -> Data
    {
        guard let data = Data( base64Encoded: self, options: .ignoreUnknownCharacters )
        else
        {
            throw XISFError.dataError( reason: "Invalid base64 data" )
        }

        return data
    }
}
