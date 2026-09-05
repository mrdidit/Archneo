#!/usr/bin/env python3
"""Validate the Android boot-image-v0 envelope emitted by Archneo."""

from __future__ import annotations

import argparse
import pathlib
import struct
import sys
import zlib


ANDROID_MAGIC = b"ANDROID!"
ARM64_IMAGE_MAGIC = b"ARMd"
FDT_MAGIC = 0xD00DFEED


class ValidationError(Exception):
    """The candidate boot image violates an Archneo packaging invariant."""


def align(value: int, alignment: int) -> int:
    return (value + alignment - 1) // alignment * alignment


def read_expected(path: pathlib.Path, description: str) -> bytes:
    try:
        data = path.read_bytes()
    except OSError as error:
        raise ValidationError(f"cannot read {description} {path}: {error}") from error
    if not data:
        raise ValidationError(f"{description} is empty: {path}")
    return data


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("boot_image", type=pathlib.Path)
    parser.add_argument("--expected-kernel", required=True, type=pathlib.Path)
    parser.add_argument("--expected-ramdisk", required=True, type=pathlib.Path)
    parser.add_argument("--expected-cmdline", required=True)
    parser.add_argument("--expected-dtb-count", required=True, type=int)
    parser.add_argument("--require-dtb-symbols", action="store_true")
    return parser.parse_args()


def validate(args: argparse.Namespace) -> None:
    candidate = read_expected(args.boot_image, "boot image")
    expected_kernel = read_expected(args.expected_kernel, "expected kernel payload")
    expected_ramdisk = read_expected(args.expected_ramdisk, "expected ramdisk")

    if len(candidate) < 608 or candidate[:8] != ANDROID_MAGIC:
        raise ValidationError("candidate is not an Android boot image")

    (
        kernel_size,
        _kernel_address,
        ramdisk_size,
        _ramdisk_address,
        second_size,
        _second_address,
        _tags_address,
        page_size,
        header_version,
        _os_version,
    ) = struct.unpack_from("<10I", candidate, 8)

    if header_version != 0:
        raise ValidationError(f"expected header version 0, found {header_version}")
    if page_size < 2048 or page_size & (page_size - 1):
        raise ValidationError(f"invalid boot-image page size: {page_size}")
    if page_size < 1632:
        raise ValidationError("boot-image page is smaller than the v0 header")
    if second_size != 0:
        raise ValidationError("unexpected second-stage payload")

    cmdline = candidate[64:576].split(b"\0", 1)[0]
    try:
        decoded_cmdline = cmdline.decode("ascii")
    except UnicodeDecodeError as error:
        raise ValidationError("boot command line is not ASCII") from error
    if decoded_cmdline != args.expected_cmdline:
        raise ValidationError("boot command line differs from the requested value")

    kernel_offset = page_size
    ramdisk_offset = kernel_offset + align(kernel_size, page_size)
    image_end = ramdisk_offset + align(ramdisk_size, page_size)
    if image_end != len(candidate):
        raise ValidationError(
            f"boot-image size mismatch: expected {image_end}, found {len(candidate)}"
        )

    kernel = candidate[kernel_offset : kernel_offset + kernel_size]
    ramdisk = candidate[ramdisk_offset : ramdisk_offset + ramdisk_size]
    if kernel != expected_kernel:
        raise ValidationError("embedded kernel payload differs from the packaged input")
    if ramdisk != expected_ramdisk:
        raise ValidationError("embedded ramdisk differs from the Archneo initramfs")
    if any(candidate[ramdisk_offset + ramdisk_size : image_end]):
        raise ValidationError("non-zero data follows the ramdisk")

    decompressor = zlib.decompressobj(16 + zlib.MAX_WBITS)
    try:
        image = decompressor.decompress(kernel) + decompressor.flush()
    except zlib.error as error:
        raise ValidationError(f"kernel field is not a valid gzip stream: {error}") from error
    if not decompressor.eof:
        raise ValidationError("kernel gzip stream is incomplete")
    if len(image) < 0x3C or image[0x38:0x3C] != ARM64_IMAGE_MAGIC:
        raise ValidationError("decompressed kernel lacks the arm64 Image magic")

    dtbs = decompressor.unused_data
    offset = 0
    dtb_count = 0
    while offset < len(dtbs):
        if len(dtbs) - offset < 40:
            raise ValidationError("truncated appended DTB header")
        magic, total_size = struct.unpack_from(">II", dtbs, offset)
        if magic != FDT_MAGIC:
            raise ValidationError(f"invalid appended DTB magic at offset {offset}")
        if total_size < 40 or total_size > len(dtbs) - offset:
            raise ValidationError(f"invalid appended DTB size at offset {offset}")
        dtb = dtbs[offset : offset + total_size]
        if args.require_dtb_symbols and b"__symbols__\0" not in dtb:
            raise ValidationError(f"appended DTB {dtb_count + 1} lacks __symbols__")
        offset += total_size
        dtb_count += 1

    if dtb_count != args.expected_dtb_count:
        raise ValidationError(
            f"expected {args.expected_dtb_count} appended DTBs, found {dtb_count}"
        )

    print(
        "archneo: boot image verified: "
        f"header=v0 page={page_size} ramdisk={ramdisk_size} dtbs={dtb_count}"
    )


def main() -> int:
    args = parse_arguments()
    try:
        validate(args)
    except ValidationError as error:
        print(f"archneo: error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
