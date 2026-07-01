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

struct Test_XISFExternalDataBlock
{
    private static let external: XISFParsingOptions = [ .allowExternalLocations ]

    /// Builds a data block from a `location` attribute.
    private static func block( location: String, baseURL: URL?, options: XISFParsingOptions ) throws -> XISFDataBlock
    {
        try XISFDataBlock( element: XISFXMLParser.parse( "<Image location=\"\( location )\"/>" ), fileData: Data(), baseURL: baseURL, options: options )
    }

    /// Creates a unique temporary directory and returns its URL.
    private static func makeTemporaryDirectory() throws -> URL
    {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent( "SwiftXISF-\( UUID().uuidString )", isDirectory: true )

        try FileManager.default.createDirectory( at: url, withIntermediateDirectories: true )

        return url
    }

    /// Encodes an unsigned 64-bit integer as little-endian bytes.
    private static func le64( _ value: UInt64 ) -> [ UInt8 ]
    {
        ( 0 ..< 8 ).map { UInt8( ( value >> ( $0 * 8 ) ) & 0xFF ) }
    }

    /// Encodes an unsigned 32-bit integer as little-endian bytes.
    private static func le32( _ value: UInt32 ) -> [ UInt8 ]
    {
        ( 0 ..< 4 ).map { UInt8( ( value >> ( $0 * 8 ) ) & 0xFF ) }
    }

    /// Builds a minimal single-node XISF data blocks file whose block index
    /// contains one element with the given id, pointing to `payload`.
    private static func dataBlocksFile( id: UInt64, payload: [ UInt8 ] ) -> Data
    {
        // Header (16) + node header (16) + one element (40) = payload position 72.
        let position = UInt64( 72 )
        var bytes    = Array( "XISB0100".utf8 ) + [ UInt8 ]( repeating: 0, count: 8 )

        bytes += Test_XISFExternalDataBlock.le32( 1 )                                  // element count
        bytes += [ UInt8 ]( repeating: 0, count: 4 )                                   // reserved
        bytes += Test_XISFExternalDataBlock.le64( 0 )                                  // next node (none)
        bytes += Test_XISFExternalDataBlock.le64( id )                                 // unique id
        bytes += Test_XISFExternalDataBlock.le64( position )                           // block position
        bytes += Test_XISFExternalDataBlock.le64( UInt64( payload.count ) )            // block length
        bytes += Test_XISFExternalDataBlock.le64( 0 )                                  // uncompressed length
        bytes += [ UInt8 ]( repeating: 0, count: 8 )                                   // reserved
        bytes += payload

        return Data( bytes )
    }

    @Test
    func resolvesAbsolutePathWholeFile() throws
    {
        let directory = try Test_XISFExternalDataBlock.makeTemporaryDirectory()
        let file      = directory.appendingPathComponent( "block.bin" )

        defer { try? FileManager.default.removeItem( at: directory ) }

        try Data( [ 0xDE, 0xAD, 0xBE, 0xEF ] ).write( to: file )

        let block = try Test_XISFExternalDataBlock.block( location: "path(\( file.path ))", baseURL: nil, options: Test_XISFExternalDataBlock.external )

        #expect( try block.data == Data( [ 0xDE, 0xAD, 0xBE, 0xEF ] ) )
    }

    @Test
    func resolvesHeaderRelativePathWholeFile() throws
    {
        let directory = try Test_XISFExternalDataBlock.makeTemporaryDirectory()
        let file      = directory.appendingPathComponent( "block.bin" )

        defer { try? FileManager.default.removeItem( at: directory ) }

        try Data( [ 0x01, 0x02, 0x03 ] ).write( to: file )

        let block = try Test_XISFExternalDataBlock.block( location: "path(@header_dir/block.bin)", baseURL: directory, options: Test_XISFExternalDataBlock.external )

        #expect( try block.data == Data( [ 0x01, 0x02, 0x03 ] ) )
    }

    @Test
    func resolvesDataBlocksFileByIndexID() throws
    {
        let directory = try Test_XISFExternalDataBlock.makeTemporaryDirectory()
        let file      = directory.appendingPathComponent( "blocks.xisb" )

        defer { try? FileManager.default.removeItem( at: directory ) }

        try Test_XISFExternalDataBlock.dataBlocksFile( id: 0x2A, payload: [ 0x11, 0x22, 0x33, 0x44 ] ).write( to: file )

        let block = try Test_XISFExternalDataBlock.block( location: "path(@header_dir/blocks.xisb):0x2a", baseURL: directory, options: Test_XISFExternalDataBlock.external )

        #expect( try block.data == Data( [ 0x11, 0x22, 0x33, 0x44 ] ) )
    }

    @Test
    func rejectsUnknownIndexID() throws
    {
        let directory = try Test_XISFExternalDataBlock.makeTemporaryDirectory()
        let file      = directory.appendingPathComponent( "blocks.xisb" )

        defer { try? FileManager.default.removeItem( at: directory ) }

        try Test_XISFExternalDataBlock.dataBlocksFile( id: 0x2A, payload: [ 0x11 ] ).write( to: file )

        let block = try Test_XISFExternalDataBlock.block( location: "path(@header_dir/blocks.xisb):0x99", baseURL: directory, options: Test_XISFExternalDataBlock.external )

        #expect( throws: XISFError.self ) { _ = try block.data }
    }

    @Test
    func rejectsExternalResolutionWhenDisabled() throws
    {
        let directory = try Test_XISFExternalDataBlock.makeTemporaryDirectory()
        let file      = directory.appendingPathComponent( "block.bin" )

        defer { try? FileManager.default.removeItem( at: directory ) }

        try Data( [ 0x01 ] ).write( to: file )

        // Constructing the block succeeds (external resolution is lazy); reading
        // it fails because the option is not enabled.
        let block = try Test_XISFExternalDataBlock.block( location: "path(\( file.path ))", baseURL: nil, options: .strict )

        #expect( throws: XISFError.self ) { _ = try block.data }
    }

    @Test
    func rejectsMissingExternalFile() throws
    {
        let directory = try Test_XISFExternalDataBlock.makeTemporaryDirectory()

        defer { try? FileManager.default.removeItem( at: directory ) }

        let block = try Test_XISFExternalDataBlock.block( location: "path(@header_dir/does-not-exist.bin)", baseURL: directory, options: Test_XISFExternalDataBlock.external )

        #expect( throws: XISFError.self ) { _ = try block.data }
    }

    @Test
    func rejectsHeaderRelativeWithoutBaseURL() throws
    {
        let block = try Test_XISFExternalDataBlock.block( location: "path(@header_dir/block.bin)", baseURL: nil, options: Test_XISFExternalDataBlock.external )

        #expect( throws: XISFError.self ) { _ = try block.data }
    }

    @Test
    func rejectsRemoteURL() throws
    {
        let block = try Test_XISFExternalDataBlock.block( location: "url(http://example.com/block.bin)", baseURL: nil, options: Test_XISFExternalDataBlock.external )

        #expect( throws: XISFError.self ) { _ = try block.data }
    }

    @Test
    func uncompressedSizeUnknownForExternalUncompressedBlock() throws
    {
        let block = try Test_XISFExternalDataBlock.block( location: "path(/data/x.bin)", baseURL: nil, options: Test_XISFExternalDataBlock.external )

        #expect( block.uncompressedSize == nil )
    }
}
