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

struct Test_XISFFile
{
    /// Builds a monolithic-file byte stream for testing.
    private static func monolithicFile( signature: String = "XISF0100", headerLength: UInt32? = nil, reserved: UInt32 = 0, xml: String = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\"/>", attachment: Data = Data() ) -> Data
    {
        let xmlData = Data( xml.utf8 )
        var data    = Data()

        data.append( contentsOf: Array( signature.utf8 ) )
        withUnsafeBytes( of: ( headerLength ?? UInt32( xmlData.count ) ).littleEndian ) { data.append( contentsOf: $0 ) }
        withUnsafeBytes( of: reserved.littleEndian )                                   { data.append( contentsOf: $0 ) }
        data.append( xmlData )
        data.append( attachment )

        return data
    }

    @Test
    func validPreamble() async throws
    {
        let xml  = "<?xml version=\"1.0\"?><xisf version=\"1.0\"/>"
        let file = try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict )

        #expect( file.headerXML == xml )
    }

    @Test
    func parsesHeaderRegardlessOfAttachment() async throws
    {
        let xml        = "<?xml version=\"1.0\"?><xisf version=\"1.0\"/>"
        let attachment = Data( [ 0xDE, 0xAD, 0xBE, 0xEF ] )
        let raw        = Test_XISFFile.monolithicFile( xml: xml, attachment: attachment )
        let file       = try XISFFile( data: raw, options: .strict )

        // Bytes following the header do not affect header parsing.
        #expect( file.headerXML == xml )
    }

    @Test
    func rejectsBadSignature() async throws
    {
        let raw = Test_XISFFile.monolithicFile( signature: "XISF0101" )

        try #require( throws: XISFError.self ) { try XISFFile( data: raw, options: .strict ) }
    }

    @Test
    func rejectsEmptyData() async throws
    {
        try #require( throws: XISFError.self ) { try XISFFile( data: Data(), options: .strict ) }
    }

    @Test
    func rejectsTruncatedFile() async throws
    {
        try #require( throws: XISFError.self ) { try XISFFile( data: Data( "XISF".utf8 ),     options: .strict ) }
        try #require( throws: XISFError.self ) { try XISFFile( data: Data( "XISF0100".utf8 ), options: .strict ) }
    }

    @Test
    func rejectsNonZeroReservedWhenStrict() async throws
    {
        let raw = Test_XISFFile.monolithicFile( reserved: 1 )

        try #require( throws: XISFError.self ) { try XISFFile( data: raw, options: .strict ) }
    }

    @Test
    func toleratesNonZeroReservedWhenLenient() async throws
    {
        let raw  = Test_XISFFile.monolithicFile( reserved: 1 )
        let file = try XISFFile( data: raw, options: .lenient )

        #expect( file.headerXML.isEmpty == false )
    }

    @Test
    func rejectsHeaderLengthPastEndOfFile() async throws
    {
        let raw = Test_XISFFile.monolithicFile( headerLength: 100_000 )

        try #require( throws: XISFError.self ) { try XISFFile( data: raw, options: .strict ) }
    }

    @Test
    func rejectsZeroHeaderLength() async throws
    {
        let raw = Test_XISFFile.monolithicFile( headerLength: 0 )

        try #require( throws: XISFError.self ) { try XISFFile( data: raw, options: .strict ) }
    }

    @Test
    func readsFromURL() async throws
    {
        let raw = Test_XISFFile.monolithicFile()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent( "Test_XISFFile_\( UUID().uuidString ).xisf" )

        try raw.write( to: url )

        defer { try? FileManager.default.removeItem( at: url ) }

        let file = try XISFFile( url: url, options: .strict )

        #expect( file.headerXML.isEmpty == false )
    }

    @Test
    func rejectsMissingURL() async throws
    {
        let url = URL( fileURLWithPath: "/nonexistent/path/\( UUID().uuidString ).xisf" )

        try #require( throws: XISFError.self ) { try XISFFile( url: url, options: .strict ) }
    }
}
