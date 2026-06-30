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

/// Options controlling how strictly XISF data is parsed and validated.
///
/// The individual flags toggle independent behaviors; the ``strict`` and
/// ``lenient`` presets bundle sensible defaults. ``strict`` validates as much
/// as possible (including data-block checksums) and rejects any spec deviation,
/// while ``lenient`` tolerates the technically-noncompliant constructs found in
/// real-world files. Both presets leave external/distributed data-block
/// resolution disabled; it must be opted into explicitly for security.
public struct XISFParsingOptions: OptionSet, Sendable
{
    /// The raw bitmask backing the option set.
    public let rawValue: Int

    /// Creates an option set from its raw bitmask value.
    ///
    /// - Parameter rawValue: The bitmask of enabled options.
    public init( rawValue: Int )
    {
        self.rawValue = rawValue
    }

    /// Verify a data block's declared checksum against its computed digest,
    /// throwing ``XISFError/checksumMismatch(reason:)`` on a mismatch. When
    /// unset, declared checksums are ignored.
    public static let verifyChecksums = XISFParsingOptions( rawValue: 1 << 0 )

    /// Allow resolving data blocks whose location refers to an external or
    /// distributed file (`url(...)` / `path(...)`). Disabled by default because
    /// resolving such locations reads files outside the parsed document.
    public static let allowExternalLocations = XISFParsingOptions( rawValue: 1 << 1 )

    /// Tolerate technically-noncompliant input that deviates from the XISF
    /// specification instead of rejecting it. When unset, such deviations are
    /// treated as errors.
    public static let allowSpecDeviations = XISFParsingOptions( rawValue: 1 << 2 )

    /// Spec-faithful parsing: verifies data-block checksums and rejects any
    /// input the XISF specification forbids.
    public static let strict: XISFParsingOptions = [
        .verifyChecksums,
    ]

    /// Real-world-friendly parsing: tolerates the noncompliant constructs found
    /// in many existing XISF files and does not require checksum verification.
    public static let lenient: XISFParsingOptions = [
        .allowSpecDeviations,
    ]
}
