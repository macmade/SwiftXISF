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

struct Test_Data
{
    @Test
    func bytesAtOffset() async throws
    {
        let data = Data( [ 0x10, 0x20, 0x30, 0x40, 0x50 ] )

        #expect( try Array( data.bytes( at: 0, count: 2 ) ) == [ 0x10, 0x20 ] )
        #expect( try Array( data.bytes( at: 3, count: 2 ) ) == [ 0x40, 0x50 ] )
        #expect( try Array( data.bytes( at: 2, count: 0 ) ) == [] )

        try #require( throws: XISFError.self ) { try data.bytes( at: 4, count: 2 ) }
        try #require( throws: XISFError.self ) { try data.bytes( at: 5, count: 1 ) }
        try #require( throws: XISFError.self ) { try data.bytes( at: -1, count: 1 ) }
        try #require( throws: XISFError.self ) { try data.bytes( at: 0, count: -1 ) }
    }

    @Test
    func bytesHandlesNonZeroBasedSlice() async throws
    {
        let full  = Data( ( 0 ..< 16 ).map { UInt8( $0 ) } )
        let slice = full[ 8 ..< 16 ]

        #expect( try Array( slice.bytes( at: 0, count: 2 ) ) == [ 0x08, 0x09 ] )
        #expect( try Array( slice.bytes( at: 6, count: 2 ) ) == [ 0x0E, 0x0F ] )

        try #require( throws: XISFError.self ) { try slice.bytes( at: 7, count: 2 ) }
    }

    @Test
    func littleEndianInteger() async throws
    {
        let data = Data( [ 0x01, 0x02, 0x03, 0x04, 0xFF, 0xFF, 0xFF, 0xFF ] )

        #expect( try data.littleEndianInteger( at: 0, as: UInt32.self ) == 0x0403_0201 )
        #expect( try data.littleEndianInteger( at: 0, as: UInt16.self ) == 0x0201 )
        #expect( try data.littleEndianInteger( at: 4, as: UInt32.self ) == 0xFFFF_FFFF )

        try #require( throws: XISFError.self ) { try data.littleEndianInteger( at: 6, as: UInt32.self ) }
    }

    @Test
    func littleEndianIntegerOnSlice() async throws
    {
        let full  = Data( [ 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04 ] )
        let slice = full[ 4 ..< 8 ]

        #expect( try slice.littleEndianInteger( at: 0, as: UInt32.self ) == 0x0403_0201 )
    }

    @Test
    func matchesASCII() async throws
    {
        let data = Data( "XISF0100extra".utf8 )

        #expect( data.matchesASCII( "XISF0100", at: 0 ) == true )
        #expect( data.matchesASCII( "extra",    at: 8 ) == true )
        #expect( data.matchesASCII( "xisf0100", at: 0 ) == false )
        #expect( data.matchesASCII( "XISF0101", at: 0 ) == false )
        #expect( data.matchesASCII( "XISF0100extra!", at: 0 ) == false )
    }
}
