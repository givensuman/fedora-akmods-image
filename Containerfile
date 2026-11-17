ARG BASE=quay.io/fedora/fedora-bootc

FROM ${BASE} AS builder

RUN dnf5 -y install dnf5-plugins \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
    dnf5 -y copr enable ublue-os/akmods

RUN KVER=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core) && \
    echo "$KVER" > /kver && \
    dnf5 -y install akmods rpm-build kernel-devel-${KVER} \
    akmod-v4l2loopback akmod-wl \
    akmod-xone akmod-gcadapter_oc akmod-framework-laptop

RUN mkdir /out && for m in $(rpm -qa 'akmod-*' --qf '%{NAME}\n'); do \
    akmods --force --kernels "$(cat /kver)" --akmod "${m#akmod-}" || exit 1; \
    done && \
    cp /var/cache/akmods/*/kmod-*.rpm /out/ && \
    test "$(ls /out | wc -l)" -ge 5

FROM ${BASE}

COPY --from=builder /out /tmp/kmods
COPY --from=builder /kver /tmp/kver

RUN dnf5 -y install dnf5-plugins \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
    dnf5 -y copr enable ublue-os/akmods && \
    dnf5 -y install /tmp/kmods/*.rpm && \
    depmod -a "$(cat /tmp/kver)" && \
    dnf5 -y swap mesa-va-drivers mesa-va-drivers-freeworld --allowerasing && \
    dnf5 -y install gstreamer1-plugins-ugly gstreamer1-libav && \
    dnf5 -y swap libavcodec-free libavcodec-freeworld --allowerasing && \
    dnf5 -y copr remove ublue-os/akmods && \
    rpm -q libavcodec-freeworld mesa-va-drivers-freeworld && \
    dnf5 clean all

COPY ./files /

# Rescue/emergency mode works with Fedora's locked root
RUN chmod +x /usr/lib/systemd/system-generators/coreos-sulogin-force-generator && \
    systemctl enable bootc-update-ca-trust.service bootc-update-crypto-policies.service getty@tty1.service
RUN rm -rf /tmp/* /var/cache/* /var/lib/dnf /var/log/dnf5.log* /run/dnf

RUN bootc container lint
