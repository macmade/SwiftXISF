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
    ///
    /// Delegates to the shared ``TestUtilities/monolithicFile(signature:headerLength:reserved:xml:attachment:)``
    /// builder so every test constructs synthetic files the same way.
    private static func monolithicFile( signature: String = XISFFile.signature, headerLength: UInt32? = nil, reserved: UInt32 = 0, xml: String = TestUtilities.defaultHeaderXML, attachment: Data = Data() ) -> Data
    {
        TestUtilities.monolithicFile( signature: signature, headerLength: headerLength, reserved: reserved, xml: xml, attachment: attachment )
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

    // MARK: - Real-fixture integration tests

    /// The plain autocrop fixture: an RGB integration image plus a Gray crop mask.
    private static var autocropFixture: URL?
    {
        TestUtilities.testFiles.first { $0.lastPathComponent.contains( "autocrop.xisf" ) }
    }

    /// The corrected fixture: a single RGB image carrying a thumbnail, ICC
    /// profile, resolution and display function.
    private static var correctedFixture: URL?
    {
        TestUtilities.testFiles.first { $0.lastPathComponent.contains( "corrected.xisf" ) }
    }

    @Test
    func parsesAllTestFiles() async throws
    {
        try #require( TestUtilities.testFiles.isEmpty == false )

        try TestUtilities.testFiles.forEach
        {
            let _ = try XISFFile( url: $0, options: .lenient )
        }
    }

    @Test
    func parsesAllTestFilesStrictly() async throws
    {
        try #require( TestUtilities.testFiles.isEmpty == false )

        try TestUtilities.testFiles.forEach
        {
            let _ = try XISFFile( url: $0, options: .strict )
        }
    }

    @Test
    func everyImageDeclaresConsistentGeometry() async throws
    {
        try TestUtilities.testFiles.forEach
        {
            let file = try XISFFile( url: $0, options: .lenient )

            file.images.forEach
            {
                #expect( $0.geometry.dimensions.isEmpty == false )
                #expect( $0.geometry.channelCount >= 1 )
                #expect( $0.geometry.sampleCount == $0.geometry.pixelCount * $0.geometry.channelCount )
                #expect( $0.sampleFormat.bytesPerSample >= 1 )
            }
        }
    }

    @Test
    func parsesAutocropFixture() async throws
    {
        let url  = try #require( Test_XISFFile.autocropFixture )
        let file = try XISFFile( url: url, options: .lenient )

        try #require( file.images.count == 2 )

        let integration = file.images[ 0 ]
        let mask        = file.images[ 1 ]

        #expect( integration.id                   == "integration_autocrop" )
        #expect( integration.geometry.dimensions  == [ 578, 1547 ] )
        #expect( integration.geometry.channelCount == 3 )
        #expect( integration.sampleFormat         == .float32 )
        #expect( integration.colorSpace           == .rgb )
        #expect( integration.byteOrder            == .little )
        #expect( integration.bounds               == 0.0 ... 1.0 )
        #expect( integration.keywords.count       == 28 )
        #expect( integration.properties.count     == 89 )

        #expect( mask.id                    == "crop_mask" )
        #expect( mask.geometry.dimensions   == [ 1080, 1920 ] )
        #expect( mask.geometry.channelCount == 1 )
        #expect( mask.sampleFormat          == .float32 )
        #expect( mask.colorSpace            == .gray )

        // A scalar property and a FITS keyword parsed from the real header.
        #expect( integration.properties.first { $0.id == "Instrument:Filter:Name" }?.value.string      == "LP" )
        #expect( integration.properties.first { $0.id == "Instrument:Sensor:XPixelSize" }?.value.float  == 2.9 )
        #expect( integration.keywords.first { $0.name == "FILTER" }?.value                              == "'LP'" )

        // The unit-level metadata element is present.
        #expect( file.metadata != nil )
        #expect( file.metadata?[ "XISF:CreatorApplication" ]?.value.string != nil )
    }

    @Test
    func parsesAutocropFixturePixelData() async throws
    {
        let url         = try #require( Test_XISFFile.autocropFixture )
        let file        = try XISFFile( url: url, options: .lenient )
        let integration = try #require( file.images.first )

        // The decoded opaque pixel bytes match geometry x bytes-per-sample.
        let expected = integration.geometry.sampleCount * integration.sampleFormat.bytesPerSample

        #expect( try integration.data.count == expected )
        #expect( expected == 578 * 1547 * 3 * 4 )
    }

    @Test
    func parsesCorrectedFixture() async throws
    {
        let url   = try #require( Test_XISFFile.correctedFixture )
        let file  = try XISFFile( url: url, options: .lenient )
        let image = try #require( file.images.first )

        try #require( file.images.count == 1 )

        #expect( image.id                    == "drizzle_integration" )
        #expect( image.geometry.dimensions   == [ 1080, 1920 ] )
        #expect( image.geometry.channelCount == 3 )
        #expect( image.sampleFormat          == .float32 )
        #expect( image.colorSpace            == .rgb )
        #expect( image.bounds                == 0.0 ... 1.0 )
        #expect( image.keywords.count        == 27 )

        // The corrected image carries the full complement of ancillary elements.
        #expect( image.thumbnail       != nil )
        #expect( image.iccProfile      != nil )
        #expect( image.resolution      != nil )
        #expect( image.displayFunction != nil )

        #expect( image.resolution?.horizontal == 72 )
        #expect( image.resolution?.vertical   == 72 )
        #expect( image.resolution?.unit       == .inch )

        // The thumbnail is a small 8-bit RGB image.
        let thumbnail = try #require( image.thumbnail )

        #expect( thumbnail.image.geometry.dimensions   == [ 225, 400 ] )
        #expect( thumbnail.image.geometry.channelCount == 3 )
        #expect( thumbnail.image.sampleFormat          == .uInt8 )
        #expect( thumbnail.image.colorSpace            == .rgb )

        #expect( file.metadata != nil )
    }

    @Test
    func decodesCorrectedFixtureAncillaryData() async throws
    {
        let url   = try #require( Test_XISFFile.correctedFixture )
        let file  = try XISFFile( url: url, options: .lenient )
        let image = try #require( file.images.first )

        // The inline ICC profile and the attached thumbnail decode to bytes.
        #expect( try image.iccProfile?.data.isEmpty == false )
        #expect( try image.thumbnail?.data.count == 225 * 400 * 3 )
    }
}
