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

/// A resolved XISF data block: the bytes backing an image, a thumbnail, an ICC
/// profile, or a vector/matrix property value.
///
/// Resolution decodes inline/embedded encodings and slices the attached region,
/// yielding the block's *raw* (still as-stored, possibly compressed) bytes via
/// ``rawBytes``. Decompression, byte-unshuffling and checksum verification are
/// layered on top in later stages; the `compression`, `checksum` and `byteOrder`
/// attributes are captured here for those stages.
///
/// Like `FITSBlock`, this is a reference type so derived values can be cached on
/// read.
public final class XISFDataBlock
{
    /// Where the block's bytes are stored.
    public let location: XISFDataBlockLocation

    /// The raw `compression` attribute, or `nil` if the block is uncompressed.
    /// Parsed into a codec descriptor in a later stage.
    public let rawCompression: String?

    /// The raw `checksum` attribute, or `nil` if the block has no checksum.
    /// Parsed and verified in a later stage.
    public let rawChecksum: String?

    /// The raw `byteOrder` attribute, or `nil` if unspecified. Interpreted when
    /// images are parsed.
    public let rawByteOrder: String?

    /// The block's raw, as-stored bytes: decoded from the inline/embedded
    /// encoding, or sliced from the attached region. These bytes are still
    /// compressed if the block declares a `compression`.
    public let rawBytes: Data

    /// Resolves a data block from an element that declares a `location`.
    ///
    /// - Parameters:
    ///   - element: The element carrying the data-block attributes (and, for an
    ///     embedded block, the `<Data>` child).
    ///   - fileData: The complete file bytes, used to slice an `attachment`
    ///     block by its absolute offset.
    ///   - options: The parsing options to apply.
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if the `location` is
    ///   missing or malformed, an embedded block lacks a valid `<Data>` child, or
    ///   an attachment range is out of bounds; or ``XISFError/dataError(reason:)``
    ///   if inline/embedded content is not valid base64 or hexadecimal.
    internal init( element: XISFElement, fileData: Data, options: XISFParsingOptions ) throws
    {
        guard let locationString = element.attributes[ "location" ]
        else
        {
            throw XISFError.dataBlockError( reason: "Data block is missing a 'location' attribute" )
        }

        let location = try XISFDataBlockLocation( attribute: locationString )

        self.location     = location
        self.rawChecksum  = element.attributes[ "checksum" ]
        self.rawByteOrder = element.attributes[ "byteOrder" ]

        switch location
        {
            case .inline( let encoding ):
                self.rawCompression = element.attributes[ "compression" ]
                self.rawBytes       = try XISFDataBlock.decode( element.content, encoding: encoding )

            case .embedded:
                guard let dataElement = element.children( named: "Data" ).first
                else
                {
                    throw XISFError.dataBlockError( reason: "Embedded data block is missing its <Data> child element" )
                }

                guard let encodingString = dataElement.attributes[ "encoding" ], let encoding = XISFDataBlockLocation.Encoding( rawValue: encodingString )
                else
                {
                    throw XISFError.dataBlockError( reason: "Embedded <Data> element has a missing or invalid 'encoding' attribute" )
                }

                // For an embedded block the compression is declared on the
                // <Data> child, falling back to the parent element.
                self.rawCompression = dataElement.attributes[ "compression" ] ?? element.attributes[ "compression" ]
                self.rawBytes       = try XISFDataBlock.decode( dataElement.content, encoding: encoding )

            case .attachment( let position, let size ):
                self.rawCompression = element.attributes[ "compression" ]

                guard let bytes = try? fileData.bytes( at: position, count: size )
                else
                {
                    throw XISFError.dataBlockError( reason: "Attachment range (position \( position ), size \( size )) is out of bounds for the \( fileData.count )-byte file" )
                }

                self.rawBytes = bytes
        }
    }

    /// Decodes inline/embedded text into bytes.
    ///
    /// - Parameters:
    ///   - text: The encoded character content.
    ///   - encoding: The declared encoding.
    /// - Returns: The decoded bytes.
    /// - Throws: ``XISFError/dataError(reason:)`` if the text is not valid for
    ///   the encoding.
    private static func decode( _ text: String, encoding: XISFDataBlockLocation.Encoding ) throws -> Data
    {
        switch encoding
        {
            case .base64: return try text.xisfBase64DecodedData()
            case .hex:    return try text.xisfHexDecodedData()
        }
    }
}
