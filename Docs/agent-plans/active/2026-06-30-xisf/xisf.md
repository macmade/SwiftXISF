# XISF File Parser (PixInsight's format)

## Goal

Create an XISF file parser in Swift, following the architecture, conventions, and organization of the SwiftFITS project closely: https://github.com/macmade/SwiftFITS.git

The APIs should match as closely as possible.  
XISF files share some common properties with FITS files, so this shouldn't be a problem.

Include complete and broad unit tests, just as SwiftFITS.  
Test files can be provided on demand.

The SwiftFITS repository is checked out in the directory above this repository.  
Make sure to read and understand how the project is structured and replicate as closely as possible.  
Do not reference any absolute file paths from SwiftFITS.

## Implementation notes

- Open, free spec. Monolithic file = UTF-8 XML header + binary data blocks. Sample formats (UInt8/16/32, Float32/64) are exactly `BITPIX` set from FITS, with planar multi-channel storage like FITS planes. XML parses with `XMLParser`.
- Dependency: decompression. Blocks may be zlib / lz4 / lz4hc / zstd (± byte-shuffling). Apple's `Compression` framework covers zlib + lz4 (shuffle is trivial); zstd is not and needs an external dep. First slice = uncompressed + zlib (+ lz4); defer zstd.

## References:

- PixInsight - XISF: https://pixinsight.com/xisf/
- XISF 1.0 Specification: https://pixinsight.com/doc/docs/XISF-1.0-spec/XISF-1.0-spec.html
