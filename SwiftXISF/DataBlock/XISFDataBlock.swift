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
/// For in-file locations (inline, embedded, attachment) the block's *raw* (still
/// as-stored, possibly compressed) bytes are decoded eagerly during
/// initialization. For external/distributed locations (`url(...)` / `path(...)`)
/// resolution is deferred: the external file is read only when ``rawBytes`` (or
/// ``data``) is first accessed, so opening a distributed unit does not read
/// resources that are never used. Both are exposed via ``rawBytes``. The fully
/// decoded bytes — decompressed and byte-unshuffled per the block's
/// ``compression`` — are available via ``data``, computed lazily and cached on
/// first access.
///
/// Like `FITSBlock`, this is a reference type so ``rawBytes`` and ``data`` can be
/// computed once and cached. Because that caching mutates on read, it is not
/// thread-safe and not `Sendable`: a block must not be read concurrently from
/// multiple threads.
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
    /// block's ``checksum`` and whether external locations may be resolved.
    private let options: XISFParsingOptions

    /// The directory of the XISF header file, used to resolve `@header_dir`
    /// relative external locations, or `nil` when the unit was opened from raw
    /// data (in which case relative external locations cannot be resolved).
    private let baseURL: URL?

    /// The eagerly-resolved in-file bytes (inline, embedded or attachment), or
    /// `nil` for an external location whose bytes are resolved lazily.
    private let inFileBytes: Data?

    /// The block's raw (still as-stored, possibly compressed) bytes: the in-file
    /// bytes, or — for an external location — the bytes read from the external
    /// resource, computed lazily and cached on first access.
    private lazy var storedResult: Result<Data, any Error> = Result { try self.resolveStoredBytes() }

    /// The block's raw, as-stored bytes: decoded from the inline/embedded
    /// encoding, sliced from the attached region, or read from the external
    /// resource. These bytes are still compressed if the block declares a
    /// ``compression``.
    ///
    /// For an external location this reads the external file on first access.
    ///
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if an external location
    ///   cannot be resolved (resolution disabled, missing base directory, unread
    ///   able or remote file, or a bad data-blocks-file index).
    public var rawBytes: Data
    {
        get throws { try self.storedResult.get() }
    }

    /// The size, in bytes, the block decodes to — its ``compression``'s declared
    /// uncompressed size, or the in-file byte count if the block is uncompressed.
    ///
    /// This is `nil` only for an uncompressed *external* block, whose size is not
    /// known without reading the external resource. It is always known without
    /// decompressing, so callers can validate an expected size cheaply.
    public var uncompressedSize: Int?
    {
        self.compression?.uncompressedSize ?? self.inFileBytes?.count
    }

    /// The fully decoded bytes, computed lazily and cached on first access (the
    /// result, success or failure, is cached). Decompresses and byte-unshuffles
    /// ``rawBytes`` per the block's ``compression``, or returns ``rawBytes``
    /// unchanged when the block is uncompressed.
    private lazy var decoded: Result<Data, any Error> = Result
    {
        let rawBytes = try self.rawBytes

        // The checksum covers the stored (as-on-disk, still-compressed) bytes,
        // so it is verified before decompression, and only when requested.
        if self.options.contains( .verifyChecksums ), let checksum = self.checksum
        {
            try checksum.verify( rawBytes )
        }

        guard let compression = self.compression
        else
        {
            return rawBytes
        }

        return try compression.decompress( rawBytes )
    }

    /// The block's fully decoded bytes: decompressed and byte-unshuffled per its
    /// ``compression``, or ``rawBytes`` if the block is uncompressed.
    ///
    /// Computed once on first access and cached.
    ///
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if an external location
    ///   cannot be resolved, ``XISFError/checksumMismatch(reason:)`` if checksum
    ///   verification is enabled and fails, or
    ///   ``XISFError/decompressionError(reason:)`` if decompression fails.
    public var data: Data
    {
        get throws { try self.decoded.get() }
    }

    /// Resolves a data block from an element that declares a `location`.
    ///
    /// In-file locations (inline, embedded, attachment) are decoded eagerly;
    /// external locations (`url(...)` / `path(...)`) are validated here but their
    /// bytes are read lazily on first access to ``rawBytes`` / ``data``.
    ///
    /// - Parameters:
    ///   - element: The element carrying the data-block attributes (and, for an
    ///     embedded block, the `<Data>` child).
    ///   - fileData: The complete file bytes, used to slice an `attachment`
    ///     block by its absolute offset.
    ///   - baseURL: The directory of the XISF header file, used to resolve
    ///     `@header_dir` relative external locations; `nil` when the unit was
    ///     opened from raw data.
    ///   - options: The parsing options to apply.
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if the `location` is
    ///   missing or malformed, an embedded block lacks a valid `<Data>` child, or
    ///   an attachment range is out of bounds; or ``XISFError/dataError(reason:)``
    ///   if inline/embedded content is not valid base64 or hexadecimal.
    internal init( element: XISFElement, fileData: Data, baseURL: URL?, options: XISFParsingOptions ) throws
    {
        guard let locationString = element.attributes[ "location" ]
        else
        {
            throw XISFError.dataBlockError( reason: "Data block is missing a 'location' attribute" )
        }

        let location = try XISFDataBlockLocation( attribute: locationString )

        self.location = location
        self.baseURL  = baseURL

        // The element that carries the data-block attributes: for an embedded
        // block it is the <Data> child (with the parent as a fallback),
        // otherwise the element itself.
        let compressionSource: XISFElement

        switch location
        {
            case .inline( let encoding ):
                self.inFileBytes  = try XISFDataBlock.decode( element.content, encoding: encoding )
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

                self.inFileBytes  = try XISFDataBlock.decode( dataElement.content, encoding: encoding )
                compressionSource = dataElement

            case .attachment( let position, let size ):
                guard let bytes = try? fileData.bytes( at: position, count: size )
                else
                {
                    throw XISFError.dataBlockError( reason: "Attachment range (position \( position ), size \( size )) is out of bounds for the \( fileData.count )-byte file" )
                }

                self.inFileBytes  = bytes
                compressionSource = element

            case .url, .absolutePath, .headerRelativePath:
                // External bytes are resolved lazily on first access.
                self.inFileBytes  = nil
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

    /// Resolves the block's raw, as-stored bytes.
    ///
    /// Returns the eagerly-decoded in-file bytes, or — for an external location —
    /// reads the external resource, gated by
    /// ``XISFParsingOptions/allowExternalLocations``.
    ///
    /// - Returns: The raw, as-stored bytes.
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if external resolution is
    ///   disabled, a `@header_dir` location has no base directory, the resource
    ///   is remote or unreadable, or a data-blocks-file index lookup fails.
    private func resolveStoredBytes() throws -> Data
    {
        if let inFileBytes = self.inFileBytes
        {
            return inFileBytes
        }

        guard self.options.contains( .allowExternalLocations )
        else
        {
            throw XISFError.dataBlockError( reason: "External/distributed data-block resolution is disabled; enable XISFParsingOptions.allowExternalLocations to read '\( self.location )'" )
        }

        switch self.location
        {
            case .url( let url, let indexID ):
                return try XISFDataBlock.readExternal( url: url, indexID: indexID )

            case .absolutePath( let path, let indexID ):
                return try XISFDataBlock.readExternal( url: URL( fileURLWithPath: path ), indexID: indexID )

            case .headerRelativePath( let path, let indexID ):
                guard let baseURL = self.baseURL
                else
                {
                    throw XISFError.dataBlockError( reason: "A '@header_dir' relative data-block location requires opening the file from a URL, not from raw data" )
                }

                return try XISFDataBlock.readExternal( url: baseURL.appendingPathComponent( path ), indexID: indexID )

            case .inline, .embedded, .attachment:
                // Unreachable: in-file locations always have inFileBytes.
                throw XISFError.dataBlockError( reason: "Internal error: in-file data block has no bytes" )
        }
    }

    /// Reads an external data block from a local file URL.
    ///
    /// When `indexID` is `nil` the block is the whole file; otherwise the file is
    /// an XISF data blocks file and the block is located through its block index.
    ///
    /// - Parameters:
    ///   - url: The file URL of the external resource. Remote (non-file) URLs are
    ///     not supported.
    ///   - indexID: The optional data-blocks-file block index identifier.
    /// - Returns: The raw bytes of the external block.
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if the URL is remote, the
    ///   file cannot be read, or the index lookup fails.
    private static func readExternal( url: URL, indexID: UInt64? ) throws -> Data
    {
        guard url.isFileURL
        else
        {
            throw XISFError.dataBlockError( reason: "Remote external data blocks are not supported: \( url.absoluteString )" )
        }

        let data: Data

        do
        {
            data = try Data( contentsOf: url, options: .mappedIfSafe )
        }
        catch
        {
            throw XISFError.dataBlockError( reason: "Cannot read external data-block file: \( url.path )" )
        }

        guard let indexID
        else
        {
            return data
        }

        return try XISFDataBlocksFile.block( withID: indexID, in: data )
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
