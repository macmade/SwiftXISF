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

/// A node in the parsed XML-header element tree.
///
/// This is the lightweight, namespace-aware representation that
/// ``XISFXMLParser`` produces from the raw XML header and that the higher-level
/// model types (properties, keywords, images) are built from. It is internal
/// infrastructure and not part of the public API.
///
/// Element and attribute names are the *local* names (any namespace prefix is
/// resolved away), and the element's namespace, if any, is available separately
/// as ``namespaceURI``. Names are compared case-sensitively, as the XML
/// specification requires.
internal final class XISFElement
{
    /// The element's local name, with any namespace prefix resolved away.
    internal let name: String

    /// The URI of the element's namespace, or `nil` if the element is in no
    /// namespace.
    internal let namespaceURI: String?

    /// The element's attributes, keyed by local name.
    internal let attributes: [ String: String ]

    /// The element's child elements, in document order.
    internal private( set ) var children: [ XISFElement ]

    /// The element's accumulated character content.
    ///
    /// Character data may be reported in several pieces while parsing; each
    /// piece is appended here verbatim. Use ``trimmedContent`` for the
    /// whitespace-trimmed value.
    internal private( set ) var content: String

    /// Creates an element node.
    ///
    /// - Parameters:
    ///   - name: The element's local name.
    ///   - namespaceURI: The element's namespace URI, or `nil` for none.
    ///   - attributes: The element's attributes, keyed by local name.
    internal init( name: String, namespaceURI: String?, attributes: [ String: String ] )
    {
        self.name         = name
        self.namespaceURI = namespaceURI
        self.attributes   = attributes
        self.children     = []
        self.content      = ""
    }

    /// Appends a child element, in document order.
    ///
    /// - Parameter child: The child element to append.
    internal func appendChild( _ child: XISFElement )
    {
        self.children.append( child )
    }

    /// Appends a piece of character content.
    ///
    /// - Parameter string: The character data to append verbatim.
    internal func appendContent( _ string: String )
    {
        self.content.append( string )
    }

    /// The element's character content with leading and trailing whitespace and
    /// newlines removed.
    internal var trimmedContent: String
    {
        self.content.trimmingCharacters( in: .whitespacesAndNewlines )
    }

    /// Returns the direct child elements with a given local name.
    ///
    /// - Parameter name: The local name to match, compared case-sensitively.
    /// - Returns: The matching direct children, in document order.
    internal func children( named name: String ) -> [ XISFElement ]
    {
        self.children.filter { $0.name == name }
    }
}
