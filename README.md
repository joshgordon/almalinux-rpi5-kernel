# almalinux-rpi5-kernel

Builds the `raspberrypi2-kernel4` source package for BCM2712 (Raspberry Pi 5) on AlmaLinux 10 and publishes the resulting RPMs as an OCI artifact image.

## Why this exists

The AlmaLinux RPi base image (`almalinux-bootc-rpi:10`) ships a BCM2711 kernel (Raspberry Pi 4). The Raspberry Pi 5 uses BCM2712, which requires a separate kernel build. This repo does that build once and caches the result so downstream images don't have to compile a kernel on every rebuild.

## What it produces

A `FROM scratch` OCI image at `ghcr.io/joshgordon/almalinux-rpi5-kernel:latest` containing only the runtime RPMs at `/rpms/`:

- `raspberrypi2-kernel4` (BCM2712 variant)
- `raspberrypi2-kernel4-modules*`
- `raspberrypi2-kernel4-tools` / `tools-libs`
- `raspberrypi2-firmware`

Debug, devel, and header packages are excluded.

## Consuming it

```dockerfile
FROM ghcr.io/joshgordon/almalinux-rpi5-kernel:latest AS kbuild

FROM quay.io/almalinuxorg/almalinux-bootc-rpi:10 AS base
COPY --from=kbuild /rpms/ /tmp/kernel/
RUN dnf -y remove --noautoremove 'raspberrypi2-kernel4*' && \
    rm -rf /usr/lib/modules/* && \
    dnf -y install /tmp/kernel/*.rpm && \
    rm -rf /tmp/kernel && dnf clean all
```

Used by [joshgordon/immutable-os](https://github.com/joshgordon/immutable-os) for the `almalinux-k8s` image variant.

## Updates

CI runs weekly and whenever the base image digest changes (managed by Renovate). A new image push will trigger Renovate to open a PR in downstream repos that pin this image's digest.
