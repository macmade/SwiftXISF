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

    /// Parses a property from an XML string, with no attached file bytes (inline
    /// data blocks need none).
    private static func property( _ xml: String, options: XISFParsingOptions = .strict ) throws -> XISFProperty
    {
        try XISFProperty( element: Test_XISFProperty.element( xml ), fileData: Data(), baseURL: nil, options: options )
    }

    @Test
    func parsesScalarProperty() async throws
    {
        let property = try Test_XISFProperty.property( "<Property id=\"Observation:Time:Start\" type=\"Int32\" value=\"42\" comment=\"a comment\" format=\"%d\"/>" )

        #expect( property.id      == "Observation:Time:Start" )
        #expect( property.type    == .int32 )
        #expect( property.value   == .integer( 42 ) )
        #expect( property.comment == "a comment" )
        #expect( property.format  == "%d" )
    }

    @Test
    func parsesInlineStringProperty() async throws
    {
        let property = try Test_XISFProperty.property( "<Property id=\"Title\" type=\"String\">Hello, world</Property>" )

        #expect( property.type  == .string )
        #expect( property.value == .string( "Hello, world" ) )
    }

    @Test
    func parsesScalarKinds() async throws
    {
        #expect( try Test_XISFProperty.property( "<Property id=\"a\" type=\"Boolean\" value=\"true\"/>" ).value    == .boolean( true ) )
        #expect( try Test_XISFProperty.property( "<Property id=\"a\" type=\"Float64\" value=\"1.5\"/>" ).value     == .float( 1.5 ) )
        #expect( try Test_XISFProperty.property( "<Property id=\"a\" type=\"Complex64\" value=\"(1,2)\"/>" ).value == .complex( real: 1, imaginary: 2 ) )
        #expect( try Test_XISFProperty.property( "<Property id=\"a\" type=\"UInt16\" value=\"65535\"/>" ).value    == .unsignedInteger( 65535 ) )
    }

    @Test
    func optionalCommentAndFormatDefaultToNil() async throws
    {
        let property = try Test_XISFProperty.property( "<Property id=\"a\" type=\"Int32\" value=\"1\"/>" )

        #expect( property.comment == nil )
        #expect( property.format  == nil )
    }

    @Test
    func rejectsMissingId() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFProperty.property( "<Property type=\"Int32\" value=\"1\"/>" ) }
    }

    @Test
    func rejectsMissingType() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFProperty.property( "<Property id=\"a\" value=\"1\"/>" ) }
    }

    @Test
    func rejectsUnknownType() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFProperty.property( "<Property id=\"a\" type=\"Complex128\" value=\"(1,2)\"/>" ) }
    }

    @Test
    func rejectsMissingValueForScalar() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFProperty.property( "<Property id=\"a\" type=\"Int32\"/>" ) }
    }

    @Test
    func validatesIdAccordingToOptions() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFProperty.property( "<Property id=\"9bad\" type=\"Int32\" value=\"1\"/>" ) }

        let lenient = try Test_XISFProperty.property( "<Property id=\"9bad\" type=\"Int32\" value=\"1\"/>", options: .lenient )

        #expect( lenient.id == "9bad" )
    }

    // MARK: - Data-block-backed values (vector / matrix / ByteArray / string)

    @Test
    func parsesVectorProperty() async throws
    {
        // Two little-endian Float32 samples (1.0, 2.0): 8 raw bytes.
        let property = try Test_XISFProperty.property( "<Property id=\"v\" type=\"F32Vector\" length=\"2\" location=\"inline:hex\">0000803f00000040</Property>" )

        #expect( property.type   == .f32Vector )
        #expect( property.length == 2 )
        #expect( property.value  == .data( Data( [ 0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x40 ] ) ) )
    }

    @Test
    func parsesByteArrayProperty() async throws
    {
        let property = try Test_XISFProperty.property( "<Property id=\"b\" type=\"ByteArray\" length=\"4\" location=\"inline:hex\">deadbeef</Property>" )

        #expect( property.type       == .byteArray )
        #expect( property.length     == 4 )
        #expect( property.value.data == Data( [ 0xDE, 0xAD, 0xBE, 0xEF ] ) )
    }

    @Test
    func parsesMatrixProperty() async throws
    {
        let property = try Test_XISFProperty.property( "<Property id=\"m\" type=\"UI8Matrix\" rows=\"2\" columns=\"2\" location=\"inline:hex\">01020304</Property>" )

        #expect( property.type    == .ui8Matrix )
        #expect( property.rows    == 2 )
        #expect( property.columns == 2 )
        #expect( property.value   == .data( Data( [ 0x01, 0x02, 0x03, 0x04 ] ) ) )
    }

    @Test
    func parsesStringPropertyCarriedInDataBlock() async throws
    {
        // A String value stored in a data block is decoded as UTF-8.
        let property = try Test_XISFProperty.property( "<Property id=\"s\" type=\"String\" location=\"inline:hex\">48656c6c6f</Property>" )

        #expect( property.value == .string( "Hello" ) )
    }
}
