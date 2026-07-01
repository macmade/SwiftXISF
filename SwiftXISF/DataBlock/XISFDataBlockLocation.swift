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
/// This models the three in-file forms (`inline`, `embedded`, `attachment`) and
/// the external/distributed forms (`url(...)` and `path(...)`, optionally with a
/// `:index-id` into an XISF data blocks file).
public enum XISFDataBlockLocation: Equatable, Sendable, CustomStringConvertible
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

    /// The bytes are an external resource at the given URL. When `indexID` is
    /// `nil`, the block is the whole file; otherwise the file is an XISF data
    /// blocks file and `indexID` selects a block index element.
    case url( URL, indexID: UInt64? )

    /// The bytes are in a local file at an absolute path. When `indexID` is
    /// `nil`, the block is the whole file; otherwise the file is an XISF data
    /// blocks file and `indexID` selects a block index element.
    case absolutePath( String, indexID: UInt64? )

    /// The bytes are in a local file at a path relative to the directory of the
    /// XISF header file (the `@header_dir` prefix). When `indexID` is `nil`, the
    /// block is the whole file; otherwise the file is an XISF data blocks file
    /// and `indexID` selects a block index element.
    case headerRelativePath( String, indexID: UInt64? )

    /// A Boolean value indicating whether the block is stored outside the XISF
    /// header file (a `url(...)` or `path(...)` location).
    public var isExternal: Bool
    {
        switch self
        {
            case .inline, .embedded, .attachment:              return false
            case .url, .absolutePath, .headerRelativePath:     return true
        }
    }

    /// The `location` attribute form this location describes (for example
    /// `inline:base64`, `attachment:4570:1428362` or `path(@header_dir/rel)`).
    public var description: String
    {
        let suffix = { ( indexID: UInt64? ) in indexID.map { ":\( $0 )" } ?? "" }

        switch self
        {
            case .inline( let encoding ):               return "inline:\( encoding.rawValue )"
            case .embedded:                             return "embedded"
            case .attachment( let position, let size ): return "attachment:\( position ):\( size )"
            case .url( let url, let indexID ):          return "url(\( url.absoluteString ))\( suffix( indexID ) )"
            case .absolutePath( let path, let indexID ):      return "path(\( path ))\( suffix( indexID ) )"
            case .headerRelativePath( let path, let indexID ): return "path(@header_dir/\( path ))\( suffix( indexID ) )"
        }
    }

    /// Parses a `location` attribute string.
    ///
    /// The value is expected to be already XML-decoded, as it is when read from
    /// a parsed header: any parentheses that were escaped as character or entity
    /// references in the URL or path (for example `&#40;` / `&#41;`) are literal
    /// `(` / `)` by the time they reach this initializer.
    ///
    /// - Parameter attribute: The XML-decoded `location` attribute value.
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if the location is
    ///   malformed.
    public init( attribute: String ) throws
    {
        // External/distributed locations embed colons (and possibly literal
        // parentheses) inside parentheses, so parse them before splitting on ':'.
        if attribute.hasPrefix( "url(" ) || attribute.hasPrefix( "path(" )
        {
            self = try XISFDataBlockLocation.parseExternal( attribute )

            return
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

    /// Parses an external `url(...)` or `path(...)` location.
    ///
    /// The resource is everything between the first `(` and the *last* `)` (so a
    /// URL or path may itself contain parentheses), optionally followed by
    /// `:index-id`. A `path(...)` beginning with `@header_dir/` is a
    /// header-relative path; any other `path(...)` is absolute.
    ///
    /// - Parameter attribute: The `location` attribute value, which must start
    ///   with `url(` or `path(`.
    /// - Returns: The parsed external location.
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if the parentheses are
    ///   unbalanced, a URL is invalid, or the `index-id` is not an unsigned
    ///   integer.
    private static func parseExternal( _ attribute: String ) throws -> XISFDataBlockLocation
    {
        let isURL  = attribute.hasPrefix( "url(" )
        let prefix = isURL ? "url(" : "path("

        guard let close = attribute.lastIndex( of: ")" )
        else
        {
            throw XISFError.dataBlockError( reason: "External data-block location is missing a closing parenthesis: '\( attribute )'" )
        }

        let open = attribute.index( attribute.startIndex, offsetBy: prefix.count )

        guard open <= close
        else
        {
            throw XISFError.dataBlockError( reason: "Malformed external data-block location: '\( attribute )'" )
        }

        let resource = String( attribute[ open ..< close ] )
        let trailing = attribute[ attribute.index( after: close )... ]
        let indexID  = try XISFDataBlockLocation.parseTrailingIndexID( trailing, attribute: attribute )

        if isURL
        {
            guard let url = URL( string: resource )
            else
            {
                throw XISFError.dataBlockError( reason: "Invalid data-block URL: '\( resource )'" )
            }

            return .url( url, indexID: indexID )
        }

        let headerPrefix = "@header_dir/"

        if resource.hasPrefix( headerPrefix )
        {
            return .headerRelativePath( String( resource.dropFirst( headerPrefix.count ) ), indexID: indexID )
        }

        return .absolutePath( resource, indexID: indexID )
    }

    /// Parses the optional `:index-id` that may trail an external location.
    ///
    /// - Parameters:
    ///   - trailing: The substring after the closing parenthesis (empty, or
    ///     `:index-id`).
    ///   - attribute: The full attribute value, for error reporting.
    /// - Returns: The parsed index identifier, or `nil` if none is present.
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if trailing text is
    ///   present but is not a valid `:index-id`.
    private static func parseTrailingIndexID( _ trailing: Substring, attribute: String ) throws -> UInt64?
    {
        guard trailing.isEmpty == false
        else
        {
            return nil
        }

        guard trailing.hasPrefix( ":" )
        else
        {
            throw XISFError.dataBlockError( reason: "Unexpected trailing text in external data-block location: '\( attribute )'" )
        }

        let digits = trailing.dropFirst()
        let value  = digits.hasPrefix( "0x" ) || digits.hasPrefix( "0X" ) ? UInt64( digits.dropFirst( 2 ), radix: 16 ) : UInt64( digits )

        guard let value
        else
        {
            throw XISFError.dataBlockError( reason: "Invalid data-block index-id: '\( digits )'" )
        }

        return value
    }
}
