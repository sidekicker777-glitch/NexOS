# NexOS build entrypoint

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help
RUN := bash

.PHONY: help check deps init iso iso-main iso-tools iso-creator iso-security validate-iso validate-iso-main validate-iso-tools validate-iso-creator validate-iso-security qemu-test part1-verify part2-verify part3-verify part3-cloud-verify vbox-create vbox-start vbox-stop vbox-reset vbox-status vbox-attach-iso vbox-screenshot vbox-logs vbox-clean vbox-test clean clean-full show-config

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
	@echo "  make iso            Build the clean main NexOS ISO"
	@echo "  make iso-main       Build the clean main NexOS ISO"
	@echo "  make iso-tools      Build NexOS Tools with broad open-source app packs"
	@echo "  make iso-creator    Build legacy creator alias ISO"
	@echo "  make iso-security   Build optional security-tool NexOS ISO"
	@echo "  make validate-iso-tools Validate the NexOS Tools ISO"
	@echo ""
	@echo "VirtualBox/test commands are also available: vbox-create, vbox-start, vbox-stop, vbox-clean"
	@echo "Maintenance: clean, clean-full, show-config"

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

iso-tools:
	@NEXOS_EDITION=tools $(RUN) scripts/05-build-live-iso.sh

iso-creator:
	@NEXOS_EDITION=creator $(RUN) scripts/05-build-live-iso.sh

iso-security:
	@NEXOS_EDITION=security $(RUN) scripts/05-build-live-iso.sh

validate-iso:
	@NEXOS_EDITION=main $(RUN) scripts/06-validate-iso.sh

validate-iso-main:
	@NEXOS_EDITION=main $(RUN) scripts/06-validate-iso.sh

validate-iso-tools:
	@NEXOS_EDITION=tools $(RUN) scripts/06-validate-iso.sh

validate-iso-creator:
	@NEXOS_EDITION=creator $(RUN) scripts/06-validate-iso.sh

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
