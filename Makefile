# LEGIT OS - local ISO build (no CI/CD, no remote build actions).
# Runs mkarchiso inside an Arch Linux container (Docker Desktop, MINGW64 shell).
#
#   make     : build out/LEGIT_OS-<version>-x86_64.iso
#   make RE  : wipe prior output & rebuild the image from scratch

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
	--env OUT_DIR=/out $(IMAGE) /bin/bash /legit-os/build/build.sh

.PHONY: all re image

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
