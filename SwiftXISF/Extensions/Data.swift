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

/// Byte-level helpers used to read and validate the binary parts of an XISF
/// monolithic file.
///
/// Every offset is interpreted relative to the data's own ``startIndex``, so
/// the helpers behave identically on a full `Data` value and on a slice of one.
public extension Data
{
    /// Returns a sub-range of the data, bounds-checked.
    ///
    /// - Parameters:
    ///   - offset: The number of bytes from ``startIndex`` at which the range
    ///             begins. Must be non-negative.
    ///   - count:  The number of bytes to return. Must be non-negative.
    /// - Returns: A slice of `count` bytes beginning at `offset`. The slice
    ///            keeps the receiver's indices, so it is itself safe to pass
    ///            back into these helpers.
    /// - Throws: ``XISFError/dataError(reason:)`` if `offset` or `count` is
    ///           negative, or if the requested range extends past the end of
    ///           the data.
    func bytes( at offset: Int, count: Int ) throws -> Data
    {
        if offset < 0 || count < 0
        {
            throw XISFError.dataError( reason: "Negative offset or count" )
        }

        let start = self.startIndex + offset
        let end   = start + count

        if end > self.endIndex
        {
            throw XISFError.dataError( reason: "Requested range \( offset )..<\( offset + count ) is out of bounds for \( self.count ) bytes" )
        }

        return self[ start ..< end ]
    }

    /// Reads a little-endian, fixed-width integer from the data.
    ///
    /// XISF stores the monolithic-file header-length field as a little-endian
    /// `UInt32`; this helper covers that and any other little-endian field.
    ///
    /// - Parameters:
    ///   - offset: The number of bytes from ``startIndex`` at which the integer
    ///             begins.
    ///   - type:   The integer type to read; its size determines how many bytes
    ///             are consumed.
    /// - Returns: The decoded integer.
    /// - Throws: ``XISFError/dataError(reason:)`` if the integer's bytes extend
    ///           past the end of the data.
    func littleEndianInteger<T: FixedWidthInteger>( at offset: Int, as type: T.Type ) throws -> T
    {
        let bytes     = try self.bytes( at: offset, count: MemoryLayout<T>.size )
        let magnitude = bytes.enumerated().reduce( into: T.Magnitude( 0 ) )
        {
            $0 |= T.Magnitude( $1.element ) << ( 8 * $1.offset )
        }

        return T( truncatingIfNeeded: magnitude )
    }

    /// Returns whether the bytes at a given offset equal the ASCII encoding of a
    /// string.
    ///
    /// Used to match fixed binary markers such as the `XISF0100` signature.
    ///
    /// - Parameters:
    ///   - string: The ASCII string to compare against. A string that is not
    ///             representable as ASCII never matches.
    ///   - offset: The number of bytes from ``startIndex`` at which to compare.
    /// - Returns: `true` if the data contains exactly the ASCII bytes of
    ///            `string` at `offset`; otherwise `false`.
    func matchesASCII( _ string: String, at offset: Int ) -> Bool
    {
        guard let ascii = string.data( using: .ascii ),
              let slice = try? self.bytes( at: offset, count: ascii.count )
        else
        {
            return false
        }

        return slice.elementsEqual( ascii )
    }
}
