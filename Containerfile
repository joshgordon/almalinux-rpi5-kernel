FROM quay.io/almalinuxorg/almalinux-bootc-rpi:10@sha256:175c1f59ba9fba99ba83bca2c3b229d97e74df9f603eb502e2681c10f3ddfcc9 AS builder
# bootc rpi image has /root as a file not a dir; use /build as HOME instead
ENV HOME=/build
RUN mkdir -p /build && \
    dnf install -y epel-release rpm-build rpmdevtools dnf-plugins-core 'dnf-command(builddep)' && \
    crb enable && rpmdev-setuptree && \
    dnf install -y dwarves && \
    dnf download --source --destdir /tmp raspberrypi2-kernel4 && \
    rpm -i /tmp/raspberrypi2-*.src.rpm && \
    dnf builddep -y /build/rpmbuild/SPECS/raspberrypi2.spec && \
    sed -i 's/^%define bcmmodel 2711/%define bcmmodel 2712/' /build/rpmbuild/SPECS/raspberrypi2.spec && \
    printf '%s\n' \
      './scripts/config --file .config --disable DEBUG_INFO_NONE --enable DEBUG_KERNEL --enable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT --enable DEBUG_INFO_BTF --disable DEBUG_INFO_BTF_MODULES' \
      'make olddefconfig' \
      'grep -q "^CONFIG_DEBUG_INFO_BTF=y" .config || { echo "BTF not enabled in .config" >&2; exit 1; }' \
      > /tmp/btf.inc && \
    sed -i '/^make bcm%{bcmmodel}_defconfig/r /tmp/btf.inc' /build/rpmbuild/SPECS/raspberrypi2.spec && \
    grep -q 'DEBUG_INFO_BTF' /build/rpmbuild/SPECS/raspberrypi2.spec \
  || { echo 'BTF insert failed'; exit 1; } && \
    rpmspec -P /build/rpmbuild/SPECS/raspberrypi2.spec | grep -q 'make bcm2712_defconfig' \
  || { echo 'bcmmodel override failed'; exit 1; } && \
    rpmbuild -bb /build/rpmbuild/SPECS/raspberrypi2.spec \
      --define 'dist .el10.bcm2712' \
      --define "_smp_mflags -j$(nproc)" && \
    mkdir -p /rpms && \
    find /build/rpmbuild/RPMS/aarch64 -name '*.rpm' \
      ! -name '*debuginfo*' ! -name '*-devel-*' ! -name '*-devel.*' ! -name '*-headers*' \
      -exec cp {} /rpms/ \;

# Validate that the settings we care about landed in the resulting RPMs.
RUN rpm2cpio /rpms/raspberrypi2-kernel4-6.12*.rpm | cpio -i --to-stdout './boot/config-*' > /tmp/kcfg && \
    grep -q '^CONFIG_ARM64_VA_BITS=47$' /tmp/kcfg || { echo 'not 47-bit VA'; exit 1; } && \
    grep -q '^CONFIG_ARM64_16K_PAGES=y$' /tmp/kcfg || { echo 'not 16K pages'; exit 1; } && \
    rm /tmp/kcfg

# export only the built RPMs; no build tooling in the final image
FROM scratch
COPY --from=builder /rpms/ /rpms/
