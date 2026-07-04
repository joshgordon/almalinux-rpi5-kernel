FROM quay.io/almalinuxorg/almalinux-bootc-rpi:10@sha256:7d658539aa3e8410092e2a13ca2823e5e2f5d3543a89410b2a06e1e3904c2fdf AS builder
# bootc rpi image has /root as a file not a dir; use /build as HOME instead
ENV HOME=/build
RUN mkdir -p /build && \
    dnf install -y epel-release rpm-build rpmdevtools dnf-plugins-core 'dnf-command(builddep)' && \
    crb enable && rpmdev-setuptree && \
    dnf download --source --destdir /tmp raspberrypi2-kernel4 && \
    rpm -i /tmp/raspberrypi2-*.src.rpm && \
    dnf builddep -y /build/rpmbuild/SPECS/raspberrypi2.spec && \
    sed -i 's/^%define bcmmodel 2711/%define bcmmodel 2712/' /build/rpmbuild/SPECS/raspberrypi2.spec && \
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

FROM scratch
COPY --from=builder /rpms/ /rpms/
