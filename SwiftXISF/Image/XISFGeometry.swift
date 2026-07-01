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

/// The geometry of an XISF image, parsed from its `geometry` attribute.
///
/// The attribute is a colon-separated list where the **last** value is the
/// channel count and the values before it are the image's spatial dimensions,
/// most-significant first — for a 2D image, `width:height:channels`. At least
/// one spatial dimension and the channel count are required.
public struct XISFGeometry: Equatable, Sendable, CustomStringConvertible
{
    /// The spatial dimensions, most-significant first (for a 2D image, width
    /// then height). Always at least one, all strictly positive.
    public let dimensions: [ Int ]

    /// The number of channels (strictly positive).
    public let channelCount: Int

    /// The number of pixels: the product of the spatial ``dimensions``.
    public var pixelCount: Int
    {
        self.dimensions.reduce( 1, * )
    }

    /// The total number of samples: ``pixelCount`` times ``channelCount``.
    public var sampleCount: Int
    {
        self.pixelCount * self.channelCount
    }

    /// Parses a `geometry` attribute of the form `d1:d2:…:dN:channelCount`.
    ///
    /// - Parameter attribute: The raw `geometry` attribute value.
    /// - Throws: ``XISFError/invalidElement(reason:)`` if there are fewer than
    ///   two components, or any component is not a strictly positive integer.
    public init( attribute: String ) throws
    {
        let components = attribute.split( separator: ":", omittingEmptySubsequences: false ).map( String.init )

        guard components.count >= 2
        else
        {
            throw XISFError.invalidElement( reason: "Geometry must have at least one dimension and a channel count: '\( attribute )'" )
        }

        let values = try components.map
        {
            ( component ) -> Int in

            guard let value = Int( component ), value > 0
            else
            {
                throw XISFError.invalidElement( reason: "Invalid geometry component '\( component )' in '\( attribute )'" )
            }

            return value
        }

        self.dimensions   = Array( values.dropLast() )
        self.channelCount = values[ values.count - 1 ]
    }

    /// The `geometry` attribute form: the dimensions and channel count joined
    /// with colons (for example `2159:3839:3`).
    public var description: String
    {
        ( self.dimensions + [ self.channelCount ] ).map { String( $0 ) }.joined( separator: ":" )
    }
}
