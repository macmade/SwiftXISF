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

import Compression
import Foundation

/// The compression applied to a data block, parsed from its `compression`
/// (and optional `subblocks`) attribute.
///
/// An XISF `compression` attribute has the form
/// `<codec>[+sh]:<uncompressed-size>[:<item-size>]`, where `+sh` marks
/// byte-shuffled data and `<item-size>` is the shuffle granularity. The
/// optional `subblocks` attribute (`c1,u1:c2,u2:…`) splits the stream into
/// independently-compressed sub-blocks.
///
/// ``decompress(_:)`` reverses the whole pipeline: it decodes each sub-block (or
/// the single stream), concatenates the results, validates the total length
/// against ``uncompressedSize``, and reverses any byte-shuffling.
///
/// The `zstd` codec is recognized by the format but requires an external
/// dependency and is not yet supported; parsing it throws.
public struct XISFCompression: Equatable, Sendable, CustomStringConvertible
{
    /// A supported compression codec.
    ///
    /// `zstd` is intentionally absent: it is a valid XISF codec but needs an
    /// external dependency and is deferred to a later milestone.
    public enum Codec: String, Equatable, Sendable, CaseIterable
    {
        /// The zlib codec (RFC 1950 zlib-wrapped DEFLATE).
        case zlib

        /// The LZ4 codec (raw LZ4 block format).
        case lz4

        /// The LZ4-HC codec; its streams are decoded by the same LZ4 decoder.
        case lz4hc
    }

    /// One independently-compressed sub-block of a split-compression stream.
    public struct Subblock: Equatable, Sendable
    {
        /// The size, in bytes, of this sub-block's compressed data.
        public let compressedSize: Int

        /// The size, in bytes, this sub-block decompresses to.
        public let uncompressedSize: Int
    }

    /// The codec used to compress the block.
    public let codec: Codec

    /// The total size, in bytes, of the fully decompressed data.
    public let uncompressedSize: Int

    /// The byte-shuffling item size, or `nil` if the data is not shuffled.
    public let itemSize: Int?

    /// The split-compression sub-blocks, or `nil` for a single compressed stream.
    public let subblocks: [ Subblock ]?

    /// A Boolean value indicating whether the data is byte-shuffled.
    public var usesByteShuffling: Bool
    {
        self.itemSize != nil
    }

    /// Parses a `compression` attribute (and an optional `subblocks` attribute).
    ///
    /// - Parameters:
    ///   - attribute: The raw `compression` attribute value, of the form
    ///     `<codec>[+sh]:<uncompressed-size>[:<item-size>]`.
    ///   - subblocksAttribute: The raw `subblocks` attribute value, or `nil`.
    /// - Throws: ``XISFError/decompressionError(reason:)`` if the attribute is
    ///   malformed, names an unknown codec, or names `zstd` (not yet supported).
    public init( attribute: String, subblocks subblocksAttribute: String? = nil ) throws
    {
        let parts = attribute.split( separator: ":", omittingEmptySubsequences: false ).map( String.init )

        guard parts.count >= 2
        else
        {
            throw XISFError.decompressionError( reason: "Malformed compression attribute: '\( attribute )'" )
        }

        var codecName     = parts[ 0 ]
        let isByteShuffled = codecName.hasSuffix( "+sh" )

        if isByteShuffled
        {
            codecName = String( codecName.dropLast( 3 ) )
        }

        if codecName == "zstd"
        {
            throw XISFError.decompressionError( reason: "The zstd codec is not yet supported (deferred to a later milestone)" )
        }

        guard let codec = Codec( rawValue: codecName )
        else
        {
            throw XISFError.decompressionError( reason: "Unknown compression codec: '\( codecName )'" )
        }

        guard let uncompressedSize = Int( parts[ 1 ] ), uncompressedSize >= 0
        else
        {
            throw XISFError.decompressionError( reason: "Invalid uncompressed size in compression attribute: '\( attribute )'" )
        }

        if isByteShuffled
        {
            guard parts.count == 3, let itemSize = Int( parts[ 2 ] ), itemSize > 0
            else
            {
                throw XISFError.decompressionError( reason: "Byte-shuffled compression requires a positive item size: '\( attribute )'" )
            }

            self.itemSize = itemSize
        }
        else
        {
            guard parts.count == 2
            else
            {
                throw XISFError.decompressionError( reason: "Unexpected components in compression attribute: '\( attribute )'" )
            }

            self.itemSize = nil
        }

        self.codec            = codec
        self.uncompressedSize = uncompressedSize
        self.subblocks        = try subblocksAttribute.map { try XISFCompression.parseSubblocks( $0 ) }
    }

    /// Decompresses a block's raw (as-stored) bytes into its final bytes.
    ///
    /// Decodes each sub-block (or the single stream), concatenates them,
    /// validates the total length against ``uncompressedSize``, and reverses any
    /// byte-shuffling.
    ///
    /// - Parameter input: The raw, as-stored compressed bytes.
    /// - Returns: The fully decompressed and un-shuffled bytes.
    /// - Throws: ``XISFError/decompressionError(reason:)`` if decompression fails
    ///   or the decompressed length does not match ``uncompressedSize``.
    public func decompress( _ input: Data ) throws -> Data
    {
        let decompressed: Data

        if let subblocks = self.subblocks
        {
            decompressed = try self.decompressSubblocks( input, subblocks: subblocks )
        }
        else
        {
            decompressed = try self.decode( input, expectedSize: self.uncompressedSize )
        }

        guard decompressed.count == self.uncompressedSize
        else
        {
            throw XISFError.decompressionError( reason: "Decompressed size \( decompressed.count ) does not match the declared size \( self.uncompressedSize )" )
        }

        guard let itemSize = self.itemSize, itemSize > 1
        else
        {
            return decompressed
        }

        return XISFCompression.byteUnshuffle( decompressed, itemSize: itemSize )
    }

    /// Parses a `subblocks` attribute (`c1,u1:c2,u2:…`).
    ///
    /// - Parameter attribute: The raw `subblocks` attribute value.
    /// - Returns: The parsed sub-blocks, in order.
    /// - Throws: ``XISFError/decompressionError(reason:)`` if the attribute is
    ///   malformed or empty.
    private static func parseSubblocks( _ attribute: String ) throws -> [ Subblock ]
    {
        let subblocks = try attribute.split( separator: ":", omittingEmptySubsequences: false ).map
        {
            ( pair ) -> Subblock in

            let numbers = pair.split( separator: ",", omittingEmptySubsequences: false )

            guard numbers.count == 2,
                  let compressedSize   = Int( numbers[ 0 ] ), compressedSize >= 0,
                  let uncompressedSize = Int( numbers[ 1 ] ), uncompressedSize >= 0
            else
            {
                throw XISFError.decompressionError( reason: "Malformed subblocks attribute: '\( attribute )'" )
            }

            return Subblock( compressedSize: compressedSize, uncompressedSize: uncompressedSize )
        }

        guard subblocks.isEmpty == false
        else
        {
            throw XISFError.decompressionError( reason: "Empty subblocks attribute" )
        }

        return subblocks
    }

    /// Decompresses a split-compression stream, sub-block by sub-block.
    ///
    /// - Parameters:
    ///   - input: The concatenated compressed sub-block streams.
    ///   - subblocks: The sub-block descriptors, in order.
    /// - Returns: The concatenated decompressed bytes.
    /// - Throws: ``XISFError/decompressionError(reason:)`` if a sub-block extends
    ///   past the input or fails to decompress to its declared size.
    private func decompressSubblocks( _ input: Data, subblocks: [ Subblock ] ) throws -> Data
    {
        var offset = input.startIndex

        return try subblocks.reduce( into: Data( capacity: self.uncompressedSize ) )
        {
            result, subblock in

            let end = offset + subblock.compressedSize

            guard end <= input.endIndex
            else
            {
                throw XISFError.decompressionError( reason: "Sub-block extends past the end of the compressed data" )
            }

            result += try self.decode( Data( input[ offset ..< end ] ), expectedSize: subblock.uncompressedSize )
            offset  = end
        }
    }

    /// Decodes a single compressed stream of a known decompressed size.
    ///
    /// - Parameters:
    ///   - input: The compressed bytes.
    ///   - expectedSize: The expected decompressed size, in bytes.
    /// - Returns: The decompressed bytes.
    /// - Throws: ``XISFError/decompressionError(reason:)`` on failure.
    private func decode( _ input: Data, expectedSize: Int ) throws -> Data
    {
        switch self.codec
        {
            case .zlib:        return try XISFCompression.inflateZlib( input, expectedSize: expectedSize )
            case .lz4, .lz4hc: return try XISFCompression.rawDecode( input, expectedSize: expectedSize, algorithm: COMPRESSION_LZ4_RAW )
        }
    }

    /// Decompresses an RFC 1950 zlib stream.
    ///
    /// Apple's `Compression` framework consumes raw DEFLATE (RFC 1951), so the
    /// 2-byte zlib header and trailing 4-byte Adler-32 are stripped, leaving the
    /// DEFLATE payload for `COMPRESSION_ZLIB`.
    ///
    /// - Parameters:
    ///   - input: The zlib-wrapped bytes.
    ///   - expectedSize: The expected decompressed size, in bytes.
    /// - Returns: The decompressed bytes.
    /// - Throws: ``XISFError/decompressionError(reason:)`` if the header is
    ///   invalid, uses an unsupported preset dictionary, or decoding fails.
    private static func inflateZlib( _ input: Data, expectedSize: Int ) throws -> Data
    {
        let bytes = [ UInt8 ]( input )

        guard bytes.count >= 6
        else
        {
            throw XISFError.decompressionError( reason: "zlib stream is too short" )
        }

        let cmf = bytes[ 0 ]
        let flg = bytes[ 1 ]

        // RFC 1950: the compression method must be DEFLATE (8), and the 16-bit
        // header must be a multiple of 31.
        guard ( cmf & 0x0F ) == 8, ( Int( cmf ) << 8 | Int( flg ) ) % 31 == 0
        else
        {
            throw XISFError.decompressionError( reason: "Invalid zlib (RFC 1950) header" )
        }

        // A preset dictionary (FDICT) is never produced by XISF and cannot be
        // honored with the raw-DEFLATE decoder.
        guard ( flg & 0x20 ) == 0
        else
        {
            throw XISFError.decompressionError( reason: "zlib preset dictionaries are not supported" )
        }

        let deflate = Data( bytes[ 2 ..< bytes.count - 4 ] )

        return try XISFCompression.rawDecode( deflate, expectedSize: expectedSize, algorithm: COMPRESSION_ZLIB )
    }

    /// Decodes a buffer with Apple's `Compression` framework.
    ///
    /// - Parameters:
    ///   - input: The compressed bytes.
    ///   - expectedSize: The expected decompressed size, in bytes.
    ///   - algorithm: The `compression_algorithm` to use.
    /// - Returns: The decompressed bytes.
    /// - Throws: ``XISFError/decompressionError(reason:)`` if the decoder writes
    ///   a number of bytes other than `expectedSize` (failure or size mismatch).
    private static func rawDecode( _ input: Data, expectedSize: Int, algorithm: compression_algorithm ) throws -> Data
    {
        guard expectedSize > 0
        else
        {
            return Data()
        }

        guard input.isEmpty == false
        else
        {
            throw XISFError.decompressionError( reason: "Cannot decompress an empty stream" )
        }

        var output  = Data( count: expectedSize )
        let written = output.withUnsafeMutableBytes
        {
            ( destination: UnsafeMutableRawBufferPointer ) -> Int in

            input.withUnsafeBytes
            {
                ( source: UnsafeRawBufferPointer ) -> Int in

                guard let destinationBase = destination.bindMemory( to: UInt8.self ).baseAddress,
                      let sourceBase      = source.bindMemory( to: UInt8.self ).baseAddress
                else
                {
                    return 0
                }

                return compression_decode_buffer( destinationBase, expectedSize, sourceBase, source.count, nil, algorithm )
            }
        }

        guard written == expectedSize
        else
        {
            throw XISFError.decompressionError( reason: "Decompression produced \( written ) bytes, expected \( expectedSize )" )
        }

        return output
    }

    /// Reverses byte-shuffling for the given item size.
    ///
    /// This is the inverse of the de-interleaving applied before compression:
    /// the planar byte stream is re-interleaved back into items of `itemSize`
    /// bytes. Any trailing bytes that do not fill a whole item are left
    /// unchanged, matching the reference implementation.
    ///
    /// - Parameters:
    ///   - data: The shuffled (decompressed) bytes.
    ///   - itemSize: The shuffle item size, in bytes.
    /// - Returns: The un-shuffled bytes.
    private static func byteUnshuffle( _ data: Data, itemSize: Int ) -> Data
    {
        guard itemSize > 1
        else
        {
            return data
        }

        let bytes = [ UInt8 ]( data )
        let count = bytes.count
        let items = count / itemSize
        let main  = items * itemSize

        let unshuffled = ( 0 ..< main ).map { bytes[ ( $0 % itemSize ) * items + ( $0 / itemSize ) ] }

        return Data( unshuffled ) + Data( bytes[ main... ] )
    }

    /// A single-line, human-readable summary of the compression.
    public var description: String
    {
        let shuffle    = self.itemSize.map { "+sh:\( self.uncompressedSize ):\( $0 )" } ?? ":\( self.uncompressedSize )"
        let subblockText = self.subblocks.map { ", subblocks: \( $0.count )" } ?? ""

        return "XISFCompression { \( self.codec.rawValue )\( shuffle )\( subblockText ) }"
    }
}
