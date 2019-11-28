ARG STAGE4b_TAG
FROM ${STAGE4b_TAG}
LABEL maintainer="linuxer (at) quantentunnel.de"
ARG MERGE_JOBS

# This is modeled after the following sources:
#  * https://github.com/wuodan-docker/gentoo-crossdev-armv6j_hardfp
#  * https://wiki.gentoo.org/wiki/Embedded_Handbook
#  * https://wiki.gentoo.org/wiki/Cross_build_environment

RUN echo YES | etc-update --automode -9; \
    rm -rf /usr/${TARGET}/var/tmp/portage && mkdir -p /usr/${TARGET}/var/tmp/portage

VOLUME /usr/${TARGET}/var/tmp/portage

# prepare build utilities and the like
COPY host-files-stage5/ /
RUN cp -l /usr/local/bin/target-xkmake /usr/local/bin/${TARGET}-xkmake && \
    chmod +x /usr/local/bin/*-xkmake

# prepare chroot target utilities
COPY target-files-stage5/ /usr/${TARGET}/

CMD /bin/bash -il
