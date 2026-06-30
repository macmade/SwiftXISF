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

struct Test_String
{
    @Test
    func hexDecodedData() async throws
    {
        #expect( try "48656c6c6f".xisfHexDecodedData()        == Data( "Hello".utf8 ) )
        #expect( try "48656C6C6F".xisfHexDecodedData()        == Data( "Hello".utf8 ) )
        #expect( try "48 65\n6c\t6c6f".xisfHexDecodedData()   == Data( "Hello".utf8 ) )
        #expect( try "".xisfHexDecodedData()                  == Data() )
    }

    @Test
    func hexDecodedDataRejectsMalformed() async throws
    {
        try #require( throws: XISFError.self ) { try "abc".xisfHexDecodedData() }
        try #require( throws: XISFError.self ) { try "zz".xisfHexDecodedData() }
        try #require( throws: XISFError.self ) { try "4g".xisfHexDecodedData() }
    }

    @Test
    func base64DecodedData() async throws
    {
        #expect( try "SGVsbG8=".xisfBase64DecodedData()       == Data( "Hello".utf8 ) )
        #expect( try "SGVs\nbG8=".xisfBase64DecodedData()     == Data( "Hello".utf8 ) )
    }

    @Test
    func base64DecodedDataRejectsMalformed() async throws
    {
        try #require( throws: XISFError.self ) { try "A".xisfBase64DecodedData() }
    }

    @Test
    func isValidXISFIdentifier() async throws
    {
        #expect( "foo".isValidXISFIdentifier        == true )
        #expect( "_bar9".isValidXISFIdentifier      == true )
        #expect( "Good_Name1".isValidXISFIdentifier == true )
        #expect( "_".isValidXISFIdentifier          == true )

        #expect( "9bad".isValidXISFIdentifier       == false )
        #expect( "".isValidXISFIdentifier           == false )
        #expect( "has space".isValidXISFIdentifier  == false )
        #expect( "dash-name".isValidXISFIdentifier  == false )
    }
}
