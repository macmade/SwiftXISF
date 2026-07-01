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

/// Confirms that every public type provides a `CustomStringConvertible`
/// description, mirroring SwiftFITS, where every public type is describable.
///
/// The spec-valued enums describe as their raw value; the aggregate types
/// describe as a readable, non-empty summary.
struct Test_Descriptions
{
    // MARK: - Spec-valued enums (description == raw value)

    @Test
    func byteOrderDescription() async throws
    {
        XISFByteOrder.allCases.forEach { #expect( $0.description == $0.rawValue ) }

        #expect( XISFByteOrder.little.description == "little" )
    }

    @Test
    func colorSpaceDescription() async throws
    {
        XISFColorSpace.allCases.forEach { #expect( $0.description == $0.rawValue ) }

        #expect( XISFColorSpace.rgb.description == "RGB" )
    }

    @Test
    func pixelStorageDescription() async throws
    {
        XISFPixelStorage.allCases.forEach { #expect( $0.description == $0.rawValue ) }

        #expect( XISFPixelStorage.planar.description == "Planar" )
    }

    @Test
    func sampleFormatDescription() async throws
    {
        XISFSampleFormat.allCases.forEach { #expect( $0.description == $0.rawValue ) }

        #expect( XISFSampleFormat.float32.description == "Float32" )
    }

    @Test
    func propertyTypeDescription() async throws
    {
        XISFPropertyType.allCases.forEach { #expect( $0.description == $0.rawValue ) }

        #expect( XISFPropertyType.ui8Vector.description == "UI8Vector" )
    }

    // MARK: - Geometry & data-block location (structured summaries)

    @Test
    func geometryDescription() async throws
    {
        #expect( try XISFGeometry( attribute: "2159:3839:3" ).description == "2159:3839:3" )
        #expect( try XISFGeometry( attribute: "4:4:4:1"     ).description == "4:4:4:1"     )
    }

    @Test
    func dataBlockLocationDescription() async throws
    {
        #expect( XISFDataBlockLocation.inline( encoding: .base64 ).description     == "inline:base64" )
        #expect( XISFDataBlockLocation.inline( encoding: .hex ).description         == "inline:hex" )
        #expect( XISFDataBlockLocation.embedded.description                         == "embedded" )
        #expect( XISFDataBlockLocation.attachment( position: 4570, size: 1428362 ).description == "attachment:4570:1428362" )
        #expect( XISFDataBlockLocation.absolutePath( "/data/x.bin", indexID: nil ).description == "path(/data/x.bin)" )
        #expect( XISFDataBlockLocation.absolutePath( "/data/x.bin", indexID: 5 ).description   == "path(/data/x.bin):5" )
        #expect( XISFDataBlockLocation.headerRelativePath( "rel/x.bin", indexID: nil ).description == "path(@header_dir/rel/x.bin)" )
    }

    @Test
    func dataBlockDescription() async throws
    {
        let element = try XISFXMLParser.parse( "<Image location=\"inline:base64\">SGVsbG8=</Image>" )
        let block   = try XISFDataBlock( element: element, fileData: Data(), baseURL: nil, options: .strict )

        #expect( block.description.contains( "inline:base64" ) )
        #expect( block.description.contains( "compression: none" ) )
        #expect( block.description.contains( "checksum: none" ) )
    }

    // MARK: - Types with public initializers

    @Test
    func checksumAndCompressionDescriptions() async throws
    {
        #expect( try XISFChecksum( attribute: "sha-1:0123456789abcdef0123456789abcdef01234567" ).description.isEmpty == false )
        #expect( try XISFCompression( attribute: "zlib:1000" ).description.isEmpty == false )
    }

    @Test
    func colorTypesWithElementInitDescriptions() async throws
    {
        let rgbws = try XISFRGBWorkingSpace(
            element: XISFXMLParser.parse( "<RGBWorkingSpace x=\"0.64:0.3:0.15\" y=\"0.33:0.6:0.06\" Y=\"0.2126:0.7152:0.0722\" gamma=\"2.2\"/>" ),
            options: .strict
        )

        let cfa = try XISFColorFilterArray(
            element: XISFXMLParser.parse( "<ColorFilterArray pattern=\"RGGB\" width=\"2\" height=\"2\"/>" ),
            options: .strict
        )

        #expect( rgbws.description.isEmpty == false )
        #expect( cfa.description.isEmpty == false )
    }

    // MARK: - Aggregate types parsed from a synthetic unit

    /// A synthetic monolithic unit exercising the full complement of describable
    /// public types: an image carrying every ancillary element, plus unit-level
    /// metadata.
    private static func richFile() throws -> XISFFile
    {
        let pixels = "0102030405060708090a0b0c" // 2 x 2 x 3 UInt8 = 12 bytes
        let xml    = """
        <xisf version="1.0" xmlns="http://www.pixinsight.com/xisf">\
        <Image geometry="2:2:3" sampleFormat="UInt8" colorSpace="RGB" location="inline:hex">\(pixels)\
        <Resolution horizontal="72" vertical="72" unit="inch"/>\
        <DisplayFunction m="0.5:0.5:0.5:0.5" s="0:0:0:0" h="1:1:1:1" l="0:0:0:0" r="1:1:1:1"/>\
        <RGBWorkingSpace x="0.64:0.3:0.15" y="0.33:0.6:0.06" Y="0.2126:0.7152:0.0722" gamma="2.2"/>\
        <ColorFilterArray pattern="RGGB" width="2" height="2"/>\
        <ICCProfile location="inline:base64">AAAA</ICCProfile>\
        <Thumbnail geometry="2:2:3" sampleFormat="UInt8" colorSpace="RGB" location="inline:hex">\(pixels)</Thumbnail>\
        <Property id="Image:Prop" type="Int32" value="7"/>\
        <FITSKeyword name="EXPTIME" value="30.0" comment="exp"/>\
        </Image>\
        <Metadata><Property id="XISF:CreatorApplication" type="String">PixInsight</Property></Metadata>\
        </xisf>
        """

        return try XISFFile( data: TestUtilities.monolithicFile( xml: xml ), options: .strict )
    }

    @Test
    func aggregateTypeDescriptions() async throws
    {
        let file  = try Test_Descriptions.richFile()
        let image = try #require( file.images.first )

        #expect( file.description.isEmpty  == false )
        #expect( image.description.isEmpty == false )

        #expect( try #require( image.resolution ).description.isEmpty      == false )
        #expect( try #require( image.displayFunction ).description.isEmpty  == false )
        #expect( try #require( image.rgbWorkingSpace ).description.isEmpty  == false )
        #expect( try #require( image.colorFilterArray ).description.isEmpty == false )
        #expect( try #require( image.iccProfile ).description.isEmpty       == false )
        #expect( try #require( image.thumbnail ).description.isEmpty        == false )

        #expect( try #require( image.properties.first ).description.isEmpty == false )
        #expect( try #require( image.keywords.first ).description.isEmpty   == false )

        #expect( try #require( file.metadata ).description.isEmpty == false )
    }
}
