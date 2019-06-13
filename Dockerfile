FROM dynainstrumentsoss/build-env-crossdev:gentoo
MAINTAINER linuxer (at) quantentunnel.de

# This is modeled after the following sources:
#  * https://github.com/wuodan-docker/gentoo-crossdev-armv6j_hardfp
#  * https://wiki.gentoo.org/wiki/Embedded_Handbook
#  * https://wiki.gentoo.org/wiki/Cross_build_environment

# prepare portage, cross-compler, static QEMU, etc.
COPY host-files-1/ /

# create toolchain
ENV TARGET=armv7a-unknown-linux-gnueabihf
RUN crossdev --stable -t "${TARGET}"
RUN crossdev --stable -t "${TARGET}" --ex-only --ex-gdb

RUN QEMU_USER_TARGETS="arm" QEMU_SOFTMMU_TARGETS="arm" USE="static-user static-libs" emerge --quiet qemu &

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

# set target make.conf, configure target-files
COPY target-files-colibri-imx6ull/ /usr/${TARGET}/

# set target make profile
RUN cd /usr/${TARGET}/etc/portage && \
	ln -s -f -T ../../usr/portage/profiles/default/linux/arm/17.0/armv7a make.profile && \
	\
# add symlink to lib64, see https://wiki.gentoo.org/wiki/Cross_build_environment#Known_bugs_and_limitations
	cd /usr/${TARGET}/usr && \
	ln -s lib lib64

# this will contain failures, gcc fails for sure
#RUN ${TARGET}-emerge -uv --keep-going --exclude "sys-apps/file sys-apps/util-linux sys-devel/gcc" @world || exit 0

# run the missing system update to the end
#RUN /etc/init.d/qemu-binfmt --quiet start ; \
#	chroot /usr/${TARGET} /bin/bash --login /usr/local/bin/update-world

# prepare build utilities and the like
COPY host-files-2/ /

# prepare chroot
RUN chmod +x /usr/local/bin/chroot-armv7a-hf
#CMD chroot-armv7a-hf
CMD /bin/bash -il
