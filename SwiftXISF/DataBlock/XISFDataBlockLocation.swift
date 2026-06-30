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

/// Where a data block's bytes are stored, as declared by a `location`
/// attribute.
///
/// This models the three in-file forms. External and distributed forms
/// (`url(...)` / `path(...)`) are recognized but deferred to a later milestone.
public enum XISFDataBlockLocation: Equatable, Sendable
{
    /// The text encoding of inline or embedded data-block bytes.
    public enum Encoding: String, Sendable
    {
        /// Base64 encoding.
        case base64

        /// Lowercase base16 (hexadecimal) encoding.
        case hex
    }

    /// The bytes are the element's character content, in the given encoding.
    case inline( encoding: Encoding )

    /// The bytes are a child `<Data>` element's character content; its encoding
    /// is declared on that element.
    case embedded

    /// The bytes are at an absolute offset within the monolithic file.
    case attachment( position: Int, size: Int )

    /// Parses a `location` attribute string.
    ///
    /// - Parameter attribute: The raw `location` attribute value.
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if the location is
    ///   malformed, or refers to an external/distributed file (not yet
    ///   supported).
    public init( attribute: String ) throws
    {
        // External/distributed locations embed colons inside parentheses, so
        // detect them before splitting. They are handled in a later milestone.
        if attribute.hasPrefix( "url(" ) || attribute.hasPrefix( "path(" )
        {
            throw XISFError.dataBlockError( reason: "External/distributed data-block locations are not yet supported: '\( attribute )'" )
        }

        let parts = attribute.split( separator: ":", omittingEmptySubsequences: false ).map( String.init )

        switch parts.first
        {
            case "inline":
                guard parts.count == 2, let encoding = Encoding( rawValue: parts[ 1 ] )
                else
                {
                    throw XISFError.dataBlockError( reason: "Invalid inline data-block location: '\( attribute )'" )
                }

                self = .inline( encoding: encoding )

            case "embedded":
                guard parts.count == 1
                else
                {
                    throw XISFError.dataBlockError( reason: "Invalid embedded data-block location: '\( attribute )'" )
                }

                self = .embedded

            case "attachment":
                guard parts.count == 3, let position = Int( parts[ 1 ] ), let size = Int( parts[ 2 ] ), position >= 0, size >= 0
                else
                {
                    throw XISFError.dataBlockError( reason: "Invalid attachment data-block location: '\( attribute )'" )
                }

                self = .attachment( position: position, size: size )

            default:
                throw XISFError.dataBlockError( reason: "Invalid data-block location: '\( attribute )'" )
        }
    }
}
