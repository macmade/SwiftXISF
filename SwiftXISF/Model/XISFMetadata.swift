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

/// A parsed XISF `<Metadata>` element: the set of unit-level properties that
/// describe an XISF unit.
///
/// The metadata is serialized as a collection of child `<Property>` elements
/// whose identifiers use the reserved `XISF:` namespace prefix (for example
/// `XISF:CreationTime` and `XISF:CreatorApplication`). The properties are
/// exposed as ordinary ``XISFProperty`` values.
public struct XISFMetadata: Equatable, Sendable, CustomStringConvertible
{
    /// The metadata properties, in document order.
    public let properties: [ XISFProperty ]

    /// The first metadata property whose identifier matches, or `nil` if none
    /// does.
    ///
    /// - Parameter id: The property identifier to look up (for example
    ///   `XISF:CreatorApplication`).
    /// - Returns: The first matching property, or `nil`.
    public subscript( id: String ) -> XISFProperty?
    {
        self.properties.first { $0.id == id }
    }

    /// Parses a `<Metadata>` element.
    ///
    /// - Parameters:
    ///   - element: The `<Metadata>` element.
    ///   - fileData: The complete file bytes, used to resolve any data-block
    ///     backed property values.
    ///   - baseURL: The directory of the XISF header file, used to resolve
    ///     `@header_dir` relative external data blocks; `nil` when the unit was
    ///     opened from raw data.
    ///   - options: The parsing options to apply.
    /// - Throws: any ``XISFError`` raised while parsing a child property under
    ///   strict parsing.
    internal init( element: XISFElement, fileData: Data, baseURL: URL?, options: XISFParsingOptions ) throws
    {
        self.properties = try XISFProperty.parseList( from: element, fileData: fileData, baseURL: baseURL, options: options )
    }

    /// A single-line, human-readable summary of the metadata.
    public var description: String
    {
        "XISFMetadata { properties: \( self.properties.count ) }"
    }
}
