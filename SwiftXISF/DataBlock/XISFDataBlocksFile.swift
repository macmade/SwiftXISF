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

/// Reads XISF data blocks files (`.xisb`) to resolve a data block by its block
/// index element identifier.
///
/// A data blocks file begins with an 8-byte `XISB0100` signature and an 8-byte
/// reserved field, followed by a singly-linked list of *block index nodes*. Each
/// node stores a 32-bit element count, a 4-byte reserved field, a 64-bit
/// position of the next node (zero when it is the last), and then that many
/// 40-byte *block index elements*. Each element carries a 64-bit unique
/// identifier, the block's 64-bit position and length, a 64-bit uncompressed
/// length, and an 8-byte reserved field. All integers are little-endian.
///
/// This type is internal infrastructure used by ``XISFDataBlock`` to resolve
/// `url(...):index-id` and `path(...):index-id` locations.
internal enum XISFDataBlocksFile
{
    /// The 8-byte ASCII signature that opens every XISF data blocks file.
    internal static let signature = "XISB0100"

    /// The size, in bytes, of the fixed header (signature plus reserved field)
    /// preceding the first block index node.
    internal static let headerSize = 16

    /// The size, in bytes, of a single block index element.
    internal static let elementSize = 40

    /// Resolves the bytes of the data block identified by `indexID` in a data
    /// blocks file.
    ///
    /// - Parameters:
    ///   - indexID: The unique identifier of the block index element to locate.
    ///   - data: The complete contents of the data blocks file.
    /// - Returns: The raw (still as-stored) bytes of the located block.
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if the signature is
    ///   invalid, the block index is malformed or truncated, the identifier is
    ///   not found, or the located block range is out of bounds.
    internal static func block( withID indexID: UInt64, in data: Data ) throws -> Data
    {
        guard data.matchesASCII( XISFDataBlocksFile.signature, at: 0 )
        else
        {
            throw XISFError.dataBlockError( reason: "External file is not an XISF data blocks file (missing the \( XISFDataBlocksFile.signature ) signature)" )
        }

        guard let element = try XISFDataBlocksFile.findElement( withID: indexID, in: data )
        else
        {
            throw XISFError.dataBlockError( reason: "No block index element with id 0x\( String( indexID, radix: 16 ) ) in the XISF data blocks file" )
        }

        guard let bytes = try? data.bytes( at: element.position, count: element.length )
        else
        {
            throw XISFError.dataBlockError( reason: "Block index element 0x\( String( indexID, radix: 16 ) ) points to an out-of-bounds range (position \( element.position ), length \( element.length ))" )
        }

        return bytes
    }

    /// A resolved block index element: the position and length of a data block.
    private struct Element
    {
        /// The byte position of the block, from the start of the file.
        let position: Int

        /// The length of the block, in bytes.
        let length: Int
    }

    /// Walks the singly-linked list of block index nodes to find the element
    /// with a given identifier.
    ///
    /// - Parameters:
    ///   - indexID: The unique identifier to find.
    ///   - data: The complete contents of the data blocks file.
    /// - Returns: The matching element, or `nil` if the identifier is not found.
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if a node extends past the
    ///   end of the file or the node chain is cyclic.
    private static func findElement( withID indexID: UInt64, in data: Data ) throws -> Element?
    {
        var nodePosition = XISFDataBlocksFile.headerSize
        var visited      = Set<Int>()

        while nodePosition != 0
        {
            guard visited.insert( nodePosition ).inserted
            else
            {
                throw XISFError.dataBlockError( reason: "Cyclic block index in the XISF data blocks file" )
            }

            guard let count = try? data.littleEndianInteger( at: nodePosition, as: UInt32.self ),
                  let next  = try? data.littleEndianInteger( at: nodePosition + 8, as: UInt64.self )
            else
            {
                throw XISFError.dataBlockError( reason: "Truncated block index node at position \( nodePosition )" )
            }

            let elementsStart = nodePosition + 16

            if let element = try XISFDataBlocksFile.element( withID: indexID, count: Int( count ), start: elementsStart, in: data )
            {
                return element
            }

            nodePosition = Int( next )
        }

        return nil
    }

    /// Scans the elements of a single block index node for a matching identifier.
    ///
    /// - Parameters:
    ///   - indexID: The unique identifier to find.
    ///   - count: The number of elements in the node.
    ///   - start: The byte position of the first element.
    ///   - data: The complete contents of the data blocks file.
    /// - Returns: The matching element, or `nil` if not found in this node.
    /// - Throws: ``XISFError/dataBlockError(reason:)`` if an element extends past
    ///   the end of the file.
    private static func element( withID indexID: UInt64, count: Int, start: Int, in data: Data ) throws -> Element?
    {
        for index in 0 ..< count
        {
            let base = start + index * XISFDataBlocksFile.elementSize

            guard let identifier = try? data.littleEndianInteger( at: base, as: UInt64.self ),
                  let position   = try? data.littleEndianInteger( at: base + 8, as: UInt64.self ),
                  let length     = try? data.littleEndianInteger( at: base + 16, as: UInt64.self )
            else
            {
                throw XISFError.dataBlockError( reason: "Truncated block index element at position \( base )" )
            }

            if identifier == indexID
            {
                return Element( position: Int( position ), length: Int( length ) )
            }
        }

        return nil
    }
}
