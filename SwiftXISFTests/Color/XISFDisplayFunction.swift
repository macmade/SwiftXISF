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

struct Test_XISFDisplayFunction
{
    private static func displayFunction( _ xml: String, options: XISFParsingOptions = .strict ) throws -> XISFDisplayFunction
    {
        try XISFDisplayFunction( element: XISFXMLParser.parse( xml ), options: options )
    }

    @Test
    func parsesAllComponentVectorsAndName() throws
    {
        let xml = "<DisplayFunction m=\"0.5:0.5:0.5:0.5\" s=\"0:0:0:0\" h=\"1:1:1:1\" l=\"0:0:0:0\" r=\"1:1:1:1\" name=\"AutoStretch\"/>"
        let df  = try Test_XISFDisplayFunction.displayFunction( xml )

        #expect( df.midtonesBalance     == XISFDisplayFunction.Components( rk: 0.5, g: 0.5, b: 0.5, l: 0.5 ) )
        #expect( df.shadowsClipping     == XISFDisplayFunction.Components( rk: 0,   g: 0,   b: 0,   l: 0 ) )
        #expect( df.highlightsClipping  == XISFDisplayFunction.Components( rk: 1,   g: 1,   b: 1,   l: 1 ) )
        #expect( df.shadowsExpansion    == XISFDisplayFunction.Components( rk: 0,   g: 0,   b: 0,   l: 0 ) )
        #expect( df.highlightsExpansion == XISFDisplayFunction.Components( rk: 1,   g: 1,   b: 1,   l: 1 ) )
        #expect( df.name                == "AutoStretch" )
    }

    @Test
    func rejectsMissingMandatoryAttributes() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFDisplayFunction.displayFunction( "<DisplayFunction s=\"0:0:0:0\" h=\"1:1:1:1\" l=\"0:0:0:0\" r=\"1:1:1:1\"/>" ) }
    }

    @Test
    func rejectsWrongComponentCount() async throws
    {
        // m has only three components instead of four.
        try #require( throws: XISFError.self ) { try Test_XISFDisplayFunction.displayFunction( "<DisplayFunction m=\"0.5:0.5:0.5\" s=\"0:0:0:0\" h=\"1:1:1:1\" l=\"0:0:0:0\" r=\"1:1:1:1\"/>" ) }
    }
}
