SHELL := /bin/bash

.DEFAULT_GOAL := help

.PHONY: help verify fetch-rocknix fetch-rootfs fetch-firmware prepare-kernel kernel rootfs image

help:
	@echo "Archneo bring-up targets:"
	@echo "  make verify          Validate repository metadata and shell scripts"
	@echo "  make fetch-rocknix   Fetch the pinned ROCKNIX distribution revision"
	@echo "  make fetch-rootfs    Fetch and signature-verify Arch Linux ARM"
	@echo "  make fetch-firmware  Fetch checksum-pinned firmware archives"
	@echo "  make prepare-kernel  Fetch Linux, apply ROCKNIX patches, and copy DTs"
	@echo "  make kernel          Cross-build a Pocket S 2K compile-smoke KERNEL"
	@echo "  make rootfs          Prepare rootfs/initramfs as root after make kernel"
	@echo "  make image           Build the complete removable image as root"

verify:
	@./scripts/verify.sh

fetch-rocknix:
	@./scripts/fetch-rocknix.sh

fetch-rootfs:
	@./scripts/fetch-rootfs.sh

fetch-firmware:
	@./scripts/fetch-firmware.sh

prepare-kernel:
	@./scripts/prepare-kernel.sh

kernel:
	@./scripts/build-kernel.sh

rootfs:
	@./scripts/prepare-rootfs.sh

image:
	@./scripts/build-image.sh
