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

# The module dir is the single source of truth: this build runs it, and
# fedora-desktop-image copies it out of this image and runs it too.
COPY --from=builder /out /usr/share/modules/akmods/rpms
COPY --from=builder /kver /usr/share/modules/akmods/kver
COPY ./files /usr/share/modules/akmods/files
COPY --chmod=0755 ./apply.sh /usr/share/modules/akmods/apply.sh

RUN /usr/share/modules/akmods/apply.sh

RUN bootc container lint
