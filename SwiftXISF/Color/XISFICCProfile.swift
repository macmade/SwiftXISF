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

/// A parsed XISF `<ICCProfile>` element: an embedded ICC color profile.
///
/// An ICC profile is serialized as an XISF data block that stores the profile
/// structure unaltered, so its bytes are exposed opaquely via ``data``. Per the
/// ICC specification the profile data is always big-endian; `ICCProfile`
/// elements therefore never carry a `byteOrder` attribute, and interpretation
/// of the bytes is left to the consumer.
///
/// The profile bytes are decoded lazily on first access to ``data`` (via the
/// backing data block), so this is a reference type and, like the data block,
/// not `Sendable`.
public final class XISFICCProfile: CustomStringConvertible
{
    /// The backing data block holding the profile bytes.
    private let dataBlock: XISFDataBlock

    /// The raw ICC profile bytes: fully decoded (decompressed if the block was
    /// compressed), exposed opaquely. Computed lazily on first access.
    ///
    /// - Throws: any ``XISFError`` raised while resolving or decoding the data
    ///   block (decompression failure, checksum mismatch).
    public var data: Data
    {
        get throws { try self.dataBlock.data }
    }

    /// Parses an `<ICCProfile>` element.
    ///
    /// - Parameters:
    ///   - element: The `<ICCProfile>` element, which must declare a data-block
    ///     `location`.
    ///   - fileData: The complete file bytes, used to resolve an `attachment`
    ///     data block by its absolute offset.
    ///   - options: The parsing options to apply.
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if the `location` is
    ///   missing or malformed, or any error raised while resolving the block.
    internal init( element: XISFElement, fileData: Data, options: XISFParsingOptions ) throws
    {
        self.dataBlock = try XISFDataBlock( element: element, fileData: fileData, options: options )
    }

    /// A single-line, human-readable summary of the ICC profile.
    public var description: String
    {
        "XISFICCProfile { location: \( self.dataBlock.location ) }"
    }
}
