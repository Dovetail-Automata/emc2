#!/bin/bash -xe

IMAGE=${DOCKER_CONTAINER:-zultron/mk-builder-3}
SOURCE_DIR=$(readlink -f $(dirname ${0})/..)
DISTRO=${TAG%-*}
MARCH=${TAG#*-}

###########################################################
# Configure source package
cd ${SOURCE_DIR}
case ${DISTRO} in
    wheezy) debian/configure -prxt 8.5 ;;
    *) debian/configure -prxt 8.6 ;;
esac

###########################################################
# Build binary packages

case ${MARCH} in
    64) BUILD_OPTS="" ;;
    32)
	SYSROOT=/sysroot/i386
	BUILD_OPTS="-a i386 -B"
	;;
    armhf)
	SYSROOT=/sysroot/armhf
	BUILD_OPTS="-a armhf -B -d"
	;;
    *) echo "Error:  unknown machine arch '${MARCH}'" >&2; exit 1 ;;
esac

# Run the Docker container as follows:
# - Privileged mode (probably not needed in Travis CI)
# - As Travis CI user/group
# - Bind-mount home directory for MK source and `~/.ccache`
# - Start in same directory
docker run --rm \
    -it --privileged \
    -u `id -u`:`id -g` \
    -e USER=travis \
    -v ${HOME}:${HOME} \
    -w ${SOURCE_DIR} \
    ${IMAGE} env SYSROOT=$SYSROOT dpkg-buildpackage -uc -us ${BUILD_OPTS}
