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

struct Test_XISFGeometry
{
    @Test
    func parses2DGeometry() throws
    {
        let geometry = try XISFGeometry( attribute: "100:200:3" )

        #expect( geometry.dimensions   == [ 100, 200 ] )
        #expect( geometry.channelCount == 3 )
        #expect( geometry.pixelCount   == 20000 )
        #expect( geometry.sampleCount  == 60000 )
    }

    @Test
    func parsesSingleChannel() throws
    {
        let geometry = try XISFGeometry( attribute: "512:512:1" )

        #expect( geometry.dimensions   == [ 512, 512 ] )
        #expect( geometry.channelCount == 1 )
        #expect( geometry.sampleCount  == 262144 )
    }

    @Test
    func parsesNDimensionalGeometry() throws
    {
        let geometry = try XISFGeometry( attribute: "10:20:30:2" )

        #expect( geometry.dimensions   == [ 10, 20, 30 ] )
        #expect( geometry.channelCount == 2 )
        #expect( geometry.pixelCount   == 6000 )
        #expect( geometry.sampleCount  == 12000 )
    }

    @Test
    func parsesMinimalGeometry() throws
    {
        let geometry = try XISFGeometry( attribute: "5:3" )

        #expect( geometry.dimensions   == [ 5 ] )
        #expect( geometry.channelCount == 3 )
        #expect( geometry.sampleCount  == 15 )
    }

    @Test
    func rejectsMalformedGeometry() async throws
    {
        try #require( throws: XISFError.self ) { try XISFGeometry( attribute: "100" ) }
        try #require( throws: XISFError.self ) { try XISFGeometry( attribute: "" ) }
        try #require( throws: XISFError.self ) { try XISFGeometry( attribute: "100:0:3" ) }
        try #require( throws: XISFError.self ) { try XISFGeometry( attribute: "100:200:0" ) }
        try #require( throws: XISFError.self ) { try XISFGeometry( attribute: "100:-5:3" ) }
        try #require( throws: XISFError.self ) { try XISFGeometry( attribute: "a:b:c" ) }
    }
}
