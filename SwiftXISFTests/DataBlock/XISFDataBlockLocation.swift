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

struct Test_XISFDataBlockLocation
{
    @Test
    func parsesInline() async throws
    {
        #expect( try XISFDataBlockLocation( attribute: "inline:base64" ) == .inline( encoding: .base64 ) )
        #expect( try XISFDataBlockLocation( attribute: "inline:hex" )    == .inline( encoding: .hex ) )
    }

    @Test
    func parsesEmbedded() async throws
    {
        #expect( try XISFDataBlockLocation( attribute: "embedded" ) == .embedded )
    }

    @Test
    func parsesAttachment() async throws
    {
        #expect( try XISFDataBlockLocation( attribute: "attachment:4570:1428362" ) == .attachment( position: 4570, size: 1428362 ) )
    }

    @Test
    func rejectsMalformedLocations() async throws
    {
        try #require( throws: XISFError.self ) { try XISFDataBlockLocation( attribute: "inline" ) }
        try #require( throws: XISFError.self ) { try XISFDataBlockLocation( attribute: "inline:base32" ) }
        try #require( throws: XISFError.self ) { try XISFDataBlockLocation( attribute: "attachment:100" ) }
        try #require( throws: XISFError.self ) { try XISFDataBlockLocation( attribute: "attachment:abc:def" ) }
        try #require( throws: XISFError.self ) { try XISFDataBlockLocation( attribute: "" ) }
        try #require( throws: XISFError.self ) { try XISFDataBlockLocation( attribute: "bogus" ) }
    }

    @Test
    func parsesURLLocations() async throws
    {
        #expect( try XISFDataBlockLocation( attribute: "url(http://example.com/f.bin)" ) == .url( URL( string: "http://example.com/f.bin" ).require(), indexID: nil ) )
        #expect( try XISFDataBlockLocation( attribute: "url(file:///data/huge.xisb):0x7a73526b" ) == .url( URL( string: "file:///data/huge.xisb" ).require(), indexID: 0x7a73526b ) )
    }

    @Test
    func parsesAbsolutePathLocations() async throws
    {
        #expect( try XISFDataBlockLocation( attribute: "path(/data/x.dat)" )     == .absolutePath( "/data/x.dat", indexID: nil ) )
        #expect( try XISFDataBlockLocation( attribute: "path(/data/x.xisb):42" ) == .absolutePath( "/data/x.xisb", indexID: 42 ) )
    }

    @Test
    func parsesHeaderRelativePathLocations() async throws
    {
        #expect( try XISFDataBlockLocation( attribute: "path(@header_dir/blocks.xisb):0x4d37" ) == .headerRelativePath( "blocks.xisb", indexID: 0x4d37 ) )
        #expect( try XISFDataBlockLocation( attribute: "path(@header_dir/sub/f.dat)" )           == .headerRelativePath( "sub/f.dat", indexID: nil ) )
    }

    @Test
    func parsesParenthesesWithinResource() async throws
    {
        // Parentheses inside the path are literal after XML decoding; the closing
        // parenthesis is the last one.
        #expect( try XISFDataBlockLocation( attribute: "path(/Documents/description(draft).txt)" ) == .absolutePath( "/Documents/description(draft).txt", indexID: nil ) )
    }

    @Test
    func reportsExternalLocationsAsExternal() async throws
    {
        #expect( try XISFDataBlockLocation( attribute: "path(/x.dat)" ).isExternal        == true )
        #expect( try XISFDataBlockLocation( attribute: "inline:hex" ).isExternal          == false )
        #expect( try XISFDataBlockLocation( attribute: "attachment:0:4" ).isExternal      == false )
    }

    @Test
    func rejectsMalformedExternalLocations() async throws
    {
        try #require( throws: XISFError.self ) { try XISFDataBlockLocation( attribute: "url(no-close" ) }
        try #require( throws: XISFError.self ) { try XISFDataBlockLocation( attribute: "path(/x.dat):zz" ) }
        try #require( throws: XISFError.self ) { try XISFDataBlockLocation( attribute: "path(/x.dat)trailing" ) }
    }
}

private extension Optional
{
    /// Unwraps the value, failing the test with a fatal error when `nil`.
    func require() -> Wrapped
    {
        guard let value = self
        else
        {
            fatalError( "Unexpected nil value in test" )
        }

        return value
    }
}
