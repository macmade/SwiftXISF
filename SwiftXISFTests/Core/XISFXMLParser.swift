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

struct Test_XISFXMLParser
{
    @Test
    func parsesElementTree() async throws
    {
        let root = try XISFXMLParser.parse( "<root a=\"1\" b=\"2\"><child>hello</child><child/></root>" )

        #expect( root.name              == "root" )
        #expect( root.attributes[ "a" ] == "1" )
        #expect( root.attributes[ "b" ] == "2" )
        #expect( root.children.count    == 2 )
        #expect( root.children( named: "child" ).count == 2 )
        #expect( root.children.first?.trimmedContent   == "hello" )
    }

    @Test
    func parsesNestedChildren() async throws
    {
        let root  = try XISFXMLParser.parse( "<a><b><c/></b></a>" )
        let b     = try #require( root.children.first )
        let c     = try #require( b.children.first )

        #expect( root.name == "a" )
        #expect( b.name    == "b" )
        #expect( c.name    == "c" )
    }

    @Test
    func resolvesDefaultNamespaceToLocalNames() async throws
    {
        let root = try XISFXMLParser.parse( "<xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\"><Image/></xisf>" )

        #expect( root.name                  == "xisf" )
        #expect( root.namespaceURI          == "http://www.pixinsight.com/xisf" )
        #expect( root.children.first?.name  == "Image" )
    }

    @Test
    func resolvesPrefixedNamespaceToLocalNames() async throws
    {
        let root = try XISFXMLParser.parse( "<x:xisf version=\"1.0\" xmlns:x=\"http://www.pixinsight.com/xisf\"><x:Image/></x:xisf>" )

        #expect( root.name                  == "xisf" )
        #expect( root.namespaceURI          == "http://www.pixinsight.com/xisf" )
        #expect( root.children.first?.name  == "Image" )
    }

    @Test
    func reportsNoNamespaceWhenAbsent() async throws
    {
        let root = try XISFXMLParser.parse( "<xisf version=\"1.0\"/>" )

        #expect( root.name         == "xisf" )
        #expect( root.namespaceURI == nil )
    }

    @Test
    func rejectsMalformedXML() async throws
    {
        try #require( throws: XISFError.self ) { try XISFXMLParser.parse( "<root><unclosed></root>" ) }
        try #require( throws: XISFError.self ) { try XISFXMLParser.parse( "not xml at all <<<" ) }
        try #require( throws: XISFError.self ) { try XISFXMLParser.parse( "" ) }
    }
}
