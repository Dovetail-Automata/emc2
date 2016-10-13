#!/bin/bash -xe
#
# Build Machinekit packages in Travis CI
#
# This script can be run manually for testing.  Customize the below
# environment variables.

# Inputs from outside; set defaults
IMAGE=${DOCKER_CONTAINER:-zultron/mk-builder-3:jessie}
TAG=${TAG:-jessie-64}
JOBS=${JOBS:-4}
NOSOURCE=${NOSOURCE:-false}  # if true, don't build source

# Computed
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
    64)
	DPKG_ROOT=                       # Don't use a sysroot for native arch
	FLAGS=                           # No extra CFLAGS/LDFLAGS
	BUILD_OPTS='-b'                  # Build all binary packages
	;;
    32)
	DPKG_ROOT='/sysroot/i386'        # Tell dpkg-shlibdeps to use sysroot
	FLAGS="--sysroot=$DPKG_ROOT"     # Tell gcc to use sysroot
	FLAGS+=' -m32'                   # Tell gcc to build for 32-bit arch
	BUILD_OPTS="-a i386 -B"          # Build only arch binary packages
	BUILD_OPTS+=" -d"                # Root fs missing build deps; force
	;;
    armhf)
	DPKG_ROOT='/sysroot/armhf'       # Tell dpkg-shlibdeps to use sysroot
	FLAGS="--sysroot=$DPKG_ROOT"     # Tell gcc to use sysroot
	BUILD_OPTS="-a armhf -B"         # Build only arch binary packages
	BUILD_OPTS+=" -d"                # Root fs missing build deps; force
	;;
    *) echo "Error:  unknown machine arch '${MARCH}'" >&2; exit 1 ;;
esac

# Pass values to Docker through env
export DPKG_ROOT
export CPPFLAGS="$FLAGS"
export LDFLAGS="$FLAGS"
# DH_VERBOSE turns on verbose package builds
! ${MK_PACKAGE_VERBOSE:-false} || export DH_VERBOSE=1
# Parallel jobs in `make`
DEB_BUILD_OPTIONS="parallel=${JOBS}"

# Build source package; requires `dpkg-source`
${NOSOURCE} || .travis/deb_update_changelog.sh

# Run the Docker container as follows:
# - Privileged mode (probably not needed in Travis CI)
# - As Travis CI user/group
# - Bind-mount home directory for MK source and `~/.ccache`
# - Start in same directory
# - Pass build-related environment variables
docker run --rm \
    -it --privileged \
    -u `id -u`:`id -g` \
    -e USER=travis \
    -v ${HOME}:${HOME} -e HOME \
    -w ${SOURCE_DIR} \
    -e DPKG_ROOT \
    -e CPPFLAGS \
    -e LDFLAGS \
    -e DEBUILD_OPTS \
    ${IMAGE} dpkg-buildpackage -uc -us ${BUILD_OPTS} ${JOBS+-j$JOBS}
