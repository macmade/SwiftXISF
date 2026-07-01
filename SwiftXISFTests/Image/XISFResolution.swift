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

struct Test_XISFResolution
{
    private static func resolution( _ xml: String, options: XISFParsingOptions = .strict ) throws -> XISFResolution
    {
        try XISFResolution( element: XISFXMLParser.parse( xml ), options: options )
    }

    @Test
    func parsesHorizontalVerticalAndUnit() throws
    {
        let resolution = try Test_XISFResolution.resolution( "<Resolution horizontal=\"120\" vertical=\"96\" unit=\"cm\"/>" )

        #expect( resolution.horizontal == 120 )
        #expect( resolution.vertical   == 96 )
        #expect( resolution.unit       == .centimeter )
    }

    @Test
    func defaultsToInchesWhenUnitAbsent() throws
    {
        let resolution = try Test_XISFResolution.resolution( "<Resolution horizontal=\"72\" vertical=\"72\"/>" )

        #expect( resolution.unit == .inch )
    }

    @Test
    func rejectsMissingMandatoryAttributes() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFResolution.resolution( "<Resolution vertical=\"72\"/>" ) }
        try #require( throws: XISFError.self ) { try Test_XISFResolution.resolution( "<Resolution horizontal=\"72\"/>" ) }
    }

    @Test
    func rejectsNonPositiveOrUnknownUnitWhenStrict() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFResolution.resolution( "<Resolution horizontal=\"0\" vertical=\"72\"/>" ) }
        try #require( throws: XISFError.self ) { try Test_XISFResolution.resolution( "<Resolution horizontal=\"72\" vertical=\"72\" unit=\"meters\"/>" ) }
    }

    @Test
    func tolersUnknownUnitWhenLenient() throws
    {
        let resolution = try Test_XISFResolution.resolution( "<Resolution horizontal=\"72\" vertical=\"72\" unit=\"meters\"/>", options: .lenient )

        #expect( resolution.unit == .inch )
    }
}
