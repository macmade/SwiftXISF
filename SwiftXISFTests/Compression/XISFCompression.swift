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
@testable import SwiftXISF
import Testing

struct Test_XISFCompression
{
    // The reference payloads, and genuine XISF-format compressed bytes produced
    // by real third-party encoders (python `zlib` for RFC-1950 zlib; homebrew
    // `liblz4` raw blocks), so these tests prove interoperability with real XISF
    // producers — not merely Apple-encode/Apple-decode round-trips. The `+sh`
    // fixtures were forward-shuffled before compression; the `subblocks` fixture
    // is two independently-zlib-compressed halves concatenated.
    static let textHex      = "5849534620636f6d7072657373696f6e20726f756e642d7472697020746573743a2074686520717569636b2062726f776e20666f78206a756d7073206f76657220746865206c617a7920646f6720303132333435363738392074686520717569636b2062726f776e20666f78206a756d7073206f76657220746865206c617a7920646f67"
    static let zlibTextHex  = "789c8bf00c765348cecf2d284a2d2ececccf5328ca2fcd4bd12d29ca2c5028492d2eb15228c94855282ccd4cce56482aca2fcf5348cbaf50c82acd2d2856c82f4b2d024be72456552aa4e4a72b18181a199b989a995b5892a20d0044f02eba"
    static let zlibSh2Hex   = "789c63606261e3e0e2e1131012119390929163646665e7e4e6e5171416159794969507001a4801f1"
    static let zlibSh4Hex    = "789c6360e1e0111091906164e5e4151495946562e3e2131293926366e7e61716979607001c3801f1"
    static let lz4TextHex   = "f1315849534620636f6d7072657373696f6e20726f756e642d7472697020746573743a2074686520717569636b2062726f776e20666f78206a756d7073206f7665721f00f1046c617a7920646f67203031323334353637383918000f37000f507920646f67"
    static let lz4hcTextHex = "f1315849534620636f6d7072657373696f6e20726f756e642d7472697020746573743a2074686520717569636b2062726f776e20666f78206a756d7073206f7665721f00ff046c617a7920646f672030313233343536373839370014507920646f67"
    static let lz4Sh2Hex    = "f01100020406080a0c0e10121416181a1c1e01030507090b0d0f11131517191b1d1f"
    static let subblocksHex = "789c05c1c10d80300805d055fe022ee000269ebd78b662c4a68040d5f17d6f9d9709459b3945b00a5cbbec433a1b922247e449b83b978acdf5151cfae1eacd02fa90237f3080186d789ccb4855c849acaa5448c94f573030343236313533b7b05428c94855282ccd4cce56482aca2fcf5348cbaf50c82acd2d2856c82f4b2d024bc3b40100c82f164e"

    /// The 32-byte shuffle payload: the bytes 0...31.
    static let shufflePayload = Data( ( 0 ..< 32 ).map { UInt8( $0 ) } )

    // MARK: - Attribute parsing

    @Test
    func parsesPlainCodec() throws
    {
        let compression = try XISFCompression( attribute: "zlib:6220800" )

        #expect( compression.codec            == .zlib )
        #expect( compression.uncompressedSize == 6220800 )
        #expect( compression.itemSize         == nil )
        #expect( compression.subblocks        == nil )
    }

    @Test
    func parsesShuffledCodec() throws
    {
        let compression = try XISFCompression( attribute: "zlib+sh:6220800:2" )

        #expect( compression.codec    == .zlib )
        #expect( compression.itemSize == 2 )
    }

    @Test
    func parsesLZ4Variants() throws
    {
        #expect( try XISFCompression( attribute: "lz4:10" ).codec        == .lz4 )
        #expect( try XISFCompression( attribute: "lz4hc:10" ).codec      == .lz4hc )
        #expect( try XISFCompression( attribute: "lz4+sh:10:4" ).itemSize == 4 )
        #expect( try XISFCompression( attribute: "lz4hc+sh:10:4" ).codec == .lz4hc )
    }

    @Test
    func parsesSubblocks() throws
    {
        let compression = try XISFCompression( attribute: "zlib:132", subblocks: "72,66:65,66" )

        #expect( compression.subblocks?.count == 2 )
        #expect( compression.subblocks?[ 0 ].compressedSize   == 72 )
        #expect( compression.subblocks?[ 0 ].uncompressedSize == 66 )
        #expect( compression.subblocks?[ 1 ].compressedSize   == 65 )
        #expect( compression.subblocks?[ 1 ].uncompressedSize == 66 )
    }

    @Test
    func rejectsUnknownCodec() async throws
    {
        try #require( throws: XISFError.self ) { try XISFCompression( attribute: "lzw:10" ) }
    }

    @Test
    func rejectsZstdAsDeferred() async throws
    {
        // zstd is a real XISF codec but requires an external dependency (M13);
        // it must fail cleanly rather than be reported as an unknown codec.
        try #require( throws: XISFError.self ) { try XISFCompression( attribute: "zstd:10" ) }
        try #require( throws: XISFError.self ) { try XISFCompression( attribute: "zstd+sh:10:2" ) }
    }

    @Test
    func rejectsMalformedAttributes() async throws
    {
        try #require( throws: XISFError.self ) { try XISFCompression( attribute: "zlib" ) }
        try #require( throws: XISFError.self ) { try XISFCompression( attribute: "zlib:" ) }
        try #require( throws: XISFError.self ) { try XISFCompression( attribute: "zlib:abc" ) }
        try #require( throws: XISFError.self ) { try XISFCompression( attribute: "zlib+sh:10" ) }
        try #require( throws: XISFError.self ) { try XISFCompression( attribute: "zlib+sh:10:abc" ) }
        try #require( throws: XISFError.self ) { try XISFCompression( attribute: "" ) }
    }

    // MARK: - Decompression round-trips (against real-encoder fixtures)

    @Test
    func decompressesZlib() throws
    {
        let original = try Test_XISFCompression.textHex.xisfHexDecodedData()
        let input    = try Test_XISFCompression.zlibTextHex.xisfHexDecodedData()

        #expect( try XISFCompression( attribute: "zlib:132" ).decompress( input ) == original )
    }

    @Test
    func decompressesLZ4() throws
    {
        let original = try Test_XISFCompression.textHex.xisfHexDecodedData()
        let input    = try Test_XISFCompression.lz4TextHex.xisfHexDecodedData()

        #expect( try XISFCompression( attribute: "lz4:132" ).decompress( input ) == original )
    }

    @Test
    func decompressesLZ4HC() throws
    {
        let original = try Test_XISFCompression.textHex.xisfHexDecodedData()
        let input    = try Test_XISFCompression.lz4hcTextHex.xisfHexDecodedData()

        #expect( try XISFCompression( attribute: "lz4hc:132" ).decompress( input ) == original )
    }

    @Test
    func decompressesZlibWithByteShufflingItemSize2() throws
    {
        let input = try Test_XISFCompression.zlibSh2Hex.xisfHexDecodedData()

        #expect( try XISFCompression( attribute: "zlib+sh:32:2" ).decompress( input ) == Test_XISFCompression.shufflePayload )
    }

    @Test
    func decompressesZlibWithByteShufflingItemSize4() throws
    {
        let input = try Test_XISFCompression.zlibSh4Hex.xisfHexDecodedData()

        #expect( try XISFCompression( attribute: "zlib+sh:32:4" ).decompress( input ) == Test_XISFCompression.shufflePayload )
    }

    @Test
    func decompressesLZ4WithByteShuffling() throws
    {
        let input = try Test_XISFCompression.lz4Sh2Hex.xisfHexDecodedData()

        #expect( try XISFCompression( attribute: "lz4+sh:32:2" ).decompress( input ) == Test_XISFCompression.shufflePayload )
    }

    @Test
    func decompressesSubblocks() throws
    {
        let original = try Test_XISFCompression.textHex.xisfHexDecodedData()
        let input    = try Test_XISFCompression.subblocksHex.xisfHexDecodedData()

        #expect( try XISFCompression( attribute: "zlib:132", subblocks: "72,66:65,66" ).decompress( input ) == original )
    }

    @Test
    func throwsOnShortOrCorruptStream() async throws
    {
        let compression = try XISFCompression( attribute: "zlib:132" )
        let garbage     = Data( [ 0x78, 0x9C, 0x01, 0x02, 0x03 ] )

        try #require( throws: XISFError.self ) { try compression.decompress( garbage ) }
    }

    @Test
    func throwsWhenDecompressedSizeDiffersFromDeclared() async throws
    {
        let input       = try Test_XISFCompression.zlibTextHex.xisfHexDecodedData()
        let compression = try XISFCompression( attribute: "zlib:200" )

        try #require( throws: XISFError.self ) { try compression.decompress( input ) }
    }
}
