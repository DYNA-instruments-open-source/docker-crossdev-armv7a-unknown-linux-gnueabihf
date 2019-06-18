#!/bin/bash

docker_dir=$(dirname $(readlink -f $0))

REPO=dynainstrumentsoss
IMAGE=$(basename $docker_dir)
TAG=2019.06
STAGE3_TAG=${REPO}/${IMAGE}-stage3:${TAG}
STAGE4a_TAG=${REPO}/${IMAGE}-stage-pre4-a:${TAG}
STAGE4b_TAG=${REPO}/${IMAGE}-stage-pre4-b:${TAG}
FULL_TAG=${REPO}/${IMAGE}-stage4:${TAG}
DATETIME=$(date '+%Y%m%d%H%M%S')

test -r $docker_dir/stage3.Dockerfile  || { echo "missing stage3.Dockerfile beside $0"; exit -1; }
test -r $docker_dir/stage4a.Dockerfile || { echo "missing stage4a.Dockerfile beside $0"; exit -1; }
test -r $docker_dir/Dockerfile || { echo "missing Dockerfile beside $0"; exit -1; }

echo "Refreshing base images"
for base in $(sed -En 's#^[[:space:]]*FROM[[:space:]]+([^ \t]+)#\1#p' ${docker_dir}/Dockerfile.stage3 | sed -E 's#\t# #g' | cut -d ' ' -f 1); do
	docker pull ${base}
done

test -r $docker_dir/.dockerignore || {
cat >$docker_dir/.dockerignore <<EOM
$(basename $(readlink -f $0))
log/*
EOM

}

mkdir -p ${docker_dir}/log
echo "Build image, write log to : ${docker_dir}/log/docker-build.${DATETIME}.log"
docker build -f stage3.Dockerfile                                         --build-arg http_proxy=$http_proxy --build-arg https_proxy=${https_proxy:-$http_proxy} --tag ${STAGE3_TAG}  $docker_dir 2>&1 | tee ${docker_dir}/log/docker-build-stage3.${DATETIME}.log || exit $?
docker build -f stage4a.Dockerfile --build-arg STAGE3_TAG=${STAGE3_TAG}   --build-arg http_proxy=$http_proxy --build-arg https_proxy=${https_proxy:-$http_proxy} --tag ${STAGE4a_TAG} $docker_dir 2>&1 | tee ${docker_dir}/log/docker-build-stage4a.${DATETIME}.log || exit $?

# build stage4b in privileged container, mimic caching
mkdir -p stage4b-cache
STAGE3_IMAGE=$(docker image ls -q ${STAGE3_TAG})
test -e stage4b-cache/${STAGE3_IMAGE} || {
  touch stage4b-cache/${STAGE3_IMAGE}
  docker rmi ${STAGE4b_TAG}
  STAGE4b_CONTAINER=$(docker run --privileged -e http_proxy=${http_proxy} -e https_proxy=${https_proxy:-$http_proxy} ${STAGE4a_TAG} /bin/bash -l -c "target-chroot locale-gen") || exit $?
  STAGE4b_IMAGE=$(docker commit --message "RUNP target-chroot locale-gen" $STAGE4b_CONTAINER) || exit $?
  STAGE4b_CONTAINER=$(docker run --privileged -e http_proxy=${http_proxy} -e https_proxy=${https_proxy:-$http_proxy} ${STAGE4b_IMAGE} /bin/bash -l -c "target-chroot emerge -v1uDN sys-devel/binutils${BINUTILS_SLOT:+:$BINUTILS_SLOT} sys-libs/glibc${GLIBC_VERSION:+-$GLIBC_VERSION} sys-kernel/linux-headers${KERNELHEADERS_VERSION:+-$KERNELHEADERS_VERSION} sys-devel/gcc${GCC_SLOT:+:$GCC_SLOT}") || exit $?
  STAGE4b_IMAGE=$(docker commit --message "RUNP target-chroot emerge -v1uDN sys-devel/binutils${BINUTILS_SLOT:+:$BINUTILS_SLOT} sys-libs/glibc${GLIBC_VERSION:+-$GLIBC_VERSION} sys-kernel/linux-headers${KERNELHEADERS_VERSION:+-$KERNELHEADERS_VERSION} sys-devel/gcc${GCC_SLOT:+:$GCC_SLOT}" $STAGE4b_CONTAINER) || exit $?
  STAGE4b_CONTAINER=$(docker run --privileged -e http_proxy=${http_proxy} -e https_proxy=${https_proxy:-$http_proxy} ${STAGE4b_IMAGE} /bin/bash -l -c "target-chroot emerge -vuDN --keep-going @world") || exit $?
  STAGE4b_IMAGE=$(docker commit --message "RUNP target-chroot emerge -vuDN --keep-going @world" $STAGE4b_CONTAINER) || exit $?
  STAGE4b_CONTAINER=$(docker run --privileged -e http_proxy=${http_proxy} -e https_proxy=${https_proxy:-$http_proxy} ${STAGE4b_IMAGE} /bin/bash -l -c "target-chroot perl-cleaner --all") || exit $?
  STAGE4b_IMAGE=$(docker commit --message "RUNP target-chroot perl-cleaner --all" $STAGE4b_CONTAINER) ${STAGE4b_TAG} || exit $?
}

# build stage 4 final
docker build -f Dockerfile         --build-arg STAGE4b_TAG=${STAGE4b_TAG} --build-arg http_proxy=$http_proxy --build-arg https_proxy=${https_proxy:-$http_proxy} --tag ${FULL_TAG}    $docker_dir 2>&1 | tee ${docker_dir}/log/docker-build-stage4.${DATETIME}.log
