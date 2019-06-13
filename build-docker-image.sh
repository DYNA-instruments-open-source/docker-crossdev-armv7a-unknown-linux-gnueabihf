#!/bin/bash

docker_dir=$(dirname $(readlink -f $0))

REPO=dynainstrumentsoss
IMAGE=$(basename $docker_dir)
TAG=gentoo
FULL_TAG=${REPO}/${IMAGE}:${TAG}
DATETIME=$(date '+%Y%m%d%H%M%S')

test -r $docker_dir/Dockerfile || { echo "missing Dockerfile beside $0"; exit -1; }

echo "Refreshing base images"
for base in $(sed -En 's#^[[:space:]]*FROM[[:space:]]+([^ \t]+)#\1#p' ${docker_dir}/Dockerfile | sed -E 's#\t# #g' | cut -d ' ' -f 1); do
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
exec docker build --build-arg http_proxy=$http_proxy --build-arg https_proxy=${https_proxy:-$http_proxy} --tag ${FULL_TAG} $docker_dir 2>&1 | tee ${docker_dir}/log/docker-build.${DATETIME}.log
