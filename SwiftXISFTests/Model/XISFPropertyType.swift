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

struct Test_XISFPropertyType
{
    @Test
    func scalarRawValues() async throws
    {
        #expect( XISFPropertyType( rawValue: "Boolean" )   == .boolean )
        #expect( XISFPropertyType( rawValue: "Int8" )      == .int8 )
        #expect( XISFPropertyType( rawValue: "UInt8" )     == .uint8 )
        #expect( XISFPropertyType( rawValue: "Int64" )     == .int64 )
        #expect( XISFPropertyType( rawValue: "UInt64" )    == .uint64 )
        #expect( XISFPropertyType( rawValue: "Float32" )   == .float32 )
        #expect( XISFPropertyType( rawValue: "Float64" )   == .float64 )
        #expect( XISFPropertyType( rawValue: "Complex32" ) == .complex32 )
        #expect( XISFPropertyType( rawValue: "Complex64" ) == .complex64 )
        #expect( XISFPropertyType( rawValue: "String" )    == .string )
        #expect( XISFPropertyType( rawValue: "TimePoint" ) == .timePoint )
    }

    @Test
    func vectorAndMatrixRawValues() async throws
    {
        #expect( XISFPropertyType( rawValue: "ByteArray" )  == .byteArray )
        #expect( XISFPropertyType( rawValue: "I8Vector" )   == .i8Vector )
        #expect( XISFPropertyType( rawValue: "UI8Vector" )  == .ui8Vector )
        #expect( XISFPropertyType( rawValue: "UI16Vector" ) == .ui16Vector )
        #expect( XISFPropertyType( rawValue: "F64Vector" )  == .f64Vector )
        #expect( XISFPropertyType( rawValue: "C64Vector" )  == .c64Vector )
        #expect( XISFPropertyType( rawValue: "I32Matrix" )  == .i32Matrix )
        #expect( XISFPropertyType( rawValue: "F32Matrix" )  == .f32Matrix )
        #expect( XISFPropertyType( rawValue: "C64Matrix" )  == .c64Matrix )
    }

    @Test
    func rejectsUnknownTypeStrings() async throws
    {
        // Complex128 / C128 do not exist in XISF 1.0.
        #expect( XISFPropertyType( rawValue: "Complex128" ) == nil )
        #expect( XISFPropertyType( rawValue: "C128Vector" ) == nil )
        #expect( XISFPropertyType( rawValue: "Int128" )     == nil )
        #expect( XISFPropertyType( rawValue: "Float128" )   == nil )
        #expect( XISFPropertyType( rawValue: "boolean" )    == nil )
        #expect( XISFPropertyType( rawValue: "Nonsense" )   == nil )
    }

    @Test
    func category() async throws
    {
        #expect( XISFPropertyType.boolean.category   == .scalar )
        #expect( XISFPropertyType.int32.category     == .scalar )
        #expect( XISFPropertyType.float64.category   == .scalar )
        #expect( XISFPropertyType.complex32.category == .complex )
        #expect( XISFPropertyType.string.category    == .string )
        #expect( XISFPropertyType.timePoint.category == .timePoint )
        #expect( XISFPropertyType.byteArray.category == .vector )
        #expect( XISFPropertyType.ui8Vector.category == .vector )
        #expect( XISFPropertyType.f32Matrix.category == .matrix )
    }
}
