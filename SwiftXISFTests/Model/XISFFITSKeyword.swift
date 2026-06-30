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

struct Test_XISFFITSKeyword
{
    private static func element( _ xml: String ) throws -> XISFElement
    {
        try XISFXMLParser.parse( xml )
    }

    @Test
    func parsesKeyword() async throws
    {
        let keyword = try XISFFITSKeyword( element: Test_XISFFITSKeyword.element( "<FITSKeyword name=\"EXPTIME\" value=\"10.0\" comment=\"exposure time\"/>" ), options: .strict )

        #expect( keyword.name    == "EXPTIME" )
        #expect( keyword.value   == "10.0" )
        #expect( keyword.comment == "exposure time" )
    }

    @Test
    func emptyValueBecomesNil() async throws
    {
        let keyword = try XISFFITSKeyword( element: Test_XISFFITSKeyword.element( "<FITSKeyword name=\"HISTORY\" value=\"\" comment=\"processed\"/>" ), options: .strict )

        #expect( keyword.name    == "HISTORY" )
        #expect( keyword.value   == nil )
        #expect( keyword.comment == "processed" )
    }

    @Test
    func rejectsMissingName() async throws
    {
        try #require( throws: XISFError.self ) { try XISFFITSKeyword( element: Test_XISFFITSKeyword.element( "<FITSKeyword value=\"x\"/>" ), options: .strict ) }
    }

    @Test
    func validatesNameLengthAccordingToOptions() async throws
    {
        let element = try Test_XISFFITSKeyword.element( "<FITSKeyword name=\"TOOLONGNAME\" value=\"1\"/>" )

        try #require( throws: XISFError.self ) { try XISFFITSKeyword( element: element, options: .strict ) }

        #expect( try XISFFITSKeyword( element: element, options: .lenient ).name == "TOOLONGNAME" )
    }

    @Test
    func validatesNameCharsetAccordingToOptions() async throws
    {
        let element = try Test_XISFFITSKeyword.element( "<FITSKeyword name=\"lower\" value=\"1\"/>" )

        try #require( throws: XISFError.self ) { try XISFFITSKeyword( element: element, options: .strict ) }

        #expect( try XISFFITSKeyword( element: element, options: .lenient ).name == "lower" )
    }
}
