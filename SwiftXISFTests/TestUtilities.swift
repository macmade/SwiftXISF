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

/// Shared fixtures and monolithic-file construction helpers for the test suite.
class TestUtilities
{
    /// The default XML header used by the synthetic monolithic-file builder: a
    /// minimal, well-formed and namespaced `xisf` root with no children.
    static let defaultHeaderXML = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\"/>"

    /// The sample `.xisf` files used as parsing fixtures.
    ///
    /// Under SwiftPM the fixtures are located relative to this source file's
    /// `#filePath` (they live at the repository root, outside any target).
    /// In a bundled build they are loaded from the test bundle's resources.
    /// Returned sorted by file name.
    public static var testFiles: [ URL ]
    {
        #if SWIFT_PACKAGE

            // The heavy "Test Files" fixtures live at the repository root, which
            // is outside any SPM target directory, so they cannot be bundled as
            // package resources. A test target is only ever run from its own
            // checkout, so we locate the fixtures relative to this source file's
            // compile-time path (#filePath -> SwiftXISFTests/ -> repository root).
            let root = URL( fileURLWithPath: #filePath )
                .deletingLastPathComponent() // SwiftXISFTests
                .deletingLastPathComponent() // repository root
                .appendingPathComponent( "Test Files" )

            guard let enumerator = FileManager.default.enumerator( at: root, includingPropertiesForKeys: nil )
            else
            {
                return []
            }

            return enumerator.compactMap { $0 as? URL }.filter
            {
                $0.pathExtension == "xisf"
            }
            .sorted
            {
                $0.lastPathComponent < $1.lastPathComponent
            }

        #else

            return ( Bundle( for: self ).urls( forResourcesWithExtension: "xisf", subdirectory: nil ) ?? [] )
                .sorted
                {
                    $0.lastPathComponent < $1.lastPathComponent
                }

        #endif
    }

    /// Builds a synthetic monolithic-file byte stream.
    ///
    /// Assembles the 16-byte binary preamble — the ASCII signature, the
    /// little-endian `UInt32` header-length field, and the reserved field —
    /// followed by the UTF-8 XML header and any attached data-block bytes,
    /// exactly as a real monolithic XISF file is laid out.
    ///
    /// - Parameters:
    ///   - signature: The 8-byte signature to write (overridable to test rejection).
    ///   - headerLength: The header-length field to write; when `nil`, the actual
    ///     UTF-8 byte count of `xml` is used (overridable to test rejection).
    ///   - reserved: The reserved preamble field to write (overridable to test rejection).
    ///   - xml: The XML header text.
    ///   - attachment: The bytes to append after the header, at file offsets that
    ///     `attachment:position:size` locations can reference.
    /// - Returns: The assembled monolithic-file bytes.
    class func monolithicFile( signature: String = XISFFile.signature, headerLength: UInt32? = nil, reserved: UInt32 = 0, xml: String = TestUtilities.defaultHeaderXML, attachment: Data = Data() ) -> Data
    {
        let xmlData = Data( xml.utf8 )
        var data    = Data()

        data.append( contentsOf: Array( signature.utf8 ) )
        withUnsafeBytes( of: ( headerLength ?? UInt32( xmlData.count ) ).littleEndian ) { data.append( contentsOf: $0 ) }
        withUnsafeBytes( of: reserved.littleEndian )                                   { data.append( contentsOf: $0 ) }
        data.append( xmlData )
        data.append( attachment )

        return data
    }

    @Test
    func hasTestFiles() async throws
    {
        #expect( TestUtilities.testFiles.isEmpty == false )
    }

    @Test
    func testFilesAreXISF() async throws
    {
        TestUtilities.testFiles.forEach
        {
            #expect( $0.pathExtension == "xisf" )
        }
    }

    @Test
    func monolithicFileHasPreambleAndHeader() async throws
    {
        let xml  = "<?xml version=\"1.0\"?><xisf version=\"1.0\"/>"
        let data = TestUtilities.monolithicFile( xml: xml )

        try #require( data.count == XISFFile.preambleSize + Data( xml.utf8 ).count )

        // The synthetic file must be a valid, parseable monolithic file.
        let file = try XISFFile( data: data, options: .strict )

        #expect( file.headerXML == xml )
    }

    @Test
    func monolithicFileAppendsAttachment() async throws
    {
        let xml        = "<?xml version=\"1.0\"?><xisf version=\"1.0\"/>"
        let attachment = Data( [ 0xDE, 0xAD, 0xBE, 0xEF ] )
        let data       = TestUtilities.monolithicFile( xml: xml, attachment: attachment )

        #expect( data.count == XISFFile.preambleSize + Data( xml.utf8 ).count + attachment.count )
        #expect( data.suffix( attachment.count ) == attachment )
    }
}
