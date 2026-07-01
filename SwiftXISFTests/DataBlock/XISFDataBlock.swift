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

struct Test_XISFDataBlock
{
    private static func element( _ xml: String ) throws -> XISFElement
    {
        try XISFXMLParser.parse( xml )
    }

    @Test
    func resolvesInlineBase64() async throws
    {
        let block = try XISFDataBlock( element: Test_XISFDataBlock.element( "<Image location=\"inline:base64\">SGVsbG8=</Image>" ), fileData: Data(), options: .strict )

        #expect( block.rawBytes == Data( "Hello".utf8 ) )
        #expect( block.location == .inline( encoding: .base64 ) )
    }

    @Test
    func resolvesInlineHex() async throws
    {
        let block = try XISFDataBlock( element: Test_XISFDataBlock.element( "<Image location=\"inline:hex\">48656c6c6f</Image>" ), fileData: Data(), options: .strict )

        #expect( block.rawBytes == Data( "Hello".utf8 ) )
    }

    @Test
    func resolvesEmbeddedBase64() async throws
    {
        let block = try XISFDataBlock( element: Test_XISFDataBlock.element( "<Image location=\"embedded\"><Data encoding=\"base64\">SGVsbG8=</Data></Image>" ), fileData: Data(), options: .strict )

        #expect( block.rawBytes == Data( "Hello".utf8 ) )
        #expect( block.location == .embedded )
    }

    @Test
    func rejectsEmbeddedWithoutDataChild() async throws
    {
        try #require( throws: XISFError.self ) { try XISFDataBlock( element: Test_XISFDataBlock.element( "<Image location=\"embedded\"/>" ), fileData: Data(), options: .strict ) }
    }

    @Test
    func rejectsEmbeddedWithInvalidEncoding() async throws
    {
        try #require( throws: XISFError.self ) { try XISFDataBlock( element: Test_XISFDataBlock.element( "<Image location=\"embedded\"><Data encoding=\"base32\">xx</Data></Image>" ), fileData: Data(), options: .strict ) }
    }

    @Test
    func resolvesAttachmentSlice() async throws
    {
        let fileData = Data( ( 0 ..< 16 ).map { UInt8( $0 ) } )
        let block    = try XISFDataBlock( element: Test_XISFDataBlock.element( "<Image location=\"attachment:4:3\"/>" ), fileData: fileData, options: .strict )

        #expect( Array( block.rawBytes ) == [ 0x04, 0x05, 0x06 ] )
        #expect( block.location == .attachment( position: 4, size: 3 ) )
    }

    @Test
    func rejectsAttachmentOutOfRange() async throws
    {
        let fileData = Data( ( 0 ..< 16 ).map { UInt8( $0 ) } )

        try #require( throws: XISFError.self ) { try XISFDataBlock( element: Test_XISFDataBlock.element( "<Image location=\"attachment:10:20\"/>" ), fileData: fileData, options: .strict ) }
    }

    @Test
    func rejectsMissingLocation() async throws
    {
        try #require( throws: XISFError.self ) { try XISFDataBlock( element: Test_XISFDataBlock.element( "<Image/>" ), fileData: Data(), options: .strict ) }
    }

    @Test
    func capturesRawAttributes() async throws
    {
        let block = try XISFDataBlock( element: Test_XISFDataBlock.element( "<Image location=\"attachment:0:4\" compression=\"zlib:8\" checksum=\"sha-1:abcdef\" byteOrder=\"little\"/>" ), fileData: Data( [ 1, 2, 3, 4 ] ), options: .strict )

        #expect( block.compression?.codec            == .zlib )
        #expect( block.compression?.uncompressedSize == 8 )
        #expect( block.checksum?.algorithm           == .sha1 )
        #expect( block.checksum?.digest              == "abcdef" )
        #expect( block.rawByteOrder                  == "little" )
    }

    @Test
    func capturesEmbeddedCompressionFromDataChild() async throws
    {
        let block = try XISFDataBlock( element: Test_XISFDataBlock.element( "<Image location=\"embedded\"><Data encoding=\"base64\" compression=\"zlib:5\">SGVsbG8=</Data></Image>" ), fileData: Data(), options: .strict )

        #expect( block.compression?.uncompressedSize == 5 )
    }

    @Test
    func dataDecompressesCompressedBlock() throws
    {
        let xml      = "<Image location=\"inline:hex\" compression=\"zlib:132\">\( Test_XISFCompression.zlibTextHex )</Image>"
        let block    = try XISFDataBlock( element: Test_XISFDataBlock.element( xml ), fileData: Data(), options: .strict )
        let original = try Test_XISFCompression.textHex.xisfHexDecodedData()

        #expect( try block.data == original )
        #expect( block.compression?.codec == .zlib )
    }

    @Test
    func dataEqualsRawBytesWhenUncompressed() throws
    {
        let block = try XISFDataBlock( element: Test_XISFDataBlock.element( "<Image location=\"inline:hex\">deadbeef</Image>" ), fileData: Data(), options: .strict )

        #expect( block.compression == nil )
        #expect( try block.data == Data( [ 0xDE, 0xAD, 0xBE, 0xEF ] ) )
    }

    @Test
    func dataThrowsOnCorruptCompressedStream() async throws
    {
        let block = try XISFDataBlock( element: Test_XISFDataBlock.element( "<Image location=\"inline:hex\" compression=\"zlib:132\">789c010203</Image>" ), fileData: Data(), options: .strict )

        try #require( throws: XISFError.self ) { _ = try block.data }
    }

    @Test
    func verifiesChecksumOnDataAccessWhenEnabled() throws
    {
        let xml   = "<Image location=\"inline:hex\" checksum=\"sha-256:\( Test_XISFChecksum.sha256Hex )\">deadbeef</Image>"
        let block = try XISFDataBlock( element: Test_XISFDataBlock.element( xml ), fileData: Data(), options: .strict )

        #expect( block.checksum?.algorithm == .sha256 )
        #expect( try block.data == Data( [ 0xDE, 0xAD, 0xBE, 0xEF ] ) )
    }

    @Test
    func throwsOnChecksumMismatchWhenEnabled() async throws
    {
        let xml   = "<Image location=\"inline:hex\" checksum=\"sha-256:0000000000000000000000000000000000000000000000000000000000000000\">deadbeef</Image>"
        let block = try XISFDataBlock( element: Test_XISFDataBlock.element( xml ), fileData: Data(), options: .strict )

        try #require( throws: XISFError.self ) { _ = try block.data }
    }

    @Test
    func skipsChecksumWhenVerificationDisabled() throws
    {
        let xml   = "<Image location=\"inline:hex\" checksum=\"sha-256:0000000000000000000000000000000000000000000000000000000000000000\">deadbeef</Image>"
        let block = try XISFDataBlock( element: Test_XISFDataBlock.element( xml ), fileData: Data(), options: .lenient )

        #expect( try block.data == Data( [ 0xDE, 0xAD, 0xBE, 0xEF ] ) )
    }

    @Test
    func verifiesEmbeddedChecksumFromDataChild() async throws
    {
        // A mismatching checksum on the <Data> child must be consulted (and
        // fail), proving the checksum is read from the child rather than the
        // checksum-less parent.
        let xml   = "<Image location=\"embedded\"><Data encoding=\"hex\" checksum=\"sha-256:0000000000000000000000000000000000000000000000000000000000000000\">deadbeef</Data></Image>"
        let block = try XISFDataBlock( element: Test_XISFDataBlock.element( xml ), fileData: Data(), options: .strict )

        #expect( block.checksum?.algorithm == .sha256 )

        try #require( throws: XISFError.self ) { _ = try block.data }
    }
}
