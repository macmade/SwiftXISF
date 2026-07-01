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
/// ``rawBytes``. The fully decoded bytes — decompressed and byte-unshuffled per
/// the block's ``compression`` — are available via ``data``, computed lazily and
/// cached on first access. The `checksum` and `byteOrder` attributes are
/// captured as raw strings for later stages.
///
/// Like `FITSBlock`, this is a reference type so ``data`` can be computed once
/// and cached. Because that caching mutates on read, it is not thread-safe and
/// not `Sendable`: a block must not be read concurrently from multiple threads.
public final class XISFDataBlock
{
    /// Where the block's bytes are stored.
    public let location: XISFDataBlockLocation

    /// The block's compression, or `nil` if it is uncompressed.
    public let compression: XISFCompression?

    /// The block's checksum, or `nil` if it declares none.
    ///
    /// When the parsing options request checksum verification, ``data`` verifies
    /// this against ``rawBytes`` (the stored bytes) on first access.
    public let checksum: XISFChecksum?

    /// The raw `byteOrder` attribute, or `nil` if unspecified. Interpreted when
    /// images are parsed.
    public let rawByteOrder: String?

    /// The parsing options applied, used to decide whether ``data`` verifies the
    /// block's ``checksum``.
    private let options: XISFParsingOptions

    /// The block's raw, as-stored bytes: decoded from the inline/embedded
    /// encoding, or sliced from the attached region. These bytes are still
    /// compressed if the block declares a ``compression``.
    public let rawBytes: Data

    /// The fully decoded bytes, computed lazily and cached on first access (the
    /// result, success or failure, is cached). Decompresses and byte-unshuffles
    /// ``rawBytes`` per the block's ``compression``, or returns ``rawBytes``
    /// unchanged when the block is uncompressed.
    private lazy var decoded: Result<Data, any Error> = Result
    {
        // The checksum covers the stored (as-on-disk, still-compressed) bytes,
        // so it is verified before decompression, and only when requested.
        if self.options.contains( .verifyChecksums ), let checksum = self.checksum
        {
            try checksum.verify( self.rawBytes )
        }

        guard let compression = self.compression
        else
        {
            return self.rawBytes
        }

        return try compression.decompress( self.rawBytes )
    }

    /// The block's fully decoded bytes: decompressed and byte-unshuffled per its
    /// ``compression``, or ``rawBytes`` if the block is uncompressed.
    ///
    /// Computed once on first access and cached.
    ///
    /// - Throws: ``XISFError/checksumMismatch(reason:)`` if checksum verification
    ///   is enabled and fails, or ``XISFError/decompressionError(reason:)`` if
    ///   decompression fails.
    public var data: Data
    {
        get throws { try self.decoded.get() }
    }

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

        self.location = location

        // The element that carries the data-block attributes: for an embedded
        // block it is the <Data> child (with the parent as a fallback),
        // otherwise the element itself.
        let compressionSource: XISFElement

        switch location
        {
            case .inline( let encoding ):
                self.rawBytes     = try XISFDataBlock.decode( element.content, encoding: encoding )
                compressionSource = element

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

                self.rawBytes     = try XISFDataBlock.decode( dataElement.content, encoding: encoding )
                compressionSource = dataElement

            case .attachment( let position, let size ):
                guard let bytes = try? fileData.bytes( at: position, count: size )
                else
                {
                    throw XISFError.dataBlockError( reason: "Attachment range (position \( position ), size \( size )) is out of bounds for the \( fileData.count )-byte file" )
                }

                self.rawBytes     = bytes
                compressionSource = element
        }

        let compressionAttribute = compressionSource.attributes[ "compression" ] ?? element.attributes[ "compression" ]
        let subblocksAttribute   = compressionSource.attributes[ "subblocks" ]   ?? element.attributes[ "subblocks" ]
        let checksumAttribute    = compressionSource.attributes[ "checksum" ]    ?? element.attributes[ "checksum" ]

        self.compression  = try compressionAttribute.map { try XISFCompression( attribute: $0, subblocks: subblocksAttribute ) }
        self.rawByteOrder = compressionSource.attributes[ "byteOrder" ] ?? element.attributes[ "byteOrder" ]
        self.options      = options

        if let checksumAttribute
        {
            // A checksum that fails to parse only matters when verification is
            // requested; otherwise it is ignored rather than failing the parse.
            self.checksum = options.contains( .verifyChecksums ) ? try XISFChecksum( attribute: checksumAttribute ) : try? XISFChecksum( attribute: checksumAttribute )
        }
        else
        {
            self.checksum = nil
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
