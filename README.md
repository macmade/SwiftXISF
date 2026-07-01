SwiftXISF
=========

[![Build Status](https://img.shields.io/github/actions/workflow/status/macmade/SwiftXISF/ci-mac.yaml?label=macOS&logo=apple)](https://github.com/macmade/SwiftXISF/actions/workflows/ci-mac.yaml)
[![Issues](http://img.shields.io/github/issues/macmade/SwiftXISF.svg?logo=github)](https://github.com/macmade/SwiftXISF/issues)
![Status](https://img.shields.io/badge/status-active-brightgreen.svg?logo=git)
![License](https://img.shields.io/badge/license-mit-brightgreen.svg?logo=open-source-initiative)  
[![Contact](https://img.shields.io/badge/follow-@macmade-blue.svg?logo=twitter&style=social)](https://twitter.com/macmade)
[![Sponsor](https://img.shields.io/badge/sponsor-macmade-pink.svg?logo=github-sponsors&style=social)](https://github.com/sponsors/macmade)

### About

XISF Image Library for Swift.

This library provides a simple interface to read [XISF](https://pixinsight.com/xisf/) (Extensible
Image Serialization Format) files in Swift, based on the
[XISF 1.0 specification](https://pixinsight.com/doc/docs/XISF-1.0-spec/XISF-1.0-spec.html). XISF is
the native image format of [PixInsight](https://pixinsight.com/).

It is a natural counterpart to [SwiftFITS](https://github.com/macmade/SwiftFITS): a single
`XISFFile` entry point, opened from a `URL` or `Data`, exposes the file's images, properties,
embedded FITS keywords and metadata. Pixel data is surfaced as fully decoded (decompressed and
un-shuffled) *opaque bytes plus typed geometry and format metadata* — interpretation of the samples
is left to the consumer.

### Status

SwiftXISF is currently **read-only**: it parses existing monolithic XISF files into their
header/data structure. Write and serialization (XISF authoring) support is not implemented and is
not currently planned.

### Features

- **Monolithic files**: reads and validates the 16-byte binary preamble (`XISF0100` signature,
  little-endian header length, reserved field) and the UTF-8 XML header.
- **Images**: multiple images per file, each exposing typed `geometry`, `sampleFormat`,
  `colorSpace`, `pixelStorage`, `byteOrder` and `bounds`, plus its fully decoded pixel bytes.
- **Properties & FITS keywords**: typed scalar, complex, time-point and string properties, plus
  vector/matrix/`ByteArray` values backed by data blocks, and embedded FITS keywords.
- **Data blocks**: `inline` (base64 / hex), `embedded` (`<Data>` child), and `attachment`
  (in-file) locations, plus opt-in external/distributed `url(...)` / `path(...)` locations and the
  `.xisb` distributed block index.
- **Compression**: `zlib`, `lz4` and `lz4hc` via Apple's Compression framework, and `zstd` via the
  upstream Zstandard library, all with optional byte-shuffling (`+sh`) and split sub-blocks.
- **Checksums**: opt-in verification of `sha-1`, `sha-256` and `sha-512` (and `sha3-256` /
  `sha3-512` where the platform provides them) data-block digests.
- **Color & ancillary metadata**: unit-level `Metadata`, per-image ICC profiles, RGB working space,
  display function, color filter array, resolution and thumbnails.
- **Strict vs. lenient**: `XISFParsingOptions` toggles spec-faithful validation against real-world
  tolerance, and gates checksum verification and external-location resolution.

### Conformance & Limitations

SwiftXISF targets the base [XISF 1.0 specification](https://pixinsight.com/doc/docs/XISF-1.0-spec/XISF-1.0-spec.html).
The following properties are intentional, not latent surprises:

- **Read-only**: there is no XISF authoring or serialization API.
- **Opaque pixel data**: samples are exposed as the fully decoded raw bytes plus typed metadata;
  the library does not decode them into typed Swift sample arrays. The consumer interprets the
  bytes using `sampleFormat`, `byteOrder`, `geometry` and `pixelStorage`.
- **External/distributed data blocks are opt-in**: `url(...)` / `path(...)` locations are resolved
  only when `XISFParsingOptions.allowExternalLocations` is set (off in both `.strict` and
  `.lenient`), because resolving them reads files outside the parsed document. Resolution is lazy:
  a unit referencing external blocks still opens, and only *accessing* such a block requires the
  option. Only local `file://` URLs and both `path(...)` forms are supported — **remote (network)
  URLs are not fetched**.
- **SHA-3 checksums require a recent OS**: `sha3-256` / `sha3-512` verification is available only
  where the system CryptoKit provides SHA-3 (macOS 26+); below that, requesting it yields a clean
  "unsupported" error rather than silently passing. `sha-1` / `sha-256` / `sha-512` are always
  available.
- **`Reference` / `uid` association is not implemented**: ancillary elements (ICC profile, display
  function, etc.) are parsed only as direct children of their `<Image>` (and `Metadata` as a direct
  child of the root). Root-level elements shared across images via `<Reference>` are not resolved.
- **`Metadata` is treated as optional**: the specification makes the unit `<Metadata>` element
  mandatory, but SwiftXISF exposes it as an optional (`nil` when absent) rather than rejecting files
  that omit it.
- **Tables are out of scope**: `Structure` / `Table` elements are not parsed.
- **Strict vs. lenient**: `.strict` verifies data-block checksums and rejects input the spec
  forbids (a non-zero reserved field, an out-of-range value, a missing `version="1.0"`, a
  float image without `bounds`, an invalid identifier, and so on), while `.lenient` tolerates common
  real-world deviations (a non-zero reserved field, a missing/mismatched version, unknown enumerated
  values falling back to their defaults, and a declared-size mismatch) and does not force checksum
  verification.
- **Not thread-safe**: `XISFFile`, `XISFImage`, `XISFDataBlock`, `XISFICCProfile` and
  `XISFThumbnail` decode and cache their bytes lazily on read, so they are not `Sendable` and must
  not be shared across threads without external synchronization.

### Requirements & Portability

SwiftXISF is written in Swift and depends on:

- **Foundation** — for `Data`, `XMLParser`, URL handling and the Compression framework
  (`zlib` / `lz4` / `lz4hc` decoding).
- **CryptoKit** — for data-block checksum verification. Its use is guarded by availability, so the
  library still builds where CryptoKit is unavailable (checksum verification then reports
  "unsupported").
- **[Zstandard](https://github.com/facebook/zstd) (`libzstd`)** — for `zstd` decompression, the one
  XISF codec Apple's Compression framework does not provide. This is fetched automatically as a
  Swift package dependency; unlike SwiftFITS, SwiftXISF is therefore **not** dependency-free.

The library is developed, built and tested on macOS (deployment target macOS 15.0; see the CI badge
above). Portability to other Swift platforms depends on the availability of Foundation's Compression
framework, CryptoKit and `libzstd`, and has not been verified.

### Swift Package Manager

SwiftXISF ships a `Package.swift` and can be consumed as a Swift package. Add it to your
dependencies:

```swift
.package( url: "https://github.com/macmade/SwiftXISF.git", branch: "main" )
```

The `libzstd` dependency is resolved transitively, so no additional setup is required. The Xcode
project (`SwiftXISF.xcodeproj`) is also provided for development.

### Cloning

This project uses submodules.  
To clone it, use the following command:

```bash
git clone --recursive https://github.com/macmade/SwiftXISF.git
```

### Example Usage

```swift
import Foundation
import SwiftXISF

do
{
    let file = try XISFFile( url: URL( fileURLWithPath: "/path/to/file.xisf" ), options: .lenient )

    for image in file.images
    {
        print( "Image \( image.id ?? "<unnamed>" ): \( image.geometry ), \( image.sampleFormat ), \( image.colorSpace )" )

        // Fully decoded (decompressed and un-shuffled) opaque pixel bytes.
        let pixels = try image.data

        print( "\( pixels.count ) bytes of pixel data" )
    }

    // Unit-level properties and embedded FITS keywords.
    print( file.properties )
    print( file.keywords )
}
catch // SwiftXISF.XISFError
{
    print( error )
}
```

License
-------

Project is released under the terms of the MIT License.

Repository Infos
----------------

    Owner:          Jean-David Gadina - XS-Labs
    Web:            www.xs-labs.com
    Blog:           www.noxeos.com
    Twitter:        @macmade
    GitHub:         github.com/macmade
    LinkedIn:       ch.linkedin.com/in/macmade/
    StackOverflow:  stackoverflow.com/users/182676/macmade
