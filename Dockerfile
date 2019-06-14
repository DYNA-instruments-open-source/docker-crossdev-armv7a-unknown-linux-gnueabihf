FROM dynainstrumentsoss/build-env-crossdev:gentoo
MAINTAINER linuxer (at) quantentunnel.de

# This is modeled after the following sources:
#  * https://github.com/wuodan-docker/gentoo-crossdev-armv6j_hardfp
#  * https://wiki.gentoo.org/wiki/Embedded_Handbook
#  * https://wiki.gentoo.org/wiki/Cross_build_environment

# prepare portage, cross-compler, static QEMU, etc.
COPY host-files-1/ /

RUN QEMU_USER_TARGETS="arm" QEMU_SOFTMMU_TARGETS="arm" USE="static-user static-libs symlink" emerge -v sys-kernel/gentoo-sources app-emulation/qemu dev-util/ninja

# create toolchain
ENV TARGET=armv7a-unknown-linux-gnueabihf
RUN crossdev --stable -t "${TARGET}"
RUN crossdev --stable -t "${TARGET}" --ex-only --ex-gdb

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

# set target make.conf, configure target-files
COPY target-files-colibri-imx6ull/ /usr/${TARGET}/

# set target make profile
RUN ln -s -f -T ../../usr/portage/profiles/default/linux/arm/17.0/armv7a /usr/${TARGET}/etc/portage/make.profile && \
	mkdir -p /usr/${TARGET}/usr/portage && \
	ln -s -f -T ../../../../usr/portage/profiles /usr/${TARGET}/usr/portage/profiles && \
# add symlink to lib64, see https://wiki.gentoo.org/wiki/Cross_build_environment#Known_bugs_and_limitations
	ln -s -f -T lib /usr/${TARGET}/usr/lib64 && \
	ln -s -f -T /tmp /usr/${TARGET}/usr/${TARGET}/tmp

# this will contain failures, gcc fails for sure
# TODO: how to run perl-cleaner --all
RUN ${TARGET}-emerge --jobs=8 --load-average=12.9 --root=/usr/${TARGET} -uv --keep-going \
	--exclude "app-crypt/pinentry sys-libs/pam dev-python/pyblake2 dev-python/pyxattr sys-apps/portage sys-apps/util-linux sys-devel/gcc dev-libs/gmp sys-apps/groff sys-devel/binutils dev-libs/libpcre" \
	@world || true

# install a default kernel
RUN USE="symlink" ${TARGET}-emerge --jobs=8 --load-average=12.9 --root=/usr/${TARGET}/ sys-kernel/gentoo-sources

# run the missing system update to the end
# TODO: how to run perl-cleaner --all
#RUN /etc/init.d/qemu-binfmt --quiet start ; \
#	chroot /usr/${TARGET} /bin/bash --login /usr/local/bin/update-world

# prepare build utilities and the like
COPY host-files-2/ /

# prepare chroot target utilities
COPY target-utilities/ /usr/${TARGET}/

# prepare chroot
RUN cp /usr/local/bin/target-chroot /usr/local/bin/${TARGET}-chroot && \
	cp /usr/local/bin/target-xkmake /usr/local/bin/${TARGET}-xkmake && \
	chmod +x /usr/local/bin/${TARGET}-{chroot,xkmake}
CMD /bin/bash -il
