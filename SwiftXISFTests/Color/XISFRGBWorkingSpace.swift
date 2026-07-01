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

struct Test_XISFRGBWorkingSpace
{
    private static func rgbws( _ xml: String, options: XISFParsingOptions = .strict ) throws -> XISFRGBWorkingSpace
    {
        try XISFRGBWorkingSpace( element: XISFXMLParser.parse( xml ), options: options )
    }

    @Test
    func parsesPrimariesLuminanceGammaAndName() throws
    {
        let xml   = "<RGBWorkingSpace x=\"0.64:0.30:0.15\" y=\"0.33:0.60:0.06\" Y=\"0.22:0.71:0.06\" gamma=\"2.2\" name=\"Adobe RGB (1998)\"/>"
        let rgbws = try Test_XISFRGBWorkingSpace.rgbws( xml )

        #expect( rgbws.x          == XISFRGBWorkingSpace.Primaries( red: 0.64, green: 0.30, blue: 0.15 ) )
        #expect( rgbws.y          == XISFRGBWorkingSpace.Primaries( red: 0.33, green: 0.60, blue: 0.06 ) )
        #expect( rgbws.luminance  == XISFRGBWorkingSpace.Primaries( red: 0.22, green: 0.71, blue: 0.06 ) )
        #expect( rgbws.gamma      == .exponent( 2.2 ) )
        #expect( rgbws.name       == "Adobe RGB (1998)" )
    }

    @Test
    func parsesSRGBGammaCaseInsensitively() throws
    {
        let rgbws = try Test_XISFRGBWorkingSpace.rgbws( "<RGBWorkingSpace x=\"0.64:0.30:0.15\" y=\"0.33:0.60:0.06\" Y=\"0.22:0.71:0.06\" gamma=\"sRGB\"/>" )

        #expect( rgbws.gamma == .sRGB )
        #expect( rgbws.name  == nil )
    }

    @Test
    func rejectsMissingMandatoryAttributes() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFRGBWorkingSpace.rgbws( "<RGBWorkingSpace y=\"0.33:0.60:0.06\" Y=\"0.22:0.71:0.06\" gamma=\"2.2\"/>" ) }
        try #require( throws: XISFError.self ) { try Test_XISFRGBWorkingSpace.rgbws( "<RGBWorkingSpace x=\"0.64:0.30:0.15\" y=\"0.33:0.60:0.06\" Y=\"0.22:0.71:0.06\"/>" ) }
    }

    @Test
    func rejectsMalformedTripletOrGamma() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFRGBWorkingSpace.rgbws( "<RGBWorkingSpace x=\"0.64:0.30\" y=\"0.33:0.60:0.06\" Y=\"0.22:0.71:0.06\" gamma=\"2.2\"/>" ) }
        try #require( throws: XISFError.self ) { try Test_XISFRGBWorkingSpace.rgbws( "<RGBWorkingSpace x=\"0.64:0.30:0.15\" y=\"0.33:0.60:0.06\" Y=\"0.22:0.71:0.06\" gamma=\"0\"/>" ) }
    }
}
