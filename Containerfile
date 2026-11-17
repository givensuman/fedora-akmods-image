ARG BASE=quay.io/fedora/fedora-bootc

# ---- build kernel modules against the base image's kernel ----
FROM ${BASE} AS builder

RUN dnf5 -y install dnf5-plugins \
	https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
	https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
	dnf5 -y copr enable ublue-os/akmods

# Use the *installed* kernel, not the build host's
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

# ---- final image ----
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
	sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/_copr*ublue-os*akmods*.repo && \
	rpm -q libavcodec-freeworld mesa-va-drivers-freeworld && \
	rm -rf /tmp/kmods /tmp/kver && dnf5 clean all && rm -rf /run/dnf

COPY ./files /

RUN bootc container lint
