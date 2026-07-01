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

/// A parsed XISF `<Image>` element: its typed geometry and format metadata,
/// nested properties and FITS keywords, and its pixel data as opaque bytes.
///
/// Following SwiftXISF's opaque-bytes design, pixel samples are exposed as the
/// fully decoded (decompressed and un-shuffled) ``data`` plus the metadata
/// needed to interpret them: ``geometry``, ``sampleFormat``, ``colorSpace``,
/// ``pixelStorage``, ``byteOrder`` and ``bounds``. Interpretation is left to the
/// consumer.
///
/// The pixel data is decoded lazily on first access to ``data`` (via the backing
/// data block), so this is a reference type and, like the data block, not
/// `Sendable`.
public final class XISFImage: CustomStringConvertible
{
    /// The image geometry: spatial dimensions and channel count.
    public let geometry: XISFGeometry

    /// The pixel sample format.
    public let sampleFormat: XISFSampleFormat

    /// The color space (defaults to `Gray` when unspecified).
    public let colorSpace: XISFColorSpace

    /// The pixel storage model (defaults to `Planar` when unspecified).
    public let pixelStorage: XISFPixelStorage

    /// The byte order of multi-byte samples (defaults to little-endian).
    public let byteOrder: XISFByteOrder

    /// The representable sample range, required for floating-point formats and
    /// `nil` otherwise (integers have an implicit range; complex is undefined).
    public let bounds: ClosedRange<Double>?

    /// The optional image type (for example `Light`, `Bias`, `Dark`).
    public let imageType: String?

    /// The optional image orientation.
    public let orientation: String?

    /// The optional image identifier.
    public let id: String?

    /// The optional image UUID.
    public let uuid: String?

    /// The image's nested properties, in document order.
    public let properties: [ XISFProperty ]

    /// The image's nested FITS keywords, in document order.
    public let keywords: [ XISFFITSKeyword ]

    /// The image's embedded ICC color profile, or `nil` if none is associated.
    public let iccProfile: XISFICCProfile?

    /// The image's RGB working space, or `nil` if none is associated (the
    /// default working space is then sRGB).
    public let rgbWorkingSpace: XISFRGBWorkingSpace?

    /// The image's display function, or `nil` if none is associated (the
    /// default is then the identity function).
    public let displayFunction: XISFDisplayFunction?

    /// The image's color filter array, or `nil` if the image is not mosaiced.
    public let colorFilterArray: XISFColorFilterArray?

    /// The image's display resolution, or `nil` if none is associated (the
    /// default is then 72 pixels per inch).
    public let resolution: XISFResolution?

    /// The image's thumbnail, or `nil` if none is associated.
    public let thumbnail: XISFThumbnail?

    /// The backing pixel data block.
    private let dataBlock: XISFDataBlock

    /// The image's pixel bytes: fully decoded (decompressed and un-shuffled),
    /// exposed opaquely. Computed lazily on first access and cached.
    ///
    /// - Throws: any ``XISFError`` raised while resolving or decoding the pixel
    ///   data block (decompression failure, checksum mismatch).
    public var data: Data
    {
        get throws { try self.dataBlock.data }
    }

    /// Parses an `<Image>` element.
    ///
    /// - Parameters:
    ///   - element: The `<Image>` element.
    ///   - fileData: The complete file bytes, used to resolve an `attachment`
    ///     pixel data block by its absolute offset.
    ///   - baseURL: The directory of the XISF header file, used to resolve
    ///     `@header_dir` relative external data blocks; `nil` when the unit was
    ///     opened from raw data.
    ///   - options: The parsing options to apply. Under strict parsing the
    ///     expected pixel byte count must match the geometry and sample format,
    ///     floating-point images must declare `bounds`, and unknown enumerated
    ///     values are errors; ``XISFParsingOptions/allowSpecDeviations`` relaxes
    ///     these.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if a required attribute is
    ///   missing or invalid, or a validation check fails; or any error raised
    ///   while resolving the pixel data block.
    internal init( element: XISFElement, fileData: Data, baseURL: URL?, options: XISFParsingOptions ) throws
    {
        guard let geometryString = element.attributes[ "geometry" ]
        else
        {
            throw XISFError.invalidElement( reason: "Image is missing a 'geometry' attribute" )
        }

        let geometry = try XISFGeometry( attribute: geometryString )

        guard let sampleFormatString = element.attributes[ "sampleFormat" ], let sampleFormat = XISFSampleFormat( rawValue: sampleFormatString )
        else
        {
            throw XISFError.invalidElement( reason: "Image has a missing or unknown 'sampleFormat': '\( element.attributes[ "sampleFormat" ] ?? "" )'" )
        }

        let lenient   = options.contains( .allowSpecDeviations )
        let bounds    = try element.attributes[ "bounds" ].map { try XISFImage.parseBounds( $0 ) }
        let dataBlock = try XISFDataBlock( element: element, fileData: fileData, baseURL: baseURL, options: options )

        if sampleFormat.isFloatingPoint, bounds == nil, lenient == false
        {
            throw XISFError.invalidElement( reason: "Floating-point image of format \( sampleFormat.rawValue ) is missing the required 'bounds' attribute" )
        }

        let expectedSize = geometry.sampleCount * sampleFormat.bytesPerSample

        // The uncompressed size is unknown for an uncompressed external block
        // (it would require reading the external resource), so validate only when
        // it is known without resolving the block.
        if let actualSize = dataBlock.uncompressedSize, actualSize != expectedSize, lenient == false
        {
            throw XISFError.invalidElement( reason: "Image pixel data is \( actualSize ) bytes but geometry \( geometryString ) and format \( sampleFormat.rawValue ) require \( expectedSize )" )
        }

        self.geometry     = geometry
        self.sampleFormat = sampleFormat
        self.colorSpace   = try XISFImage.enumeratedValue( element, "colorSpace",   default: XISFColorSpace.defaultValue,   options: options )
        self.pixelStorage = try XISFImage.enumeratedValue( element, "pixelStorage", default: XISFPixelStorage.defaultValue, options: options )
        self.byteOrder    = try XISFImage.enumeratedValue( element, "byteOrder",    default: XISFByteOrder.defaultValue,    options: options )
        self.bounds       = bounds
        self.imageType    = element.attributes[ "imageType" ]
        self.orientation  = element.attributes[ "orientation" ]
        self.id           = element.attributes[ "id" ]
        self.uuid         = element.attributes[ "uuid" ]
        self.dataBlock    = dataBlock
        self.properties   = try XISFProperty.parseList( from: element, fileData: fileData, baseURL: baseURL, options: options )
        self.keywords     = try element.children( named: "FITSKeyword" ).map { try XISFFITSKeyword( element: $0, options: options ) }

        self.iccProfile       = try XISFImage.optionalChild( element, named: "ICCProfile",       options: options ) { try XISFICCProfile( element: $0, fileData: fileData, baseURL: baseURL, options: options ) }
        self.rgbWorkingSpace  = try XISFImage.optionalChild( element, named: "RGBWorkingSpace",  options: options ) { try XISFRGBWorkingSpace( element: $0, options: options ) }
        self.displayFunction  = try XISFImage.optionalChild( element, named: "DisplayFunction",  options: options ) { try XISFDisplayFunction( element: $0, options: options ) }
        self.colorFilterArray = try XISFImage.optionalChild( element, named: "ColorFilterArray", options: options ) { try XISFColorFilterArray( element: $0, options: options ) }
        self.resolution       = try XISFImage.optionalChild( element, named: "Resolution",       options: options ) { try XISFResolution( element: $0, options: options ) }
        self.thumbnail        = try XISFImage.optionalChild( element, named: "Thumbnail",        options: options ) { try XISFThumbnail( element: $0, fileData: fileData, baseURL: baseURL, options: options ) }
    }

    /// Parses an optional child metadata element, tolerating a malformed one
    /// under lenient parsing.
    ///
    /// - Parameters:
    ///   - element: The `<Image>` element whose children to search.
    ///   - name: The local name of the child element to parse.
    ///   - options: The parsing options; under
    ///     ``XISFParsingOptions/allowSpecDeviations`` a child that fails to parse
    ///     is dropped (returns `nil`) instead of propagating the error.
    ///   - parse: The closure that parses the first matching child element.
    /// - Returns: The parsed value, `nil` if no matching child exists, or `nil`
    ///   if parsing failed under lenient parsing.
    /// - Throws: any error raised by `parse` under strict parsing.
    private static func optionalChild<T>( _ element: XISFElement, named name: String, options: XISFParsingOptions, parse: ( XISFElement ) throws -> T ) throws -> T?
    {
        guard let child = element.children( named: name ).first
        else
        {
            return nil
        }

        do
        {
            return try parse( child )
        }
        catch
        {
            if options.contains( .allowSpecDeviations )
            {
                return nil
            }

            throw error
        }
    }

    /// Parses a `bounds` attribute of the form `low:high`.
    ///
    /// - Parameter raw: The raw `bounds` attribute value.
    /// - Returns: The parsed closed range.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the attribute is not
    ///   two `low:high` reals with `low <= high`.
    private static func parseBounds( _ raw: String ) throws -> ClosedRange<Double>
    {
        let parts = raw.split( separator: ":", omittingEmptySubsequences: false )

        guard parts.count == 2, let low = Double( parts[ 0 ] ), let high = Double( parts[ 1 ] ), low <= high
        else
        {
            throw XISFError.invalidElement( reason: "Invalid bounds attribute: '\( raw )'" )
        }

        return low ... high
    }

    /// Reads a string-raw-valued enumerated attribute, applying a default when
    /// absent.
    ///
    /// - Parameters:
    ///   - element: The `<Image>` element.
    ///   - name: The attribute name.
    ///   - defaultValue: The value to use when the attribute is absent.
    ///   - options: The parsing options; under
    ///     ``XISFParsingOptions/allowSpecDeviations`` an unknown value falls back
    ///     to the default instead of being an error.
    /// - Returns: The parsed value, or the default.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the value is present
    ///   but unknown and strict parsing is in effect.
    private static func enumeratedValue<T: RawRepresentable>( _ element: XISFElement, _ name: String, default defaultValue: T, options: XISFParsingOptions ) throws -> T where T.RawValue == String
    {
        guard let raw = element.attributes[ name ]
        else
        {
            return defaultValue
        }

        guard let value = T( rawValue: raw )
        else
        {
            if options.contains( .allowSpecDeviations )
            {
                return defaultValue
            }

            throw XISFError.invalidElement( reason: "Invalid '\( name )' attribute: '\( raw )'" )
        }

        return value
    }

    /// A single-line, human-readable summary of the image.
    public var description: String
    {
        let dimensions = self.geometry.dimensions.map { String( $0 ) }.joined( separator: "x" )

        return "XISFImage { geometry: \( dimensions ):\( self.geometry.channelCount ), sampleFormat: \( self.sampleFormat.rawValue ), colorSpace: \( self.colorSpace.rawValue ), pixelStorage: \( self.pixelStorage.rawValue ), byteOrder: \( self.byteOrder.rawValue ) }"
    }
}
