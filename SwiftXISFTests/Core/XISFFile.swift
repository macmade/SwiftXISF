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

    @Test
    func resolvesHeaderRelativeExternalImageFromURL() async throws
    {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent( "Test_XISFFile_\( UUID().uuidString )", isDirectory: true )

        try FileManager.default.createDirectory( at: directory, withIntermediateDirectories: true )

        defer { try? FileManager.default.removeItem( at: directory ) }

        // A 2x2:1 UInt8 image whose pixels live in an adjacent external file,
        // located relative to the header file's directory.
        let xml    = "<xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\"><Image geometry=\"2:2:1\" sampleFormat=\"UInt8\" location=\"path(@header_dir/pixels.bin)\"/></xisf>"
        let header = directory.appendingPathComponent( "image.xisf" )
        let pixels = directory.appendingPathComponent( "pixels.bin" )

        try Test_XISFFile.monolithicFile( xml: xml ).write( to: header )
        try Data( [ 0x01, 0x02, 0x03, 0x04 ] ).write( to: pixels )

        let file = try XISFFile( url: header, options: [ .allowExternalLocations ] )

        #expect( try file.images.first?.data == Data( [ 0x01, 0x02, 0x03, 0x04 ] ) )
    }

    @Test
    func rejectsExternalImageWhenResolutionDisabled() async throws
    {
        let xml  = "<xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\"><Image geometry=\"2:2:1\" sampleFormat=\"UInt8\" location=\"path(/nonexistent/pixels.bin)\"/></xisf>"
        let file = try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict )

        // Opening succeeds (external resolution is lazy); reading the pixels
        // fails because external resolution is disabled by default.
        try #require( throws: XISFError.self ) { _ = try file.images.first?.data }
    }

    @Test
    func exposesTopLevelElementNames() async throws
    {
        let xml  = "<xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\"><Image geometry=\"1:1:1\" sampleFormat=\"UInt8\" location=\"inline:hex\">01</Image><Property id=\"a\" type=\"Int32\" value=\"1\"/><FITSKeyword name=\"A\" value=\"1\"/></xisf>"
        let file = try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict )

        #expect( file.headerElementNames == [ "Image", "Property", "FITSKeyword" ] )
    }

    @Test
    func exposesPropertiesAndKeywords() async throws
    {
        let xml  = "<xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\"><Property id=\"A\" type=\"Int32\" value=\"1\"/><Property id=\"B\" type=\"String\">hi</Property><FITSKeyword name=\"EXPTIME\" value=\"10\" comment=\"exp\"/><FITSKeyword name=\"HISTORY\" value=\"\" comment=\"x\"/></xisf>"
        let file = try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict )

        #expect( file.properties.count       == 2 )
        #expect( file[ "A" ]?.value          == .integer( 1 ) )
        #expect( file[ "B" ]?.value          == .string( "hi" ) )
        #expect( file[ "missing" ]           == nil )
        #expect( file.keywords.count         == 2 )
        #expect( file.keywords( named: "EXPTIME" ).count == 1 )
        #expect( file.keywords( named: "EXPTIME" ).first?.value == "10" )
    }

    @Test
    func parsesDataBlockBackedProperties() async throws
    {
        let xml  = "<xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\"><Property id=\"V\" type=\"UI8Vector\" length=\"3\" location=\"inline:base64\">AAEC</Property><Property id=\"S\" type=\"Int32\" value=\"5\"/></xisf>"
        let file = try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict )

        // Vector/matrix properties are resolved through the data-block pipeline.
        #expect( file.properties.count == 2 )
        #expect( file[ "S" ]?.value    == .integer( 5 ) )
        #expect( file[ "V" ]?.type     == .ui8Vector )
        #expect( file[ "V" ]?.length   == 3 )
        #expect( file[ "V" ]?.value    == .data( Data( [ 0x00, 0x01, 0x02 ] ) ) )
    }

    @Test
    func exposesImages() async throws
    {
        let xml  = "<xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\"><Image geometry=\"2:2:1\" sampleFormat=\"UInt8\" location=\"inline:hex\">01020304</Image></xisf>"
        let file = try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict )

        #expect( file.images.count            == 1 )
        #expect( file.images.first?.sampleFormat == .uInt8 )
        #expect( try file.images.first?.data  == Data( [ 0x01, 0x02, 0x03, 0x04 ] ) )
    }

    @Test
    func exposesMultipleImages() async throws
    {
        let xml  = "<xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\"><Image geometry=\"1:1:1\" sampleFormat=\"UInt8\" location=\"inline:hex\">01</Image><Image geometry=\"1:1:1\" sampleFormat=\"UInt8\" location=\"inline:hex\">02</Image></xisf>"
        let file = try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict )

        #expect( file.images.count == 2 )
    }

    @Test
    func exposesUnitLevelMetadata() async throws
    {
        let xml  = "<xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\"><Metadata><Property id=\"XISF:CreatorApplication\" type=\"String\">PixInsight</Property></Metadata></xisf>"
        let file = try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict )

        #expect( file.metadata?.properties.count == 1 )
        #expect( file.metadata?[ "XISF:CreatorApplication" ]?.value == .string( "PixInsight" ) )
    }

    @Test
    func hasNilMetadataWhenAbsent() async throws
    {
        let xml  = "<xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\"/>"
        let file = try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict )

        #expect( file.metadata == nil )
    }

    @Test
    func rejectsWrongRoot() async throws
    {
        let xml = "<notxisf version=\"1.0\"/>"

        try #require( throws: XISFError.self ) { try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict ) }
    }

    @Test
    func rejectsMissingVersionWhenStrict() async throws
    {
        let xml = "<xisf xmlns=\"http://www.pixinsight.com/xisf\"/>"

        try #require( throws: XISFError.self ) { try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict ) }
    }

    @Test
    func toleratesMissingVersionWhenLenient() async throws
    {
        let xml  = "<xisf xmlns=\"http://www.pixinsight.com/xisf\"/>"
        let file = try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .lenient )

        #expect( file.headerElementNames.isEmpty )
    }

    @Test
    func rejectsForeignNamespace() async throws
    {
        let xml = "<xisf version=\"1.0\" xmlns=\"http://example.com/other\"/>"

        try #require( throws: XISFError.self ) { try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict ) }
    }

    @Test
    func parsesNonNamespacedHeader() async throws
    {
        let xml  = "<xisf version=\"1.0\"><Image geometry=\"1:1:1\" sampleFormat=\"UInt8\" location=\"inline:hex\">01</Image></xisf>"
        let file = try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict )

        #expect( file.headerElementNames == [ "Image" ] )
    }

    @Test
    func rejectsMalformedHeaderXML() async throws
    {
        let xml = "<xisf version=\"1.0\"><unclosed></xisf>"

        try #require( throws: XISFError.self ) { try XISFFile( data: Test_XISFFile.monolithicFile( xml: xml ), options: .strict ) }
    }
}
