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

struct Test_XISFProperty
{
    private static func element( _ xml: String ) throws -> XISFElement
    {
        try XISFXMLParser.parse( xml )
    }

    @Test
    func parsesScalarProperty() async throws
    {
        let element  = try Test_XISFProperty.element( "<Property id=\"Observation:Time:Start\" type=\"Int32\" value=\"42\" comment=\"a comment\" format=\"%d\"/>" )
        let property = try XISFProperty( element: element, options: .strict )

        #expect( property.id      == "Observation:Time:Start" )
        #expect( property.type    == .int32 )
        #expect( property.value   == .integer( 42 ) )
        #expect( property.comment == "a comment" )
        #expect( property.format  == "%d" )
    }

    @Test
    func parsesInlineStringProperty() async throws
    {
        let element  = try Test_XISFProperty.element( "<Property id=\"Title\" type=\"String\">Hello, world</Property>" )
        let property = try XISFProperty( element: element, options: .strict )

        #expect( property.type  == .string )
        #expect( property.value == .string( "Hello, world" ) )
    }

    @Test
    func parsesScalarKinds() async throws
    {
        #expect( try XISFProperty( element: Test_XISFProperty.element( "<Property id=\"a\" type=\"Boolean\" value=\"true\"/>" ),        options: .strict ).value == .boolean( true ) )
        #expect( try XISFProperty( element: Test_XISFProperty.element( "<Property id=\"a\" type=\"Float64\" value=\"1.5\"/>" ),         options: .strict ).value == .float( 1.5 ) )
        #expect( try XISFProperty( element: Test_XISFProperty.element( "<Property id=\"a\" type=\"Complex64\" value=\"(1,2)\"/>" ),     options: .strict ).value == .complex( real: 1, imaginary: 2 ) )
        #expect( try XISFProperty( element: Test_XISFProperty.element( "<Property id=\"a\" type=\"UInt16\" value=\"65535\"/>" ),        options: .strict ).value == .unsignedInteger( 65535 ) )
    }

    @Test
    func optionalCommentAndFormatDefaultToNil() async throws
    {
        let property = try XISFProperty( element: Test_XISFProperty.element( "<Property id=\"a\" type=\"Int32\" value=\"1\"/>" ), options: .strict )

        #expect( property.comment == nil )
        #expect( property.format  == nil )
    }

    @Test
    func rejectsMissingId() async throws
    {
        try #require( throws: XISFError.self ) { try XISFProperty( element: Test_XISFProperty.element( "<Property type=\"Int32\" value=\"1\"/>" ), options: .strict ) }
    }

    @Test
    func rejectsMissingType() async throws
    {
        try #require( throws: XISFError.self ) { try XISFProperty( element: Test_XISFProperty.element( "<Property id=\"a\" value=\"1\"/>" ), options: .strict ) }
    }

    @Test
    func rejectsUnknownType() async throws
    {
        try #require( throws: XISFError.self ) { try XISFProperty( element: Test_XISFProperty.element( "<Property id=\"a\" type=\"Complex128\" value=\"(1,2)\"/>" ), options: .strict ) }
    }

    @Test
    func rejectsMissingValueForScalar() async throws
    {
        try #require( throws: XISFError.self ) { try XISFProperty( element: Test_XISFProperty.element( "<Property id=\"a\" type=\"Int32\"/>" ), options: .strict ) }
    }

    @Test
    func validatesIdAccordingToOptions() async throws
    {
        let element = try Test_XISFProperty.element( "<Property id=\"9bad\" type=\"Int32\" value=\"1\"/>" )

        try #require( throws: XISFError.self ) { try XISFProperty( element: element, options: .strict ) }

        let lenient = try XISFProperty( element: element, options: .lenient )

        #expect( lenient.id == "9bad" )
    }
}
