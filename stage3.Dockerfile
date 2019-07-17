ARG BASE_TAG=latest
FROM dynainstrumentsoss/build-env-crossdev:${BASE_TAG}
LABEL maintainer="linuxer (at) quantentunnel.de"
ARG MERGE_JOBS

# This is modeled after the following sources:
#  * https://github.com/wuodan-docker/gentoo-crossdev-armv6j_hardfp
#  * https://wiki.gentoo.org/wiki/Embedded_Handbook
#  * https://wiki.gentoo.org/wiki/Cross_build_environment

# prepare portage, cross-compler, static QEMU, etc.
COPY host-files-stage3/ /

RUN QEMU_USER_TARGETS="arm" QEMU_SOFTMMU_TARGETS="arm" USE="static-user static-libs symlink" emerge ${MERGE_JOBS} sys-kernel/gentoo-sources app-emulation/qemu

# create toolchain
ENV TARGET=armv7a-unknown-linux-gnueabihf
RUN crossdev --stable -t "${TARGET}" --portage "${MERGE_JOBS}"
RUN crossdev --stable -t "${TARGET}" --ex-only --ex-gdb --portage "${MERGE_JOBS}"

RUN emerge-wrapper --target "${TARGET}" --init

# Set the STAGE3_VERSION env variable
# http://distfiles.gentoo.org/releases/arm/autobuilds/20180831/stage3-armv7a_hardfp-20180831.tar.bz2
ENV STAGE3_DATE=20180831 STAGE3_ARCH=armv7a_hardfp \
	STAGE3_SHA512=1682d9fcff49977f4a934450a132b293e0f757906aa8c28b554178b8fbf433195a29b166a548476f4f92d43231727c4bbbd13d7650da4c2d79427c6aa28c2f2e
ENV STAGE3_FILE=stage3-"${STAGE3_ARCH}"-"${STAGE3_DATE}".tar.bz2
ENV STAGE3_URI=http://distfiles.gentoo.org/releases/arm/autobuilds/${STAGE3_DATE}/${STAGE3_FILE}

# Load the base system with stage3
RUN cd /var/tmp \
	&& curl -O "${STAGE3_URI}" \
	&& sha512sum $STAGE3_FILE | grep -q $STAGE3_SHA512 \
	&& tar xpf ${STAGE3_FILE} --xattrs-include='*.*' --numeric-owner -C /usr/${TARGET}/ \
	&& rm ${STAGE3_FILE} \
	&& cp /usr/bin/qemu-arm /usr/${TARGET}/usr/bin

COPY target-chroot /usr/local/bin/
RUN cp /usr/local/bin/target-chroot /usr/local/bin/${TARGET}-chroot && \
        chmod +x /usr/local/bin/target-chroot /usr/local/bin/${TARGET}-chroot
CMD /bin/bash -il

