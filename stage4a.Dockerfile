ARG STAGE3_TAG
FROM dynainstrumentsoss/${STAGE3_TAG}
LABEL maintainer="linuxer (at) quantentunnel.de"

# This is modeled after the following sources:
#  * https://github.com/wuodan-docker/gentoo-crossdev-armv6j_hardfp
#  * https://wiki.gentoo.org/wiki/Embedded_Handbook
#  * https://wiki.gentoo.org/wiki/Cross_build_environment


# set target make.conf, configure target-files
COPY target-files-stage4-colibri-imx6ull/ /usr/${TARGET}/

# set target make profile
RUN ln -s -f -T ../../usr/portage/profiles/default/linux/arm/17.0/armv7a /usr/${TARGET}/etc/portage/make.profile && \
	mkdir -p /usr/${TARGET}/usr/portage && \
	ln -s -f -T ../../../../usr/portage/profiles /usr/${TARGET}/usr/portage/profiles && \
# add symlink to lib64, see https://wiki.gentoo.org/wiki/Cross_build_environment#Known_bugs_and_limitations
	ln -s -f -T lib /usr/${TARGET}/usr/lib64 && \
	ln -s -f -T /tmp /usr/${TARGET}/usr/${TARGET}/tmp

# this will contain failures, gcc fails for sure
# perl-cleaner -all will be run in stage4b in a privileged container
RUN ${TARGET}-emerge --jobs=8 --load-average=12.9 --root=/usr/${TARGET} -uv --keep-going \
	--exclude "app-crypt/pinentry sys-libs/pam dev-python/pyblake2 dev-python/pyxattr sys-apps/portage sys-apps/util-linux sys-devel/gcc dev-libs/gmp sys-apps/groff sys-devel/binutils dev-libs/libpcre" \
	@world || true

# install a default kernel
RUN USE="symlink" ${TARGET}-emerge --jobs=8 --load-average=12.9 --root=/usr/${TARGET}/ sys-kernel/gentoo-sources app-portage/gentoolkit sys-devel/gdb

# run the missing system update to the end
# commented, will be run in an privileged container during the build script
#RUNP /etc/init.d/qemu-binfmt --quiet start && \
#	chroot /usr/${TARGET} /bin/bash --login -c locale-gen && \
#	chroot /usr/${TARGET} /bin/bash --login -c "emerge -v1uDN sys-devel/binutils${BINUTILS_SLOT:+:$BINUTILS_SLOT} sys-libs/glibc${GLIBC_VERSION:+-$GLIBC_VERSION} sys-kernel/linux-headers${KERNELHEADERS_VERSION:+-$KERNELHEADERS_VERSION} sys-devel/gcc${GCC_SLOT:+:$GCC_SLOT}" && \
#	chroot /usr/${TARGET} /bin/bash --login -c "emerge -vuDN --keep-going @world" && \
#	chroot /usr/${TARGET} /bin/bash --login -c "perl-cleaner --all"

CMD /bin/bash -il
