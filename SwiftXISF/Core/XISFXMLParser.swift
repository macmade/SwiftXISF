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

/// Builds an ``XISFElement`` tree from the raw XML header text.
///
/// A thin, namespace-aware wrapper over Foundation's `XMLParser`. Namespace
/// processing is enabled, so prefixed and default-namespaced documents both
/// resolve to local element names with the namespace exposed separately, as the
/// XML specification requires. External-entity resolution is left disabled (the
/// `XMLParser` default), so the parser never reads outside the header.
///
/// This is internal infrastructure and not part of the public API.
internal final class XISFXMLParser: NSObject, XMLParserDelegate
{
    /// The root element, set once the opening tag is seen.
    private var root: XISFElement?

    /// The stack of currently-open elements; its last entry is the element
    /// receiving children and character content.
    private var stack: [ XISFElement ]

    /// The first parsing error encountered, if any.
    private var parsingError: XISFError?

    /// Creates a parser delegate.
    private override init()
    {
        self.stack = []

        super.init()
    }

    /// Parses XML header text into an element tree.
    ///
    /// - Parameter xml: The XML header text.
    /// - Returns: The root element of the parsed tree.
    /// - Throws: ``XISFError/malformedXML(reason:)`` if the text is not
    ///   well-formed XML or contains no root element.
    internal static func parse( _ xml: String ) throws -> XISFElement
    {
        let parser   = XMLParser( data: Data( xml.utf8 ) )
        let delegate = XISFXMLParser()

        parser.delegate                = delegate
        parser.shouldProcessNamespaces = true

        let parsed = parser.parse()

        if let error = delegate.parsingError
        {
            throw error
        }

        guard parsed
        else
        {
            throw XISFError.malformedXML( reason: parser.parserError?.localizedDescription ?? "The XML header is not well-formed" )
        }

        guard let root = delegate.root
        else
        {
            throw XISFError.malformedXML( reason: "The XML header contains no root element" )
        }

        return root
    }

    internal func parser( _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [ String: String ] )
    {
        // XMLParser reports a no-namespace element's URI as an empty string;
        // normalize that to nil so "no namespace" is represented one way.
        let resolvedNamespace = ( namespaceURI?.isEmpty ?? true ) ? nil : namespaceURI
        let element           = XISFElement( name: elementName, namespaceURI: resolvedNamespace, attributes: attributes )

        if let parent = self.stack.last
        {
            parent.appendChild( element )
        }
        else
        {
            self.root = element
        }

        self.stack.append( element )
    }

    internal func parser( _ parser: XMLParser, foundCharacters string: String )
    {
        self.stack.last?.appendContent( string )
    }

    internal func parser( _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String? )
    {
        _ = self.stack.popLast()
    }

    internal func parser( _ parser: XMLParser, parseErrorOccurred parseError: Error )
    {
        if self.parsingError == nil
        {
            self.parsingError = XISFError.malformedXML( reason: parseError.localizedDescription )
        }
    }
}
