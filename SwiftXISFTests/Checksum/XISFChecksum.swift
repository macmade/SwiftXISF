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

struct Test_XISFChecksum
{
    /// The reference payload (`DE AD BE EF`) and its digests, computed by
    /// python `hashlib` — a reference independent of CryptoKit.
    static let payload    = Data( [ 0xDE, 0xAD, 0xBE, 0xEF ] )
    static let sha1Hex    = "d78f8bb992a56a597f6c7a1fb918bb78271367eb"
    static let sha256Hex  = "5f78c33274e43fa9de5659265c1d917e25c03722dcb0b8d27db8d5feaa813953"
    static let sha512Hex  = "1284b2d521535196f22175d5f558104220a6ad7680e78b49fa6f20e57ea7b185d71ec1edb137e70eba528dedb141f5d2f8bb53149d262932b27cf41fed96aa7f"
    static let sha3256Hex = "352b82608dad6c7ac3dd665bc2666e5d97803cb13f23a1109e2105e93f42c448"
    static let sha3512Hex = "16f4abfb7f079d757a24cf6a12a4ee2c28041cee3fa68cb7a50aa95e33aa87d5ada97274d4dc548499eb23da351b1b3ab7c5a04376f94cab4fe705dc0d171bef"

    // MARK: - Attribute parsing

    @Test
    func parsesAlgorithmAndDigest() throws
    {
        let checksum = try XISFChecksum( attribute: "sha-256:\( Test_XISFChecksum.sha256Hex )" )

        #expect( checksum.algorithm == .sha256 )
        #expect( checksum.digest    == Test_XISFChecksum.sha256Hex )
    }

    @Test
    func acceptsAlgorithmAliases() throws
    {
        #expect( try XISFChecksum( attribute: "sha1:00" ).algorithm     == .sha1 )
        #expect( try XISFChecksum( attribute: "sha-1:00" ).algorithm    == .sha1 )
        #expect( try XISFChecksum( attribute: "sha256:00" ).algorithm   == .sha256 )
        #expect( try XISFChecksum( attribute: "sha-256:00" ).algorithm  == .sha256 )
        #expect( try XISFChecksum( attribute: "sha512:00" ).algorithm   == .sha512 )
        #expect( try XISFChecksum( attribute: "sha-512:00" ).algorithm  == .sha512 )
        #expect( try XISFChecksum( attribute: "sha3-256:00" ).algorithm == .sha3_256 )
        #expect( try XISFChecksum( attribute: "sha3-512:00" ).algorithm == .sha3_512 )
    }

    @Test
    func rejectsUnknownAlgorithm() async throws
    {
        try #require( throws: XISFError.self ) { try XISFChecksum( attribute: "md5:00" ) }
        try #require( throws: XISFError.self ) { try XISFChecksum( attribute: "sha3-384:00" ) }
    }

    @Test
    func rejectsMalformedAttribute() async throws
    {
        try #require( throws: XISFError.self ) { try XISFChecksum( attribute: "sha-256" ) }
        try #require( throws: XISFError.self ) { try XISFChecksum( attribute: "" ) }
        try #require( throws: XISFError.self ) { try XISFChecksum( attribute: ":abc" ) }
        try #require( throws: XISFError.self ) { try XISFChecksum( attribute: "sha-256:" ) }
    }

    // MARK: - Digest computation (matching / mismatching)

    @Test
    func matchesSHA1() throws
    {
        #expect( try XISFChecksum( attribute: "sha-1:\( Test_XISFChecksum.sha1Hex )" ).matches( Test_XISFChecksum.payload ) )
    }

    @Test
    func matchesSHA256() throws
    {
        #expect( try XISFChecksum( attribute: "sha-256:\( Test_XISFChecksum.sha256Hex )" ).matches( Test_XISFChecksum.payload ) )
    }

    @Test
    func matchesSHA512() throws
    {
        #expect( try XISFChecksum( attribute: "sha-512:\( Test_XISFChecksum.sha512Hex )" ).matches( Test_XISFChecksum.payload ) )
    }

    @Test
    func matchesSHA3() throws
    {
        if #available( macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, * )
        {
            #expect( try XISFChecksum( attribute: "sha3-256:\( Test_XISFChecksum.sha3256Hex )" ).matches( Test_XISFChecksum.payload ) )
            #expect( try XISFChecksum( attribute: "sha3-512:\( Test_XISFChecksum.sha3512Hex )" ).matches( Test_XISFChecksum.payload ) )
        }
        else
        {
            // On older systems SHA-3 has no implementation and must fail cleanly.
            try #require( throws: XISFError.self ) { try XISFChecksum( attribute: "sha3-256:\( Test_XISFChecksum.sha3256Hex )" ).matches( Test_XISFChecksum.payload ) }
        }
    }

    @Test
    func doesNotMatchWrongDigest() throws
    {
        let checksum = try XISFChecksum( attribute: "sha-256:0000000000000000000000000000000000000000000000000000000000000000" )

        #expect( try checksum.matches( Test_XISFChecksum.payload ) == false )
    }

    @Test
    func verifyThrowsOnMismatch() async throws
    {
        let checksum = try XISFChecksum( attribute: "sha-1:0000000000000000000000000000000000000000" )

        try #require( throws: XISFError.self ) { try checksum.verify( Test_XISFChecksum.payload ) }
    }

    @Test
    func verifySucceedsOnMatch() throws
    {
        try XISFChecksum( attribute: "sha-1:\( Test_XISFChecksum.sha1Hex )" ).verify( Test_XISFChecksum.payload )
    }
}
