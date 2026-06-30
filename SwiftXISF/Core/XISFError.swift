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

/// The errors thrown by SwiftXISF when reading or validating XISF data.
public enum XISFError: LocalizedError, CustomStringConvertible, Sendable
{
    /// The provided URL does not point to a readable file (e.g. it is missing
    /// or refers to a directory).
    case invalidFileURL( url: URL )

    /// The file at the given URL exists but its contents could not be read.
    case cannotReadFile( url: URL )

    /// The monolithic-file binary preamble is invalid — either the signature is
    /// not the expected `XISF0100` marker, or the reserved field is non-zero;
    /// `reason` describes the specific problem.
    case invalidSignature( reason: String )

    /// The XML-header length field is invalid (e.g. zero, or extending past the
    /// end of the file); `reason` describes the specific problem.
    case invalidHeaderLength( reason: String )

    /// The XML header could not be parsed as well-formed XML; `reason` describes
    /// the specific problem.
    case malformedXML( reason: String )

    /// An XML element or attribute is missing, malformed, or carries an invalid
    /// value; `reason` describes the specific problem.
    case invalidElement( reason: String )

    /// A data block's bytes could not be resolved from its declared location;
    /// `reason` describes the specific problem.
    case dataBlockError( reason: String )

    /// A compressed data block could not be decompressed; `reason` describes the
    /// specific problem.
    case decompressionError( reason: String )

    /// A data block's computed digest does not match its declared checksum;
    /// `reason` describes the specific problem.
    case checksumMismatch( reason: String )

    /// A low-level data operation failed; `reason` describes the specific
    /// problem.
    case dataError( reason: String )

    /// A human-readable description prefixed with `XISF Error:`.
    public var description: String
    {
        "XISF Error: \( self.errorDescription ?? "Unknown error" )"
    }

    /// A localized message describing the error and its cause.
    public var errorDescription: String?
    {
        switch self
        {
            case .invalidFileURL( let url ):         return "Invalid file URL: \( url )"
            case .cannotReadFile( let url ):         return "Cannot read file: \( url )"
            case .invalidSignature( let reason ):    return "Invalid signature: \( reason )"
            case .invalidHeaderLength( let reason ): return "Invalid header length: \( reason )"
            case .malformedXML( let reason ):        return "Malformed XML: \( reason )"
            case .invalidElement( let reason ):      return "Invalid element: \( reason )"
            case .dataBlockError( let reason ):      return "Data block error: \( reason )"
            case .decompressionError( let reason ):  return "Decompression error: \( reason )"
            case .checksumMismatch( let reason ):    return "Checksum mismatch: \( reason )"
            case .dataError( let reason ):           return "Data error: \( reason )"
        }
    }
}
