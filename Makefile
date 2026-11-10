# LEGIT OS - local ISO build only (no CI/CD or remote actions).
# Windows: Docker Desktop / Git Bash; VirtualBox optional.
# Linux (42): Docker without sudo or rootless Podman; QEMU optional.
#
#   make           build the Arch container + ISO
#   make re        rebuild container image from scratch + ISO
#   make aur-clean remove compiled AUR cache
#   make check     check host prerequisites without downloading an image
#   make vm        boot the newest ISO (VirtualBox Windows / QEMU Linux)
#
# Linux data, cache and ISO output live under:
# /sgoinfre/goinfre/Perso/zcadinot/.home/legit-os/
# Override with: make LEGIT_DATA_DIR=/another/writable/directory

.DEFAULT_GOAL := all

UNAME_S := $(shell uname -s 2>/dev/null)
ifneq ($(filter Windows_NT,$(OS)),)
  HOST_WINDOWS := 1
else ifneq ($(filter MINGW% MSYS% CYGWIN%,$(UNAME_S)),)
  HOST_WINDOWS := 1
else
  HOST_WINDOWS := 0
endif

IMAGE := legit-os/builder
DOCKERFILE := build/Containerfile
VMNAME := LEGIT-OS

ifeq ($(HOST_WINDOWS),1)
  DockerBin := /c/Program Files/Docker/Docker/resources/bin
  export PATH := $(DockerBin):$(PATH)
  export MSYS_NO_PATHCONV := 1
  LEGIT_DATA_DIR ?= D:/Legit-OS
  MNT := $(shell cygpath -m "$(CURDIR)" 2>/dev/null || echo "$(CURDIR)")
  CONTAINER_ENGINE ?= $(shell sh -c 'command -v docker || echo "/c/Program Files/Docker/Docker/resources/bin/docker.exe"')
  HOST_CA ?= $(LEGIT_DATA_DIR)/.cache/host-ca.der
else
  LEGIT_DATA_DIR ?= /sgoinfre/goinfre/Perso/zcadinot/.home/legit-os
  # Rootless Podman image layers should also use the large user storage.
  export XDG_DATA_HOME ?= $(LEGIT_DATA_DIR)/.xdg/share
  MNT := $(abspath $(CURDIR))
  # Prefer usable Podman over Docker with a potentially inaccessible socket.
  # Override if needed: make CONTAINER_ENGINE=docker
  CONTAINER_ENGINE ?= $(shell sh -c 'if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then echo podman; elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then echo docker; else echo unavailable; fi')
  # No Norton / SSL interception assumption for 42.
  HOST_CA ?= $(LEGIT_DATA_DIR)/.cache/host-ca.der
  QEMU ?= qemu-system-x86_64
  QEMU_IMG ?= qemu-img
endif

OUT_DIR := $(LEGIT_DATA_DIR)/out
CACHE_DIR := $(LEGIT_DATA_DIR)/.cache
AUR_CACHE_DIR := $(CACHE_DIR)/legit-aur
PACMAN_CACHE_DIR := $(CACHE_DIR)/archiso/pacman
WORK_ROOT := $(LEGIT_DATA_DIR)/work

# A missing CA should not turn into a Docker-created directory.
CERT_MOUNT = $(if $(wildcard $(HOST_CA)),--volume "$(HOST_CA):/tmp/host-ca.der:ro",)

RUN = "$(CONTAINER_ENGINE)" run --rm --privileged \
	--volume "$(MNT):/legit-os:ro" \
	--volume "$(OUT_DIR):/out" \
	--volume "$(PACMAN_CACHE_DIR):/var/cache/pacman/pkg" \
	--volume "$(AUR_CACHE_DIR):/aur-cache" \
	--volume "$(WORK_ROOT):/work" \
	$(CERT_MOUNT) \
	--env OUT_DIR=/out \
	--env SRC_DIR=/legit-src \
	--env WORK_DIR=/work/archiso \
	--env PROFILE_DIR=/work/profile \
	--env AUR_REPO_DIR=/work/aur-repo \
	$(IMAGE) /bin/bash -lc 'set -e; \
	if [ -s /tmp/host-ca.der ]; then \
	  openssl x509 -inform DER -in /tmp/host-ca.der -out /etc/ca-certificates/trust-source/anchors/host.crt; \
	  update-ca-trust; \
	fi; \
	mkdir -p /legit-src; \
	tar -C /legit-os --exclude=./out --exclude=./work --exclude=./.cache --exclude=./.git -cf - . | tar -C /legit-src -xf -; \
	exec /bin/bash /legit-src/build/build.sh'

.PHONY: all re image vm aur-clean check engine-check

# Host sudo is never invoked.
check:
	@set -eu; \
	echo ">>> LEGIT OS host check: $(if $(filter 1,$(HOST_WINDOWS)),Windows,Linux)"; \
	mkdir -p "$(OUT_DIR)" "$(PACMAN_CACHE_DIR)" "$(AUR_CACHE_DIR)" "$(WORK_ROOT)" "$(LEGIT_DATA_DIR)/.xdg/share"; \
	test -w "$(OUT_DIR)" || { echo 'ERROR: ISO output is not writable: $(OUT_DIR)' >&2; exit 1; }; \
	if [ "$(CONTAINER_ENGINE)" = unavailable ] || ! command -v "$(CONTAINER_ENGINE)" >/dev/null 2>&1; then \
	  echo 'ERROR: no usable Docker/Podman executable without sudo.' >&2; \
	  echo '42 requires configured rootless Podman or access to a Docker daemon.' >&2; \
	  exit 1; \
	fi; \
	if ! "$(CONTAINER_ENGINE)" info >/dev/null 2>&1; then \
	  echo 'ERROR: the container engine is inaccessible to this user without sudo.' >&2; \
	  exit 1; \
	fi; \
	if [ "$(HOST_WINDOWS)" = 1 ] && [ ! -s "$(HOST_CA)" ]; then \
	  echo 'ERROR: Norton DER root certificate missing at $(HOST_CA)' >&2; exit 1; \
	fi; \
	echo ">>> Engine: $(CONTAINER_ENGINE)"; \
	echo ">>> Output: $(OUT_DIR)"; \
	echo ">>> Cache: $(CACHE_DIR)"; \
	if [ "$(HOST_WINDOWS)" = 0 ] && [ "$(CONTAINER_ENGINE)" = podman ]; then \
	  if command -v unshare >/dev/null 2>&1 && unshare -Ur true >/dev/null 2>&1; then \
	    echo '>>> User namespaces: available'; \
	  else \
	    echo 'WARNING: unshare -Ur is unavailable; mkarchiso may fail on this host.' >&2; \
	  fi; \
	fi

# A working container daemon alone does not mean mkarchiso can mount filesystems.
# Rootless --privileged does not bypass the host kernel's limits.
engine-check:
	@"$(CONTAINER_ENGINE)" run --rm --privileged "$(IMAGE)" /bin/bash -ec 'mkdir -p /tmp/legit-mount-test; if ! mount -t tmpfs tmpfs /tmp/legit-mount-test; then echo "ERROR: mounts unavailable in this container; mkarchiso cannot run. Kernel namespaces/mount support required." >&2; exit 1; fi; umount /tmp/legit-mount-test'

image: check
	"$(CONTAINER_ENGINE)" build -f "$(DOCKERFILE)" -t "$(IMAGE)" build/

all: image
	@$(MAKE) --no-print-directory engine-check
	@echo ">>> Building LEGIT OS ISO locally..."
	$(RUN)

re: check
	@echo ">>> Full rebuild: fresh container image and ISO."
	"$(CONTAINER_ENGINE)" build --no-cache -f "$(DOCKERFILE)" -t "$(IMAGE)" build/
	@rm -f "$(OUT_DIR)"/*.iso
	@$(MAKE) --no-print-directory engine-check
	$(RUN)

aur-clean:
	@set -eu; \
	test -n "$(AUR_CACHE_DIR)" && test "$(AUR_CACHE_DIR)" != /; \
	echo ">>> Clearing compiled AUR cache ($(AUR_CACHE_DIR))..."; \
	rm -rf "$(AUR_CACHE_DIR)"

ifeq ($(HOST_WINDOWS),1)
# --- VIRTUALBOX (create + boot the ISO in a local VM) ---
# Creates the LEGIT-OS VM profile (UEFI, 8 GB RAM, VMSVGA + 3D, 60 GB disk,
# DVD with the latest out/*.iso) and starts it in a GUI window.
VB := $(shell sh -c 'for p in "/d/Other/App/VirtualBox" "/c/Program Files/Oracle/VirtualBox"; do [ -f "$$p/VBoxManage.exe" ] && { echo "$$p/VBoxManage.exe"; exit 0; }; done; command -v VBoxManage')
VMNAME := LEGIT-OS

.PHONY: vm

vm:
	@set -e; \
	echo ">>> VirtualBox VM setup for LEGIT OS"; \
	"$(VB)" --version > /dev/null 2>&1 || { echo 'ERROR: VirtualBox not found (install it from https://www.virtualbox.org/)'; exit 1; }; \
	iso=$(ls -t "$(OUT_DIR)"/*.iso 2>/dev/null | head -n 1); \
	test -n "$$iso" || { echo 'ERROR: no ISO in out/, run make first'; exit 1; }; \
	echo ">>> Using ISO: $$iso"; \
	isowin=$$(cygpath -w "$$iso"); \
	vmdir=$$(cygpath -u "$$USERPROFILE")/"VirtualBox VMs"/$(VMNAME); \
	vdiw=$$(cygpath -w "$$vmdir/$(VMNAME).vdi"); \
	if ! "$(VB)" showvminfo "$(VMNAME)" > /dev/null 2>&1; then \
	  echo ">>> Creating VM $(VMNAME)..."; \
	  "$(VB)" createvm --name "$(VMNAME)" --ostype Linux_64 --register; \
	  "$(VB)" modifyvm "$(VMNAME)" --memory 8192 --cpus 2 --vram 128; \
	  "$(VB)" modifyvm "$(VMNAME)" --firmware efi --graphicscontroller vmsvga --accelerate3d on; \
	  "$(VB)" modifyvm "$(VMNAME)" --boot1 dvd --boot2 disk --boot3 none --boot4 none; \
	  "$(VB)" modifyvm "$(VMNAME)" --nic1 nat --audio-driver none; \
	  "$(VB)" storagectl "$(VMNAME)" --name SATA --add sata --portcount 2 --bootable on; \
	fi; \
	test -f "$$vmdir/$(VMNAME).vdi" || { \
	  echo ">>> Creating hard disk (60 GB)..."; \
	  mkdir -p "$$vmdir"; \
	  "$(VB)" createhd --filename "$$vdiw" --size 61440; \
	}; \
	"$(VB)" storageattach "$(VMNAME)" --storagectl SATA --port 1 --device 0 --type hdd --medium "$$vdiw"; \
	"$(VB)" storageattach "$(VMNAME)" --storagectl SATA --port 0 --device 0 --type dvddrive --medium "$$isowin"; \
	running=$$("$(VB)" showvminfo "$(VMNAME)" --machinereadable | sed -n 's/^VMState="\([a-z-]*\)".*/\1/p'); \
	if [ "$$running" = "running" ]; then \
	  echo ">>> VM $(VMNAME) already running: rebooting into the ISO..."; \
	  "$(VB)" controlvm "$(VMNAME)" reset; \
	else \
	  echo ">>> Starting VM $(VMNAME)..."; \
	  "$(VB)" startvm "$(VMNAME)" --type gui; \
	fi

else
# Linux: QEMU userspace emulator. KVM is optional; TCG needs no host sudo.
vm:
	@set -eu; \
	command -v "$(QEMU)" >/dev/null 2>&1 && command -v "$(QEMU_IMG)" >/dev/null 2>&1 || { \
	  echo 'ERROR: QEMU/qemu-img unavailable in PATH.' >&2; exit 1; \
	}; \
	iso=$$(ls -t "$(OUT_DIR)"/*.iso 2>/dev/null | head -n 1); \
	test -n "$$iso" || { echo 'ERROR: no ISO, run make first' >&2; exit 1; }; \
	mkdir -p "$(LEGIT_DATA_DIR)/vm"; \
	disk="$(LEGIT_DATA_DIR)/vm/$(VMNAME).qcow2"; \
	if [ ! -f "$$disk" ]; then "$(QEMU_IMG)" create -f qcow2 "$$disk" 60G; fi; \
	accel=tcg; \
	if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then accel=kvm; fi; \
	echo ">>> QEMU boot with ISO $$iso (accel=$$accel)"; \
	"$(QEMU)" -machine "accel=$$accel" -m 8192 -smp 2 \
	  -drive "file=$$disk,format=qcow2,if=virtio" \
	  -cdrom "$$iso" -boot order=d \
	  -nic user,model=e1000
endif
