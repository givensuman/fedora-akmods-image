#!/usr/bin/env bash

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kver="$(cat "${here}/kver")"

# kmods are only valid for the kernel they were built against
running="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)"
if [[ "${running}" != "${kver}" ]]; then
    echo "kernel mismatch: kmods built for ${kver}, image has ${running}" >&2
    exit 1
fi

dnf5 -y install dnf5-plugins \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf5 -y copr enable ublue-os/akmods
dnf5 -y install "${here}"/rpms/*.rpm
depmod -a "${kver}"
dnf5 -y swap mesa-va-drivers mesa-va-drivers-freeworld --allowerasing
dnf5 -y install gstreamer1-plugins-ugly gstreamer1-libav
dnf5 -y swap libavcodec-free libavcodec-freeworld --allowerasing
dnf5 -y copr remove ublue-os/akmods
rpm -q libavcodec-freeworld mesa-va-drivers-freeworld

cp -a "${here}/files/." /

# Rescue/emergency mode works with Fedora's locked root
# https://github.com/ublue-os/main/blob/main/build_files/install.sh
chmod +x /usr/lib/systemd/system-generators/coreos-sulogin-force-generator
systemctl enable bootc-update-crypto-policies.service getty@tty1.service

dnf5 clean all
rm -rf /var/cache/* /var/lib/dnf /var/log/dnf5.log* /run/dnf
