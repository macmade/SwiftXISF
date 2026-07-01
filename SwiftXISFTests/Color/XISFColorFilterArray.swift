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

struct Test_XISFColorFilterArray
{
    private static func cfa( _ xml: String, options: XISFParsingOptions = .strict ) throws -> XISFColorFilterArray
    {
        try XISFColorFilterArray( element: XISFXMLParser.parse( xml ), options: options )
    }

    @Test
    func parsesPatternWidthHeightAndName() throws
    {
        let cfa = try Test_XISFColorFilterArray.cfa( "<ColorFilterArray pattern=\"GRBG\" width=\"2\" height=\"2\" name=\"GRBG Bayer Filter\"/>" )

        #expect( cfa.pattern  == "GRBG" )
        #expect( cfa.width    == 2 )
        #expect( cfa.height   == 2 )
        #expect( cfa.name     == "GRBG Bayer Filter" )
        #expect( cfa.elements == [ .green, .red, .blue, .green ] )
    }

    @Test
    func parsesAllPatternElements() throws
    {
        let cfa = try Test_XISFColorFilterArray.cfa( "<ColorFilterArray pattern=\"0RGBWCMY\" width=\"8\" height=\"1\"/>" )

        #expect( cfa.name     == nil )
        #expect( cfa.elements == [ .none, .red, .green, .blue, .white, .cyan, .magenta, .yellow ] )
    }

    @Test
    func rejectsMissingMandatoryAttributes() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFColorFilterArray.cfa( "<ColorFilterArray width=\"2\" height=\"2\"/>" ) }
        try #require( throws: XISFError.self ) { try Test_XISFColorFilterArray.cfa( "<ColorFilterArray pattern=\"GRBG\" height=\"2\"/>" ) }
    }

    @Test
    func rejectsInvalidPatternCharacterWhenStrict() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFColorFilterArray.cfa( "<ColorFilterArray pattern=\"GRXG\" width=\"2\" height=\"2\"/>" ) }
    }

    @Test
    func rejectsPatternLengthMismatchWhenStrict() async throws
    {
        // 3 pattern characters but width x height = 4.
        try #require( throws: XISFError.self ) { try Test_XISFColorFilterArray.cfa( "<ColorFilterArray pattern=\"GRB\" width=\"2\" height=\"2\"/>" ) }
    }

    @Test
    func rejectsNonPositiveDimensionsWhenStrict() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFColorFilterArray.cfa( "<ColorFilterArray pattern=\"\" width=\"0\" height=\"0\"/>" ) }
    }
}
