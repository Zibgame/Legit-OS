# LEGIT OS - local ISO build (no CI/CD, no remote build actions).
# Runs mkarchiso inside an Arch Linux container (Docker Desktop, MINGW64 shell).
#
#   make        : build out/LEGIT_OS-<version>-x86_64.iso
#   make re     : wipe prior output & rebuild the image from scratch
#   make aur-clean : wipe the compiled-AUR cache (full AUR recompilation)
#   make vm     : create/refresh the VirtualBox LEGIT-OS VM with the latest ISO
#                 and boot it (VirtualBox must be installed on the Windows host)
#
# Prerequisite once: export the Norton Web/Mail Shield root certificate
# (SSL-scanning proxy) to D:/Legit-OS/.cache/host-ca.der, e.g.:
#   Export-Certificate -Cert (Get-Item Cert:\LocalMachine\Root\<THUMBPRINT>) `
#       -FilePath D:\Legit-OS\.cache\host-ca.der

MSYS_NO_PATHCONV := 1
# Make the Docker Desktop bin dir visible to the recipe shell (MSYS2 sh does
# not inherit it), required for docker-credential-desktop etc.
DockerBin := /c/Program Files/Docker/Docker/resources/bin
export PATH := $(DockerBin):$(PATH)
MNT := $(shell cygpath -m "$(CURDIR)" 2>/dev/null || echo "$(CURDIR)")
IMAGE := legit-os/builder
# Docker can be absent from the MSYS2 PATH; fall back to Docker Desktop's CLI.
DOCKER := $(shell sh -c 'command -v docker || echo "/c/Program Files/Docker/Docker/resources/bin/docker.exe"')
DOCKERFILE := build/Containerfile

RUN := MSYS_NO_PATHCONV=1 "$(DOCKER)" run --rm --privileged \
	--volume "$(MNT)":/legit-os \
	--volume "D:/Legit-OS/out":/out \
	--volume "D:/Legit-OS/.cache/archiso/pacman":/var/cache/pacman/pkg \
	--volume "D:/Legit-OS/.cache/legit-aur":/aur-cache \
	--volume "D:/Legit-OS/.cache/host-ca.der":/tmp/host-ca.der:ro \
	--env OUT_DIR=/out \
	--env SRC_DIR=/legit-src \
	$(IMAGE) /bin/bash -lc 'set -e; \
	test -s /tmp/host-ca.der || { echo "FATAL: missing D:/Legit-OS/.cache/host-ca.der (export the Norton Web/Mail Shield root cert)"; exit 42; }; \
	openssl x509 -inform DER -in /tmp/host-ca.der -out /etc/ca-certificates/trust-source/anchors/norton.crt; \
	update-ca-trust; \
	mkdir -p /legit-src; \
	tar -C /legit-os --exclude=./out --exclude=./.git -cf - . | tar -C /legit-src -xf -; \
	exec /bin/bash /legit-src/build/build.sh'

.PHONY: all re image vm aur-clean

# Wipes the persistent compiled-AUR cache; the next build recompiles every
# AUR package (use this after upgrading packages/aur-tools.list versions).
aur-clean:
	@echo ">>> Clearing compiled AUR cache (D:/Legit-OS/.cache/legit-aur)..."
	@rm -rf "D:/Legit-OS/.cache/legit-aur"

all: image
	@echo ">>> Building LEGIT OS ISO (this can take a while)..."
	$(RUN)

re:
	@echo ">>> Full rebuild: fresh container image, no prior ISO."
	MSYS_NO_PATHCONV=1 "$(DOCKER)" build --no-cache -f "$(DOCKERFILE)" -t $(IMAGE) build/
	@$(RM) -f out/*.iso
	$(RUN)

image:
	MSYS_NO_PATHCONV=1 "$(DOCKER)" build -f "$(DOCKERFILE)" -t $(IMAGE) build/

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
	iso=$$(ls -t out/*.iso 2>/dev/null | head -n 1); \
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
