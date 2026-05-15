# NexOS build entrypoint

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help check deps init iso validate-iso qemu-test part1-verify part2-verify part3-verify part3-cloud-verify vbox-create vbox-start vbox-stop vbox-reset vbox-status vbox-attach-iso vbox-screenshot vbox-logs vbox-clean vbox-test clean clean-full show-config

help:
	@echo "NexOS Build System"
	@echo "=================="
	@echo "Foundation commands:"
	@echo "  make check          Check build host requirements"
	@echo "  make deps           Install host dependencies on Debian/Ubuntu"
	@echo "  make init           Generate/refresh live-build config"
	@echo "  make part1-verify   Verify Part 1 foundation files"
	@echo ""
	@echo "Part 2 commands:"
	@echo "  make iso            Build the first bootable NexOS live ISO"
	@echo "  make validate-iso   Validate ISO artifact and checksum"
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
	@./scripts/00-host-check.sh

deps:
	@./scripts/01-install-host-deps.sh

init:
	@./scripts/02-init-live-build.sh

iso:
	@./scripts/05-build-live-iso.sh

validate-iso:
	@./scripts/06-validate-iso.sh

qemu-test:
	@./testing/qemu-live-smoke-test.sh

part1-verify:
	@./scripts/04-part1-verify.sh

part2-verify:
	@./scripts/07-part2-verify.sh

part3-verify:
	@./scripts/08-part3-verify.sh

part3-cloud-verify:
	@./scripts/09-part3-windows-cloud-verify.sh

vbox-create:
	@./testing/vbox-create.sh

vbox-start:
	@./testing/vbox-start.sh

vbox-stop:
	@./testing/vbox-stop.sh

vbox-reset:
	@./testing/vbox-reset.sh

vbox-status:
	@./testing/vbox-status.sh

vbox-attach-iso:
	@./testing/vbox-attach-iso.sh

vbox-screenshot:
	@./testing/vbox-screenshot.sh

vbox-logs:
	@./testing/vbox-collect-logs.sh

vbox-clean:
	@./testing/vbox-clean.sh

vbox-test:
	@./testing/vbox-full-live-test.sh

clean:
	@./scripts/03-clean.sh light

clean-full:
	@./scripts/03-clean.sh full

show-config:
	@cat build-config/nexos.conf
