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

/// A parsed XISF `<Thumbnail>` element: a small, representative version of an
/// image.
///
/// Other than its tag name, a thumbnail is an ordinary XISF image, so it is
/// parsed through and exposed as an ``XISFImage`` (available as ``image``). The
/// XISF specification additionally restricts a thumbnail to a two-dimensional,
/// `UInt8` or `UInt16`, grayscale or RGB image with no `bounds` attribute and no
/// child `ColorFilterArray` or nested `Thumbnail`; these restrictions are
/// enforced under strict parsing and relaxed under
/// ``XISFParsingOptions/allowSpecDeviations``.
///
/// Because the backing image decodes its pixel bytes lazily, this is a reference
/// type and not `Sendable`.
public final class XISFThumbnail: CustomStringConvertible
{
    /// The thumbnail as an ordinary parsed image.
    public let image: XISFImage

    /// The thumbnail's pixel bytes: fully decoded (decompressed and
    /// un-shuffled), exposed opaquely. Computed lazily on first access.
    ///
    /// - Throws: any ``XISFError`` raised while resolving or decoding the pixel
    ///   data block.
    public var data: Data
    {
        get throws { try self.image.data }
    }

    /// Parses a `<Thumbnail>` element.
    ///
    /// - Parameters:
    ///   - element: The `<Thumbnail>` element.
    ///   - fileData: The complete file bytes, used to resolve an `attachment`
    ///     pixel data block by its absolute offset.
    ///   - baseURL: The directory of the XISF header file, used to resolve
    ///     `@header_dir` relative external data blocks; `nil` when the unit was
    ///     opened from raw data.
    ///   - options: The parsing options to apply. Under strict parsing the
    ///     thumbnail restrictions are enforced;
    ///     ``XISFParsingOptions/allowSpecDeviations`` relaxes them.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if a thumbnail restriction
    ///   is violated under strict parsing, or any error raised while parsing the
    ///   image.
    internal init( element: XISFElement, fileData: Data, baseURL: URL?, options: XISFParsingOptions ) throws
    {
        let image = try XISFImage( element: element, fileData: fileData, baseURL: baseURL, options: options )

        if options.contains( .allowSpecDeviations ) == false
        {
            try XISFThumbnail.validate( image, element: element )
        }

        self.image = image
    }

    /// Enforces the XISF thumbnail restrictions on a parsed image.
    ///
    /// - Parameters:
    ///   - image: The parsed thumbnail image.
    ///   - element: The originating `<Thumbnail>` element (used to detect
    ///     forbidden child elements).
    /// - Throws: ``XISFError/invalidElement(reason:)`` if any restriction is
    ///   violated.
    private static func validate( _ image: XISFImage, element: XISFElement ) throws
    {
        guard image.sampleFormat == .uInt8 || image.sampleFormat == .uInt16
        else
        {
            throw XISFError.invalidElement( reason: "Thumbnail sample format must be UInt8 or UInt16, found \( image.sampleFormat.rawValue )" )
        }

        guard image.colorSpace == .gray || image.colorSpace == .rgb
        else
        {
            throw XISFError.invalidElement( reason: "Thumbnail color space must be Gray or RGB, found \( image.colorSpace.rawValue )" )
        }

        guard image.geometry.dimensions.count == 2
        else
        {
            throw XISFError.invalidElement( reason: "Thumbnail must be a two-dimensional image" )
        }

        guard image.bounds == nil
        else
        {
            throw XISFError.invalidElement( reason: "Thumbnail must not define a 'bounds' attribute" )
        }

        guard element.children( named: "ColorFilterArray" ).isEmpty
        else
        {
            throw XISFError.invalidElement( reason: "Thumbnail must not contain a ColorFilterArray element" )
        }

        guard element.children( named: "Thumbnail" ).isEmpty
        else
        {
            throw XISFError.invalidElement( reason: "Thumbnail must not contain a nested Thumbnail element" )
        }
    }

    /// A single-line, human-readable summary of the thumbnail.
    public var description: String
    {
        "XISFThumbnail { \( self.image ) }"
    }
}
