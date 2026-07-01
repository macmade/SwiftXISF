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

/// A parsed XISF (Extensible Image Serialization Format) monolithic file.
///
/// A monolithic XISF file begins with a 16-byte binary preamble — the 8-byte
/// `XISF0100` signature, a little-endian `UInt32` giving the length of the XML
/// header, and a 4-byte reserved field — followed by the UTF-8 XML header and,
/// after it, the attached binary data blocks. This type reads and validates the
/// preamble and exposes the raw XML header.
///
/// Like `FITSFile`, the file's bytes are not held in a separate whole-file
/// buffer: parsing happens during initialization, and the bytes that later
/// stages need (for `attachment:position:size` data-block locations, whose
/// positions are absolute offsets from the start of the file) are resolved into
/// the per-block model objects then, as cheap slices of the original bytes.
///
/// ``XISFParsingOptions`` controls how strictly the preamble is validated; for
/// example a non-zero reserved field is rejected unless
/// ``XISFParsingOptions/allowSpecDeviations`` is set.
///
/// This is a reference type holding parsed file state; it is not `Sendable`.
public class XISFFile: CustomStringConvertible
{
    /// The 8-byte ASCII signature that opens every monolithic XISF file.
    public static let signature = "XISF0100"

    /// The size, in bytes, of the binary preamble: the 8-byte signature, the
    /// 4-byte little-endian header-length field, and the 4-byte reserved field.
    /// The XML header begins immediately after, at this offset.
    public static let preambleSize = 16

    /// The XML namespace declared by the root `xisf` element.
    public static let namespace = "http://www.pixinsight.com/xisf"

    /// The raw UTF-8 XML header, as a string.
    ///
    /// This is the verbatim header text; the parsed element tree is available
    /// internally as ``root``.
    public let headerXML: String

    /// The root `xisf` element of the parsed XML header.
    internal let root: XISFElement

    /// The local names of the root's direct child elements, in document order
    /// (for example `Image`, `Property`, `FITSKeyword`).
    public var headerElementNames: [ String ]
    {
        self.root.children.map { $0.name }
    }

    /// The unit-level (top-level) properties, in document order, including
    /// data-block-backed vector, matrix and `ByteArray` values.
    public let properties: [ XISFProperty ]

    /// The unit-level (top-level) embedded FITS keywords, in document order.
    public let keywords: [ XISFFITSKeyword ]

    /// The images contained in the unit, in document order.
    public let images: [ XISFImage ]

    /// The first property whose identifier matches, or `nil` if none does.
    ///
    /// - Parameter id: The property identifier to look up.
    /// - Returns: The first matching property, or `nil`.
    public subscript( id: String ) -> XISFProperty?
    {
        self.properties.first { $0.id == id }
    }

    /// The embedded FITS keywords with a given name, in document order.
    ///
    /// A name may appear more than once (notably `HISTORY` and `COMMENT`), so
    /// this returns every match.
    ///
    /// - Parameter name: The keyword name to look up.
    /// - Returns: The matching keywords, in document order.
    public func keywords( named name: String ) -> [ XISFFITSKeyword ]
    {
        self.keywords.filter { $0.name == name }
    }

    /// Reads and parses an XISF file from a file URL.
    ///
    /// - Parameters:
    ///   - url: The location of the file to read.
    ///   - options: The parsing options to apply.
    /// - Throws: ``XISFError/invalidFileURL(url:)`` if the URL is missing or a
    ///   directory, ``XISFError/cannotReadFile(url:)`` if the contents cannot be
    ///   read, or any ``XISFError`` raised while parsing the data.
    /// - Note: The file is memory-mapped when safe (`.mappedIfSafe`). If another
    ///   process truncates the file while it is being parsed, accessing the
    ///   vanished pages can raise `SIGBUS` and terminate the process, which no
    ///   Swift error handling can intercept.
    public convenience init( url: URL, options: XISFParsingOptions ) throws
    {
        let data: Data

        do
        {
            data = try Data( contentsOf: url, options: .mappedIfSafe )
        }
        catch
        {
            // Classify the failure only after attempting the read, so there is
            // no time-of-check/time-of-use gap: a missing path or a directory is
            // an invalid URL, anything else is an unreadable file.
            var isDirectory: ObjCBool = false

            if FileManager.default.fileExists( atPath: url.path, isDirectory: &isDirectory ) == false || isDirectory.boolValue
            {
                throw XISFError.invalidFileURL( url: url )
            }

            throw XISFError.cannotReadFile( url: url )
        }

        try self.init( data: data, options: options )
    }

    /// Parses an XISF file from raw bytes.
    ///
    /// Validates the binary preamble (signature, header-length field and
    /// reserved field), slices out the UTF-8 XML header, parses it into an
    /// element tree, and validates the `xisf` root element.
    ///
    /// - Parameters:
    ///   - data: The complete file contents.
    ///   - options: The parsing options to apply.
    /// - Throws: ``XISFError/dataError(reason:)`` if the data is empty,
    ///   ``XISFError/invalidSignature(reason:)`` if the signature or reserved
    ///   field is invalid, ``XISFError/invalidHeaderLength(reason:)`` if the
    ///   header-length field is zero or extends past the end of the file,
    ///   ``XISFError/malformedXML(reason:)`` if the header bytes are not valid
    ///   UTF-8 or not well-formed XML, or ``XISFError/invalidElement(reason:)``
    ///   if the root element is not a valid `xisf` element.
    public init( data: Data, options: XISFParsingOptions ) throws
    {
        guard data.isEmpty == false
        else
        {
            throw XISFError.dataError( reason: "Data is empty" )
        }

        guard data.matchesASCII( XISFFile.signature, at: 0 )
        else
        {
            throw XISFError.invalidSignature( reason: "File does not start with the \( XISFFile.signature ) signature" )
        }

        guard data.count >= XISFFile.preambleSize
        else
        {
            throw XISFError.invalidHeaderLength( reason: "File is smaller than the \( XISFFile.preambleSize )-byte preamble" )
        }

        let reserved = try data.littleEndianInteger( at: 12, as: UInt32.self )

        if reserved != 0, options.contains( .allowSpecDeviations ) == false
        {
            throw XISFError.invalidSignature( reason: "Reserved preamble field at offset 12 is not zero (\( reserved ))" )
        }

        let headerLength = Int( try data.littleEndianInteger( at: 8, as: UInt32.self ) )

        guard headerLength > 0
        else
        {
            throw XISFError.invalidHeaderLength( reason: "Header length is zero" )
        }

        guard XISFFile.preambleSize + headerLength <= data.count
        else
        {
            throw XISFError.invalidHeaderLength( reason: "XML header (\( headerLength ) bytes) extends past the end of the \( data.count )-byte file" )
        }

        let headerData = try data.bytes( at: XISFFile.preambleSize, count: headerLength )

        guard let headerXML = String( data: headerData, encoding: .utf8 )
        else
        {
            throw XISFError.malformedXML( reason: "XML header is not valid UTF-8" )
        }

        let root = try XISFXMLParser.parse( headerXML )

        try XISFFile.validateRoot( root, options: options )

        self.headerXML  = headerXML
        self.root       = root
        self.properties = try XISFProperty.parseList( from: root, fileData: data, options: options )
        self.keywords   = try root.children( named: "FITSKeyword" ).map { try XISFFITSKeyword( element: $0, options: options ) }
        self.images     = try root.children( named: "Image" ).map { try XISFImage( element: $0, fileData: data, options: options ) }
    }


    /// Validates the root element of a parsed XISF header.
    ///
    /// The root must be an `xisf` element in the XISF namespace (or in no
    /// namespace, tolerating headers that omit the declaration); an element in
    /// any other namespace is rejected. The `version` attribute must be `1.0`
    /// unless ``XISFParsingOptions/allowSpecDeviations`` is set, which tolerates
    /// a missing or different version.
    ///
    /// - Parameters:
    ///   - root: The root element to validate.
    ///   - options: The parsing options to apply.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if the root is not a
    ///   valid `xisf` element.
    private static func validateRoot( _ root: XISFElement, options: XISFParsingOptions ) throws
    {
        guard root.name == "xisf"
        else
        {
            throw XISFError.invalidElement( reason: "Expected root element 'xisf' but found '\( root.name )'" )
        }

        if let namespace = root.namespaceURI, namespace.isEmpty == false, namespace != XISFFile.namespace
        {
            throw XISFError.invalidElement( reason: "Root element 'xisf' is in an unexpected namespace: \( namespace )" )
        }

        if options.contains( .allowSpecDeviations ) == false
        {
            guard root.attributes[ "version" ] == "1.0"
            else
            {
                let found = root.attributes[ "version" ].map { "'\( $0 )'" } ?? "no version attribute"

                throw XISFError.invalidElement( reason: "Expected XISF version '1.0' but found \( found )" )
            }
        }
    }

    /// A multi-line, human-readable summary of the file.
    public var description: String
    {
        """
        XISFFile
        {
            Header: \( self.headerXML.count ) characters
        }
        """
    }
}
