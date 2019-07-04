ARG STAGE4b_TAG
FROM ${STAGE4b_TAG}
LABEL maintainer="linuxer (at) quantentunnel.de"
ARG MERGE_JOBS

# This is modeled after the following sources:
#  * https://github.com/wuodan-docker/gentoo-crossdev-armv6j_hardfp
#  * https://wiki.gentoo.org/wiki/Embedded_Handbook
#  * https://wiki.gentoo.org/wiki/Cross_build_environment

# prepare build utilities and the like
COPY host-files-stage5/ /

# prepare chroot target utilities
COPY target-utilities-stage5/ /usr/${TARGET}/

CMD /bin/bash -il
