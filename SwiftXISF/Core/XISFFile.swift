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

    /// The raw UTF-8 XML header, as a string.
    ///
    /// This is the verbatim header text; parsing it into a typed element tree is
    /// performed by later stages.
    public let headerXML: String

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
    /// reserved field) and slices out the UTF-8 XML header.
    ///
    /// - Parameters:
    ///   - data: The complete file contents.
    ///   - options: The parsing options to apply.
    /// - Throws: ``XISFError/dataError(reason:)`` if the data is empty,
    ///   ``XISFError/invalidSignature(reason:)`` if the signature or reserved
    ///   field is invalid, ``XISFError/invalidHeaderLength(reason:)`` if the
    ///   header-length field is zero or extends past the end of the file, or
    ///   ``XISFError/malformedXML(reason:)`` if the header bytes are not valid
    ///   UTF-8.
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

        self.headerXML = headerXML
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
