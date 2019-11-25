#!/bin/bash

docker_dir=$(dirname $(readlink -f $0))

: "${MERGE_JOBS:="--jobs=16"}"
: "${REPO:=dynainstrumentsoss}"
: "${IMAGE:=$(basename $docker_dir)}"
: "${TAG:=2019.11}"
STAGE3_TAG=${REPO}/${IMAGE}-stage3:${TAG}
STAGE4a_TAG=${REPO}/${IMAGE}-stage4-a:${TAG}
STAGE4b_TAG=${REPO}/${IMAGE}-stage4-b:${TAG}
FULL_TAG=${REPO}/${IMAGE}-stage5:${TAG}
DATETIME=$(date '+%Y%m%d%H%M%S')

test -r $docker_dir/stage3.Dockerfile  || { echo "missing stage3.Dockerfile beside $0"; exit -1; }
test -r $docker_dir/stage4a.Dockerfile || { echo "missing stage4a.Dockerfile beside $0"; exit -1; }
test -r $docker_dir/stage5.Dockerfile || { echo "missing stage5.Dockerfile beside $0"; exit -1; }

test -r $docker_dir/.dockerignore || {
cat >$docker_dir/.dockerignore <<EOM
$(basename $(readlink -f $0))
log/*
EOM

}

mkdir -p ${docker_dir}/log
echo "Build image, write log to : ${docker_dir}/log/docker-build.${DATETIME}.log"
docker build -f stage3.Dockerfile  --build-arg BASE_TAG=${TAG}          --build-arg "MERGE_JOBS=${MERGE_JOBS}" --build-arg http_proxy=$http_proxy --build-arg https_proxy=${https_proxy:-$http_proxy} --tag ${STAGE3_TAG}  $docker_dir 2>&1 | tee ${docker_dir}/log/docker-build-stage3.${DATETIME}.log  || exit $?
docker build -f stage4a.Dockerfile --build-arg STAGE3_TAG=${STAGE3_TAG} --build-arg "MERGE_JOBS=${MERGE_JOBS}" --build-arg http_proxy=$http_proxy --build-arg https_proxy=${https_proxy:-$http_proxy} --tag ${STAGE4a_TAG} $docker_dir 2>&1 | tee ${docker_dir}/log/docker-build-stage4a.${DATETIME}.log || exit $?

# build stage4b in privileged container, mimic caching
mkdir -p  ${docker_dir}/stage4b-cache

# cleaup build cmd cache by removing all cache tags with missing image
IMAGES_LIST=$(docker images -aq --no-trunc)
for h in ${docker_dir}/stage4b-cache/*; do
  echo $h | egrep -q '\.txt$' && continue
  test -e $h && { echo "${IMAGES_LIST}" | grep -q $(cat $h) || { rm -f $h; rm -f $h.txt; } ; }
done

# run sequence of privileged build commands
INTERMEDIATE_IMAGE=$(docker image ls -q --no-trunc ${STAGE4a_TAG})
for BUILD_CMD in "target-chroot locale-gen" \
                 "target-chroot emerge -1u $MERGE_JOBS sys-devel/distcc \; sleep 2m" \
                 "target-chroot emerge -1u $MERGE_JOBS sys-devel/binutils${BINUTILS_SLOT:+:$BINUTILS_SLOT}" \
                 "target-chroot BINUTILS_SLOT=$BINUTILS_SLOT switch-toolchain" \
                 "target-chroot emerge -1uDN $MERGE_JOBS --autounmask-backtrack=y --keep-going sys-kernel/linux-headers${KERNELHEADERS_VERSION:+-$KERNELHEADERS_VERSION}\; echo YES \| etc-update --automode -9" \
                 "target-chroot emerge -1u $MERGE_JOBS sys-libs/glibc${GLIBC_VERSION:+-$GLIBC_VERSION}" \
                 "target-chroot emerge -1u $MERGE_JOBS sys-devel/gcc${GCC_SLOT:+:$GCC_SLOT} \; sleep 2m" \
                 "target-chroot BINUTILS_SLOT=$BINUTILS_SLOT GCC_SLOT=$GCC_SLOT switch-toolchain" \
                 "target-chroot emerge -1u $MERGE_JOBS sys-devel/gdb" \
                 "target-chroot emerge -uDN $MERGE_JOBS --autounmask-backtrack=y --keep-going @world\; echo YES \| etc-update --automode -9\; true" \
                 "target-chroot perl-cleaner --all -- $MERGE_JOBS" \
                 "target-chroot /usr/local/sbin/distcc-fix" \
                 "target-chroot emerge --depclean sys-devel/binutils sys-devel/gcc sys-libs/glibc" \
                 "target-chroot quickpkg-all-parallel" \
                 ; do 
  BUILD_HASH=$(echo -n ${INTERMEDIATE_IMAGE}:${BUILD_CMD} | md5sum - | cut -c -32)
  echo "${INTERMEDIATE_IMAGE}:${BUILD_CMD}" >${docker_dir}/stage4b-cache/${BUILD_HASH}.txt
  if [ -e ${docker_dir}/stage4b-cache/${BUILD_HASH} ]; then
    echo "image '"${INTERMEDIATE_IMAGE}"' takes '"${BUILD_CMD}"' from cache"
    INTERMEDIATE_IMAGE=$(cat ${docker_dir}/stage4b-cache/${BUILD_HASH})
  else
    echo "image '"${INTERMEDIATE_IMAGE}"' runs '"${BUILD_CMD}"'"
    INTERMEDIATE_CONTAINER=$(docker run --detach --privileged -e http_proxy=${http_proxy} -e https_proxy=${https_proxy:-$http_proxy} ${INTERMEDIATE_IMAGE} /bin/bash -l -c "${BUILD_CMD}") || exit $?
    docker logs --follow $INTERMEDIATE_CONTAINER 2>&1 | tee -a ${docker_dir}/log/docker-build-stage4b.${DATETIME}.log || { docker stop $INTERMEDIATE_CONTAINER; exit $(docker wait $INTERMEDIATE_CONTAINER); }
    INTERMEDIATE_RESULT=$(docker wait $INTERMEDIATE_CONTAINER)
    test ${INTERMEDIATE_RESULT:--256} -eq 0 || exit $INTERMEDIATE_RESULT
    INTERMEDIATE_IMAGE=$(docker commit --change 'LABEL maintainer="linuxer (at) quantentunnel.de"' --message "RUNP ${BUILD_CMD}" $INTERMEDIATE_CONTAINER) || exit $?
    docker rm ${INTERMEDIATE_CONTAINER} || exit $?
    echo ${INTERMEDIATE_IMAGE} >${docker_dir}/stage4b-cache/${BUILD_HASH}
  fi
done

docker tag ${INTERMEDIATE_IMAGE} ${STAGE4b_TAG} || exit $?

# build stage 5 final
docker build -f stage5.Dockerfile --build-arg STAGE4b_TAG=${STAGE4b_TAG} --build-arg "MERGE_JOBS=${MERGE_JOBS}" --build-arg http_proxy=$http_proxy --build-arg https_proxy=${https_proxy:-$http_proxy} --tag ${FULL_TAG} $docker_dir 2>&1 | tee ${docker_dir}/log/docker-build-stage5.${DATETIME}.log
