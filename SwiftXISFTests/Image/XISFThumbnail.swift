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

struct Test_XISFThumbnail
{
    private static func thumbnail( _ xml: String, fileData: Data = Data(), options: XISFParsingOptions = .strict ) throws -> XISFThumbnail
    {
        try XISFThumbnail( element: XISFXMLParser.parse( xml ), fileData: fileData, options: options )
    }

    @Test
    func parsesRGBUInt8Thumbnail() throws
    {
        let thumbnail = try Test_XISFThumbnail.thumbnail( "<Thumbnail geometry=\"1:1:3\" sampleFormat=\"UInt8\" colorSpace=\"RGB\" location=\"inline:hex\">010203</Thumbnail>" )

        #expect( thumbnail.image.geometry.dimensions == [ 1, 1 ] )
        #expect( thumbnail.image.sampleFormat        == .uInt8 )
        #expect( thumbnail.image.colorSpace          == .rgb )
        #expect( try thumbnail.data                  == Data( [ 0x01, 0x02, 0x03 ] ) )
    }

    @Test
    func rejectsUnsupportedSampleFormatWhenStrict() async throws
    {
        // Float32 is not a permitted thumbnail sample format.
        try #require( throws: XISFError.self ) { try Test_XISFThumbnail.thumbnail( "<Thumbnail geometry=\"1:1:1\" sampleFormat=\"Float32\" bounds=\"0:1\" location=\"inline:hex\">0000803f</Thumbnail>" ) }
    }

    @Test
    func rejectsBoundsWhenStrict() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFThumbnail.thumbnail( "<Thumbnail geometry=\"1:1:1\" sampleFormat=\"UInt8\" bounds=\"0:1\" location=\"inline:hex\">01</Thumbnail>" ) }
    }

    @Test
    func rejectsChildColorFilterArrayWhenStrict() async throws
    {
        try #require( throws: XISFError.self )
        {
            try Test_XISFThumbnail.thumbnail( "<Thumbnail geometry=\"1:1:1\" sampleFormat=\"UInt8\" location=\"inline:hex\">01<ColorFilterArray pattern=\"RG\" width=\"2\" height=\"1\"/></Thumbnail>" )
        }
    }
}
