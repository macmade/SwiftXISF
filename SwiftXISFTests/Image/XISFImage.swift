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

struct Test_XISFImage
{
    private static func image( _ xml: String, fileData: Data = Data(), options: XISFParsingOptions = .strict ) throws -> XISFImage
    {
        try XISFImage( element: XISFXMLParser.parse( xml ), fileData: fileData, options: options )
    }

    @Test
    func parsesGrayUInt8Image() throws
    {
        let image = try Test_XISFImage.image( "<Image geometry=\"2:2:1\" sampleFormat=\"UInt8\" colorSpace=\"Gray\" location=\"inline:hex\">01020304</Image>" )

        #expect( image.geometry.dimensions   == [ 2, 2 ] )
        #expect( image.geometry.channelCount == 1 )
        #expect( image.sampleFormat          == .uInt8 )
        #expect( image.colorSpace            == .gray )
        #expect( try image.data              == Data( [ 0x01, 0x02, 0x03, 0x04 ] ) )
    }

    @Test
    func appliesDefaultsWhenAttributesAbsent() throws
    {
        let image = try Test_XISFImage.image( "<Image geometry=\"2:2:1\" sampleFormat=\"UInt8\" location=\"inline:hex\">01020304</Image>" )

        #expect( image.colorSpace   == .gray )
        #expect( image.pixelStorage == .planar )
        #expect( image.byteOrder    == .little )
        #expect( image.bounds       == nil )
    }

    @Test
    func parsesRGBWithPlanarAndNormalStorage() throws
    {
        let planar = try Test_XISFImage.image( "<Image geometry=\"1:1:3\" sampleFormat=\"UInt8\" colorSpace=\"RGB\" pixelStorage=\"Planar\" location=\"inline:hex\">010203</Image>" )
        let normal = try Test_XISFImage.image( "<Image geometry=\"1:1:3\" sampleFormat=\"UInt8\" colorSpace=\"RGB\" pixelStorage=\"Normal\" location=\"inline:hex\">010203</Image>" )

        #expect( planar.colorSpace   == .rgb )
        #expect( planar.pixelStorage == .planar )
        #expect( normal.pixelStorage == .normal )
    }

    @Test
    func parsesFloatImageWithBounds() throws
    {
        let image = try Test_XISFImage.image( "<Image geometry=\"1:1:1\" sampleFormat=\"Float32\" byteOrder=\"little\" bounds=\"0:1\" location=\"inline:hex\">0000803f</Image>" )

        #expect( image.sampleFormat == .float32 )
        #expect( image.byteOrder    == .little )
        #expect( image.bounds       == 0.0 ... 1.0 )
        #expect( try image.data     == Data( [ 0x00, 0x00, 0x80, 0x3F ] ) )
    }

    @Test
    func requiresBoundsForFloatingPointWhenStrict() async throws
    {
        try #require( throws: XISFError.self )
        {
            try Test_XISFImage.image( "<Image geometry=\"1:1:1\" sampleFormat=\"Float32\" location=\"inline:hex\">0000803f</Image>" )
        }
    }

    @Test
    func toleratesMissingBoundsForFloatingPointWhenLenient() throws
    {
        let image = try Test_XISFImage.image( "<Image geometry=\"1:1:1\" sampleFormat=\"Float32\" location=\"inline:hex\">0000803f</Image>", options: .lenient )

        #expect( image.bounds == nil )
    }

    @Test
    func rejectsPixelSizeMismatchWhenStrict() async throws
    {
        // geometry 2:2:1 UInt8 expects 4 bytes; only 3 are provided.
        try #require( throws: XISFError.self )
        {
            try Test_XISFImage.image( "<Image geometry=\"2:2:1\" sampleFormat=\"UInt8\" location=\"inline:hex\">010203</Image>" )
        }
    }

    @Test
    func parsesOptionalIdentityAttributes() throws
    {
        let image = try Test_XISFImage.image( "<Image geometry=\"2:2:1\" sampleFormat=\"UInt8\" id=\"main\" uuid=\"abc-123\" imageType=\"Light\" orientation=\"0\" location=\"inline:hex\">01020304</Image>" )

        #expect( image.id          == "main" )
        #expect( image.uuid        == "abc-123" )
        #expect( image.imageType   == "Light" )
        #expect( image.orientation == "0" )
    }

    @Test
    func parsesNestedPropertiesAndKeywords() throws
    {
        let xml   = "<Image geometry=\"2:2:1\" sampleFormat=\"UInt8\" location=\"embedded\"><Data encoding=\"hex\">01020304</Data><Property id=\"P\" type=\"Int32\" value=\"7\"/><FITSKeyword name=\"EXPTIME\" value=\"1.0\" comment=\"exposure\"/></Image>"
        let image = try Test_XISFImage.image( xml )

        #expect( image.properties.count       == 1 )
        #expect( image.properties.first?.value == .integer( 7 ) )
        #expect( image.keywords.count         == 1 )
        #expect( image.keywords.first?.name   == "EXPTIME" )
        #expect( try image.data               == Data( [ 0x01, 0x02, 0x03, 0x04 ] ) )
    }

    @Test
    func rejectsMissingGeometryOrSampleFormat() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFImage.image( "<Image sampleFormat=\"UInt8\" location=\"inline:hex\">01</Image>" ) }
        try #require( throws: XISFError.self ) { try Test_XISFImage.image( "<Image geometry=\"1:1:1\" location=\"inline:hex\">01</Image>" ) }
    }
}
