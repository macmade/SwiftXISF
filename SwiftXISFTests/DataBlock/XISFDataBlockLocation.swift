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
    func rejectsExternalLocationsForNow() async throws
    {
        // External / distributed locations are deferred to a later milestone.
        try #require( throws: XISFError.self ) { try XISFDataBlockLocation( attribute: "url(file:///tmp/x.dat)" ) }
        try #require( throws: XISFError.self ) { try XISFDataBlockLocation( attribute: "path(/tmp/x.dat)" ) }
    }
}
