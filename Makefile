SHELL := /bin/bash

.DEFAULT_GOAL := help

.PHONY: help verify fetch-rocknix prepare-kernel kernel

help:
	@echo "Archneo bring-up targets:"
	@echo "  make verify          Validate repository metadata and shell scripts"
	@echo "  make fetch-rocknix   Fetch the pinned ROCKNIX distribution revision"
	@echo "  make prepare-kernel  Fetch Linux, apply ROCKNIX patches, and copy DTs"
	@echo "  make kernel          Cross-build and package Pocket S 2K as out/KERNEL"

verify:
	@./scripts/verify.sh

fetch-rocknix:
	@./scripts/fetch-rocknix.sh

prepare-kernel:
	@./scripts/prepare-kernel.sh

kernel:
	@./scripts/build-kernel.sh
