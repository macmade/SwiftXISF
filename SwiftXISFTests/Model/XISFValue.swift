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

struct Test_XISFValue
{
    @Test
    func accessorReturnsPayloadForMatchingCase() async throws
    {
        #expect( XISFValue.boolean( true ).boolean                   == true )
        #expect( XISFValue.integer( 42 ).integer                     == 42 )
        #expect( XISFValue.unsignedInteger( 42 ).unsignedInteger     == 42 )
        #expect( XISFValue.float( 42.5 ).float                       == 42.5 )
        #expect( XISFValue.string( "hi" ).string                     == "hi" )

        let complex = try #require( XISFValue.complex( real: 1.5, imaginary: -2.5 ).complex )

        #expect( complex.real      == 1.5 )
        #expect( complex.imaginary == -2.5 )
    }

    @Test
    func accessorReturnsNilForNonMatchingCase() async throws
    {
        #expect( XISFValue.integer( 42 ).boolean             == nil )
        #expect( XISFValue.integer( 42 ).unsignedInteger     == nil )
        #expect( XISFValue.integer( 42 ).float               == nil )
        #expect( XISFValue.string( "hi" ).integer            == nil )
        #expect( XISFValue.float( 1 ).complex                == nil )
        #expect( XISFValue.boolean( true ).timePoint         == nil )
    }

    @Test
    func kindDerivesFromCase() async throws
    {
        #expect( XISFValue.boolean( true ).kind                       == .boolean )
        #expect( XISFValue.integer( 1 ).kind                          == .integer )
        #expect( XISFValue.unsignedInteger( 1 ).kind                  == .unsignedInteger )
        #expect( XISFValue.float( 1 ).kind                            == .float )
        #expect( XISFValue.complex( real: 0, imaginary: 0 ).kind      == .complex )
        #expect( XISFValue.string( "x" ).kind                         == .string )
        #expect( XISFValue.timePoint( Date( timeIntervalSince1970: 0 ) ).kind == .timePoint )
    }

    @Test
    func kindDescription() async throws
    {
        #expect( XISFValue.Kind.boolean.description         == "Boolean" )
        #expect( XISFValue.Kind.integer.description         == "Integer" )
        #expect( XISFValue.Kind.unsignedInteger.description == "Unsigned Integer" )
        #expect( XISFValue.Kind.float.description           == "Float" )
        #expect( XISFValue.Kind.complex.description         == "Complex" )
        #expect( XISFValue.Kind.string.description          == "String" )
        #expect( XISFValue.Kind.timePoint.description       == "Time Point" )
    }

    @Test
    func equalityAndNaN() async throws
    {
        #expect( XISFValue.integer( 42 )         == .integer( 42 ) )
        #expect( XISFValue.integer( 42 )         != .integer( 43 ) )
        #expect( XISFValue.integer( 42 )         != .unsignedInteger( 42 ) )
        #expect( XISFValue.float( .nan )         == .float( .nan ) )
        #expect( XISFValue.float( 1.5 )          == .float( 1.5 ) )
        #expect( XISFValue.complex( real: .nan, imaginary: 1 ) == .complex( real: .nan, imaginary: 1 ) )
        #expect( XISFValue.complex( real: 1, imaginary: 2 )    != .complex( real: 1, imaginary: 3 ) )
    }

    @Test
    func distinctValuesHashDistinctly() async throws
    {
        let values: [ XISFValue ] = [ .boolean( true ), .integer( 1 ), .unsignedInteger( 1 ), .float( 1 ), .complex( real: 1, imaginary: 1 ), .string( "x" ) ]
        let hashes                = Set( values.map { $0.hashValue } )

        #expect( hashes.count == values.count )
        #expect( XISFValue.float( .nan ).hashValue == XISFValue.float( .nan ).hashValue )
    }

    @Test
    func valueTypesAreSendable() async throws
    {
        func requireSendable< T: Sendable >( _: T.Type ) {}

        requireSendable( XISFValue.self )
        requireSendable( XISFValue.Kind.self )
        requireSendable( XISFPropertyType.self )
    }

    @Test
    func parsesBoolean() async throws
    {
        #expect( try XISFValue.value( fromAttribute: "1",     type: .boolean ) == .boolean( true ) )
        #expect( try XISFValue.value( fromAttribute: "0",     type: .boolean ) == .boolean( false ) )
        #expect( try XISFValue.value( fromAttribute: "true",  type: .boolean ) == .boolean( true ) )
        #expect( try XISFValue.value( fromAttribute: "False", type: .boolean ) == .boolean( false ) )

        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "maybe", type: .boolean ) }
    }

    @Test
    func parsesSignedIntegers() async throws
    {
        #expect( try XISFValue.value( fromAttribute: "42",   type: .int32 ) == .integer( 42 ) )
        #expect( try XISFValue.value( fromAttribute: "-5",   type: .int8 )  == .integer( -5 ) )
        #expect( try XISFValue.value( fromAttribute: "9223372036854775807", type: .int64 ) == .integer( 9223372036854775807 ) )

        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "300",  type: .int8 ) }
        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "abc",  type: .int32 ) }
        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "99999999999999999999", type: .int64 ) }
    }

    @Test
    func parsesUnsignedIntegers() async throws
    {
        #expect( try XISFValue.value( fromAttribute: "200", type: .uint8 )  == .unsignedInteger( 200 ) )
        #expect( try XISFValue.value( fromAttribute: "18446744073709551615", type: .uint64 ) == .unsignedInteger( 18446744073709551615 ) )

        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "-1",  type: .uint8 ) }
        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "300", type: .uint8 ) }
    }

    @Test
    func parsesFloats() async throws
    {
        #expect( try XISFValue.value( fromAttribute: "1.5",   type: .float64 ) == .float( 1.5 ) )
        #expect( try XISFValue.value( fromAttribute: "1.0e3", type: .float32 ) == .float( 1000.0 ) )

        let nan = try XISFValue.value( fromAttribute: "nan", type: .float64 )

        #expect( nan.float?.isNaN == true )

        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "x", type: .float64 ) }
    }

    @Test
    func parsesComplex() async throws
    {
        #expect( try XISFValue.value( fromAttribute: "(1.5,-2.5)",  type: .complex64 ) == .complex( real: 1.5, imaginary: -2.5 ) )
        #expect( try XISFValue.value( fromAttribute: "( 1 , 2 )",   type: .complex32 ) == .complex( real: 1, imaginary: 2 ) )

        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "(1.5)",   type: .complex64 ) }
        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "1.5,2.5", type: .complex64 ) }
        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "(a,b)",   type: .complex64 ) }
    }

    @Test
    func parsesTimePoint() async throws
    {
        let value = try XISFValue.value( fromAttribute: "2021-01-02T03:04:05Z", type: .timePoint )
        let date  = try #require( value.timePoint )

        var calendar      = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( secondsFromGMT: 0 ) ?? .current

        let components = calendar.dateComponents( [ .year, .month, .day, .hour, .minute, .second ], from: date )

        #expect( components.year   == 2021 )
        #expect( components.month  == 1 )
        #expect( components.day    == 2 )
        #expect( components.hour   == 3 )
        #expect( components.minute == 4 )
        #expect( components.second == 5 )

        // Fractional seconds are accepted too.
        #expect( ( try XISFValue.value( fromAttribute: "2021-01-02T03:04:05.500Z", type: .timePoint ) ).timePoint != nil )

        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "not a date", type: .timePoint ) }
    }

    @Test
    func rejectsNonValueAttributeTypes() async throws
    {
        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "x",   type: .string ) }
        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "1 2", type: .ui8Vector ) }
        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "1 2", type: .f32Matrix ) }
        try #require( throws: XISFError.self ) { try XISFValue.value( fromAttribute: "00",  type: .byteArray ) }
    }
}
