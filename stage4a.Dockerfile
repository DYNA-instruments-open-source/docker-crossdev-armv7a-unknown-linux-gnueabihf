ARG STAGE3_TAG
FROM ${STAGE3_TAG}
LABEL maintainer="linuxer (at) quantentunnel.de"
ARG MERGE_JOBS

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
	ln -s -f -T /tmp /usr/${TARGET}/usr/${TARGET}/tmp && \
# delete some files, which prevent regular updates by portage/emerge \
        rm -f /usr/$TARGET/sbin/unix_chkpwd \
              /usr/$TARGET/bin/ping \
              /usr/$TARGET/bin/arping \
              /usr/$TARGET/usr/lib/misc/ssh-keysign

# install a default kernel and some tools
RUN USE="symlink" ${TARGET}-emerge ${MERGE_JOBS} --root=/usr/${TARGET}/ \
        sys-kernel/gentoo-sources \
        app-portage/gentoolkit \
        sys-fs/f2fs-tools \
        sys-fs/nilfs-utils \
        sys-fs/mtd-utils

# this will contain failures, gcc fails for sure
# perl-cleaner -all will be run in stage4b in a privileged container
RUN  chmod ug-s /usr/${TARGET}/bin/{passwd,su} /usr/${TARGET}/usr/bin/{expiry,newgidmap,newuidmap,chsh,chfn,newgrp,gpasswd,chage}; \
     ${TARGET}-emerge ${MERGE_JOBS} --root=/usr/${TARGET} -uv --keep-going \
	--exclude "app-crypt/pinentry dev-python/pyblake2 dev-python/pyxattr sys-apps/util-linux sys-apps/portage sys-devel/gcc dev-libs/gmp sys-apps/groff sys-devel/binutils dev-libs/libpcre" \
	@world || true

COPY switch-toolchain /usr/$TARGET/usr/local/bin
COPY target-distcc-fix1 /usr/${TARGET}/etc/portage/bashrc
COPY target-distcc-fix2 /usr/${TARGET}/usr/local/sbin/distcc-fix
COPY target-quickpkg-all-parallel /usr/${TARGET}/usr/local/sbin/quickpkg-all-parallel
COPY target-distcc-hosts /usr/${TARGET}/etc/distcc/hosts

RUN  chmod +x /usr/${TARGET}/usr/local/bin/switch-toolchain && \
     chmod +x /usr/${TARGET}/usr/local/sbin/* && \
     chmod -s /usr/${TARGET}/bin/mount /usr/$TARGET/bin/umount

CMD /bin/bash -il
