FROM quay.io/almalinuxorg/almalinux-bootc-rpi:10@sha256:7d658539aa3e8410092e2a13ca2823e5e2f5d3543a89410b2a06e1e3904c2fdf AS builder
# bootc rpi image has /root as a file not a dir; use /build as HOME instead
ENV HOME=/build
RUN mkdir -p /build && \
    dnf install -y epel-release rpm-build rpmdevtools dnf-plugins-core 'dnf-command(builddep)' && \
    crb enable && rpmdev-setuptree && \
    dnf download --source --destdir /tmp raspberrypi2-kernel4 && \
    rpm -i /tmp/raspberrypi2-*.src.rpm && \
    dnf builddep -y /build/rpmbuild/SPECS/raspberrypi2.spec && \
    rpmbuild -bb /build/rpmbuild/SPECS/raspberrypi2.spec \
      --define 'bcmmodel 2712' --define 'dist .el10.bcm2712' \
      --define "_smp_mflags -j$(nproc)" && \
    mkdir -p /rpms && \
    find /build/rpmbuild/RPMS/aarch64 -name '*.rpm' \
      ! -name '*debuginfo*' ! -name '*-devel-*' ! -name '*-devel.*' ! -name '*-headers*' \
      -exec cp {} /rpms/ \;

FROM scratch
COPY --from=builder /rpms/ /rpms/
