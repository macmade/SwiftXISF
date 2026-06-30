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

struct Test_XISFError
{
    @Test
    func description() async throws
    {
        [
            ( error: XISFError.invalidFileURL(      url: URL( fileURLWithPath: "/foo/bar.xisf" ) ), contains: "/foo/bar.xisf" ),
            ( error: XISFError.cannotReadFile(      url: URL( fileURLWithPath: "/foo/bar.xisf" ) ), contains: "/foo/bar.xisf" ),
            ( error: XISFError.invalidSignature(    reason: "This is a test" ),                      contains: "This is a test" ),
            ( error: XISFError.invalidHeaderLength( reason: "This is a test" ),                      contains: "This is a test" ),
            ( error: XISFError.malformedXML(        reason: "This is a test" ),                      contains: "This is a test" ),
            ( error: XISFError.invalidElement(      reason: "This is a test" ),                      contains: "This is a test" ),
            ( error: XISFError.dataBlockError(      reason: "This is a test" ),                      contains: "This is a test" ),
            ( error: XISFError.decompressionError(  reason: "This is a test" ),                      contains: "This is a test" ),
            ( error: XISFError.checksumMismatch(    reason: "This is a test" ),                      contains: "This is a test" ),
            ( error: XISFError.dataError(           reason: "This is a test" ),                      contains: "This is a test" ),
        ]
        .forEach
        {
            #expect( $0.error.description.isEmpty == false )
            #expect( $0.error.description         != _typeName( XISFError.self, qualified: true ) )
            #expect( $0.error.description.contains( $0.contains ) )
        }
    }
}
