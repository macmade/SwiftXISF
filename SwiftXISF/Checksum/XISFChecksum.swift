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

import CryptoKit
import Foundation

/// A data block's checksum, parsed from its `checksum` attribute.
///
/// An XISF `checksum` attribute has the form `algorithm:digest`, where the
/// digest is lowercase base16 (hexadecimal). The digest is computed over the
/// block's *stored* (as-on-disk, still-compressed) bytes, so verification
/// happens before decompression.
///
/// The SHA-3 algorithms rely on `CryptoKit` support that is only available on
/// recent operating systems; on older systems ``matches(_:)`` / ``verify(_:)``
/// throw ``XISFError/unsupported(reason:)`` rather than silently passing.
public struct XISFChecksum: Equatable, Sendable, CustomStringConvertible
{
    /// A supported checksum algorithm.
    public enum Algorithm: Equatable, Sendable
    {
        /// SHA-1 (accepts the `sha-1` and `sha1` spellings).
        case sha1

        /// SHA-256 (accepts the `sha-256` and `sha256` spellings).
        case sha256

        /// SHA-512 (accepts the `sha-512` and `sha512` spellings).
        case sha512

        /// SHA3-256.
        case sha3_256

        /// SHA3-512.
        case sha3_512

        /// Creates an algorithm from its XISF attribute spelling.
        ///
        /// - Parameter name: The algorithm name, matched case-insensitively.
        public init?( name: String )
        {
            switch name.lowercased()
            {
                case "sha-1", "sha1":     self = .sha1
                case "sha-256", "sha256": self = .sha256
                case "sha-512", "sha512": self = .sha512
                case "sha3-256":          self = .sha3_256
                case "sha3-512":          self = .sha3_512
                default:                  return nil
            }
        }

        /// The canonical XISF spelling of the algorithm.
        public var name: String
        {
            switch self
            {
                case .sha1:     return "sha-1"
                case .sha256:   return "sha-256"
                case .sha512:   return "sha-512"
                case .sha3_256: return "sha3-256"
                case .sha3_512: return "sha3-512"
            }
        }
    }

    /// The checksum algorithm.
    public let algorithm: Algorithm

    /// The declared digest, as a base16 (hexadecimal) string.
    public let digest: String

    /// Parses a `checksum` attribute of the form `algorithm:digest`.
    ///
    /// - Parameter attribute: The raw `checksum` attribute value.
    /// - Throws: ``XISFError/unsupported(reason:)`` if the algorithm is not
    ///   recognized, or ``XISFError/invalidElement(reason:)`` if the attribute
    ///   is malformed or has an empty digest.
    public init( attribute: String ) throws
    {
        guard let separator = attribute.firstIndex( of: ":" )
        else
        {
            throw XISFError.invalidElement( reason: "Malformed checksum attribute (expected 'algorithm:digest'): '\( attribute )'" )
        }

        let name   = String( attribute[ ..<separator ] )
        let digest = String( attribute[ attribute.index( after: separator )... ] )

        guard let algorithm = Algorithm( name: name )
        else
        {
            throw XISFError.unsupported( reason: "Unsupported checksum algorithm: '\( name )'" )
        }

        guard digest.isEmpty == false
        else
        {
            throw XISFError.invalidElement( reason: "Checksum attribute has an empty digest: '\( attribute )'" )
        }

        self.algorithm = algorithm
        self.digest    = digest
    }

    /// Returns whether the checksum matches the digest of the given bytes.
    ///
    /// - Parameter data: The bytes to hash (a data block's stored bytes).
    /// - Returns: `true` if the computed digest equals the declared digest.
    /// - Throws: ``XISFError/unsupported(reason:)`` if the algorithm has no
    ///   implementation on the current operating-system version.
    public func matches( _ data: Data ) throws -> Bool
    {
        try self.computedDigest( data ) == self.digest.lowercased()
    }

    /// Verifies that the checksum matches the digest of the given bytes.
    ///
    /// - Parameter data: The bytes to hash (a data block's stored bytes).
    /// - Throws: ``XISFError/checksumMismatch(reason:)`` if the digests differ,
    ///   or ``XISFError/unsupported(reason:)`` if the algorithm has no
    ///   implementation on the current operating-system version.
    public func verify( _ data: Data ) throws
    {
        guard try self.matches( data )
        else
        {
            throw XISFError.checksumMismatch( reason: "\( self.algorithm.name ) digest of the \( data.count )-byte data block does not match the declared checksum" )
        }
    }

    /// Computes the lowercase base16 digest of the given bytes.
    ///
    /// - Parameter data: The bytes to hash.
    /// - Returns: The digest as a lowercase hexadecimal string.
    /// - Throws: ``XISFError/unsupported(reason:)`` if CryptoKit is unavailable
    ///   (below macOS 10.15 / iOS 13), or if a SHA-3 algorithm is requested on an
    ///   operating system that does not provide it (below macOS 26 / iOS 26) or in
    ///   a build made against an SDK that predates the CryptoKit SHA-3 types.
    private func computedDigest( _ data: Data ) throws -> String
    {
        // CryptoKit is unavailable below macOS 10.15 / iOS 13. Guarding here (so
        // no availability floor is imposed on the package) means checksum
        // verification degrades to a clean "unsupported" error on older systems
        // rather than being a compile-time requirement.
        guard #available( macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, * )
        else
        {
            throw XISFError.unsupported( reason: "Checksum verification requires macOS 10.15 / iOS 13 or newer" )
        }

        switch self.algorithm
        {
            case .sha1:   return XISFChecksum.hexString( Insecure.SHA1.hash( data: data ) )
            case .sha256: return XISFChecksum.hexString( SHA256.hash( data: data ) )
            case .sha512: return XISFChecksum.hexString( SHA512.hash( data: data ) )

            // The SHA3_256 / SHA3_512 types were introduced in the macOS 26 SDK
            // (the Swift 6.2 toolchain), so they cannot even be referenced when
            // building against an older SDK — a runtime #available guard is not
            // enough. The #if compiler check compiles the SHA-3 path in only when
            // the toolchain provides the symbols; on older toolchains, and at
            // runtime below macOS 26, verification degrades to a clean
            // "unsupported" error.
            case .sha3_256:
                #if compiler(>=6.2)
                if #available( macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, * )
                {
                    return XISFChecksum.hexString( SHA3_256.hash( data: data ) )
                }
                #endif

                throw XISFError.unsupported( reason: "sha3-256 checksum verification requires macOS 26 / iOS 26 or newer, built with the matching SDK" )

            case .sha3_512:
                #if compiler(>=6.2)
                if #available( macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, * )
                {
                    return XISFChecksum.hexString( SHA3_512.hash( data: data ) )
                }
                #endif

                throw XISFError.unsupported( reason: "sha3-512 checksum verification requires macOS 26 / iOS 26 or newer, built with the matching SDK" )
        }
    }

    /// Formats a digest's bytes as a lowercase base16 string.
    ///
    /// - Parameter hash: The digest bytes.
    /// - Returns: The lowercase hexadecimal representation.
    private static func hexString<H: Sequence>( _ hash: H ) -> String where H.Element == UInt8
    {
        hash.map { String( format: "%02x", $0 ) }.joined()
    }

    /// A single-line, human-readable summary of the checksum.
    public var description: String
    {
        "XISFChecksum { \( self.algorithm.name ): \( self.digest ) }"
    }
}
