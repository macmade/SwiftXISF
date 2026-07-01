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

struct Test_XISFICCProfile
{
    private static func iccProfile( _ xml: String, fileData: Data = Data(), baseURL: URL? = nil, options: XISFParsingOptions = .strict ) throws -> XISFICCProfile
    {
        try XISFICCProfile( element: XISFXMLParser.parse( xml ), fileData: fileData, baseURL: baseURL, options: options )
    }

    @Test
    func exposesInlineProfileBytes() throws
    {
        let icc = try Test_XISFICCProfile.iccProfile( "<ICCProfile location=\"inline:hex\">deadbeef</ICCProfile>" )

        #expect( try icc.data == Data( [ 0xDE, 0xAD, 0xBE, 0xEF ] ) )
    }

    @Test
    func resolvesAttachmentProfileBytes() throws
    {
        let fileData = Data( [ 0x00, 0x00, 0x11, 0x22, 0x33, 0x44 ] )
        let icc      = try Test_XISFICCProfile.iccProfile( "<ICCProfile location=\"attachment:2:4\"/>", fileData: fileData )

        #expect( try icc.data == Data( [ 0x11, 0x22, 0x33, 0x44 ] ) )
    }

    @Test
    func rejectsMissingLocation() async throws
    {
        try #require( throws: XISFError.self ) { try Test_XISFICCProfile.iccProfile( "<ICCProfile/>" ) }
    }
}
