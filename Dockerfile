ARG STAGE4a_TAG
FROM dynainstrumentsoss/${STAGE4a_TAG}
LABEL maintainer="linuxer (at) quantentunnel.de"

# This is modeled after the following sources:
#  * https://github.com/wuodan-docker/gentoo-crossdev-armv6j_hardfp
#  * https://wiki.gentoo.org/wiki/Embedded_Handbook
#  * https://wiki.gentoo.org/wiki/Cross_build_environment

# prepare build utilities and the like
COPY host-files-stage4/ /

# prepare chroot target utilities
COPY target-utilities-stage4/ /usr/${TARGET}/

CMD /bin/bash -il
