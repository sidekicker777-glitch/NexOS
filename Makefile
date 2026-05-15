# NexOS build entrypoint

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# Run scripts through bash so GitHub web uploads and Windows ZIP extraction
# cannot break the build by removing Linux executable bits.
RUN := bash

.PHONY: help check deps init iso iso-main iso-security validate-iso validate-iso-main validate-iso-security qemu-test part1-verify part2-verify part3-verify part3-cloud-verify vbox-create vbox-start vbox-stop vbox-reset vbox-status vbox-attach-iso vbox-screenshot vbox-logs vbox-clean vbox-test clean clean-full show-config

help:
	@echo "NexOS Build System"
	@echo "=================="
	@echo "Foundation commands:"
	@echo "  make check          Check build host requirements"
	@echo "  make deps           Install host dependencies on Debian/Ubuntu"
	@echo "  make init           Generate/refresh live-build config"
	@echo "  make part1-verify   Verify Part 1 foundation files"
	@echo ""
	@echo "ISO editions:"
	@echo "  make iso            Build the normal main NexOS ISO"
	@echo "  make iso-main       Build the normal main NexOS ISO"
	@echo "  make iso-security   Build the optional security-tool NexOS ISO"
	@echo "  make validate-iso   Validate the normal main NexOS ISO"
	@echo "  make validate-iso-main Validate the normal main NexOS ISO"
	@echo "  make validate-iso-security Validate the optional security-tool ISO"
	@echo ""
	@echo "Part 2 commands:"
	@echo "  make qemu-test      Boot-test the ISO in QEMU if installed"
	@echo "  make part2-verify   Verify Part 2 files/config without building"
	@echo ""
	@echo "Part 3 VirtualBox commands:"
	@echo "  make part3-verify   Verify Part 3 VirtualBox workflow files"
	@echo "  make part3-cloud-verify Verify Windows/GitHub Actions ISO build files"
	@echo "  make vbox-create    Create the NexOS VirtualBox test VM"
	@echo "  make vbox-start     Start the VM in GUI mode"
	@echo "  make vbox-stop      Send ACPI shutdown to the VM"
	@echo "  make vbox-reset     Restore the VM to the clean test snapshot"
	@echo "  make vbox-status    Show VM status and key settings"
	@echo "  make vbox-screenshot Capture a PNG screenshot from the running VM"
	@echo "  make vbox-logs      Collect VM info and VirtualBox logs"
	@echo "  make vbox-clean     Delete the test VM"
	@echo "  make vbox-test      Create/start the VM test workflow"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean          Light clean generated live-build artifacts"
	@echo "  make clean-full     Remove generated build/iso/workspace artifacts"
	@echo "  make show-config    Print current NexOS build config"

check:
	@$(RUN) scripts/00-host-check.sh

deps:
	@$(RUN) scripts/01-install-host-deps.sh

init:
	@$(RUN) scripts/02-init-live-build.sh

iso:
	@NEXOS_EDITION=main $(RUN) scripts/05-build-live-iso.sh

iso-main:
	@NEXOS_EDITION=main $(RUN) scripts/05-build-live-iso.sh

iso-security:
	@NEXOS_EDITION=security $(RUN) scripts/05-build-live-iso.sh

validate-iso:
	@NEXOS_EDITION=main $(RUN) scripts/06-validate-iso.sh

validate-iso-main:
	@NEXOS_EDITION=main $(RUN) scripts/06-validate-iso.sh

validate-iso-security:
	@NEXOS_EDITION=security $(RUN) scripts/06-validate-iso.sh

qemu-test:
	@$(RUN) testing/qemu-live-smoke-test.sh

part1-verify:
	@$(RUN) scripts/04-part1-verify.sh

part2-verify:
	@$(RUN) scripts/07-part2-verify.sh

part3-verify:
	@$(RUN) scripts/08-part3-verify.sh

part3-cloud-verify:
	@$(RUN) scripts/09-part3-windows-cloud-verify.sh

vbox-create:
	@$(RUN) testing/vbox-create.sh

vbox-start:
	@$(RUN) testing/vbox-start.sh

vbox-stop:
	@$(RUN) testing/vbox-stop.sh

vbox-reset:
	@$(RUN) testing/vbox-reset.sh

vbox-status:
	@$(RUN) testing/vbox-status.sh

vbox-attach-iso:
	@$(RUN) testing/vbox-attach-iso.sh

vbox-screenshot:
	@$(RUN) testing/vbox-screenshot.sh

vbox-logs:
	@$(RUN) testing/vbox-collect-logs.sh

vbox-clean:
	@$(RUN) testing/vbox-clean.sh

vbox-test:
	@$(RUN) testing/vbox-full-live-test.sh

clean:
	@$(RUN) scripts/03-clean.sh light

clean-full:
	@$(RUN) scripts/03-clean.sh full

show-config:
	@cat build-config/nexos.conf
