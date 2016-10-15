#!/bin/bash -e
#
# Build Machinekit packages in Travis CI
#
# This script can be run manually for testing.  Some or all of the
# following variables must be set, such as:
#
# CMD=deb TAG=armhf NOSOURCE=true .travis/docker_build.sh

# Inputs from outside; set defaults
CMD=${CMD:-deb}
IMAGE=${DOCKER_CONTAINER:-zultron/mk-cross-builder}
TAG=${TAG:-amd64}
JOBS=${JOBS:-4}
NOSOURCE=${NOSOURCE:-false}  # if true, don't build source

###########################################################
# Set build parameters

case ${TAG} in
    amd64)
	BUILD_OPTS='-b'                  # Build all binary packages
	RUN_TESTS='runtests tests'
	;;
    i386)
	BUILD_OPTS="-a i386 -B"          # Build only arch binary packages
	BUILD_OPTS+=" -d"                # Root fs missing build deps; force
	RUN_TESTS=''                     # No tests for cross-compile
	;;
    armhf|raspbian)
	BUILD_OPTS="-a armhf -B"         # Build only arch binary packages
	BUILD_OPTS+=" -d"                # Root fs missing build deps; force
	RUN_TESTS=''                     # No tests for cross-compile
	;;
    *) echo "Error:  unknown tag '${TAG}'" >&2; exit 1 ;;
esac

# Path to source
SOURCE_DIR=$(readlink -f $(dirname ${0})/..)

# DH_VERBOSE turns on verbose package builds
! ${MK_PACKAGE_VERBOSE:-false} || export DH_VERBOSE=1

# Parallel jobs in `make`
export DEB_BUILD_OPTIONS="parallel=${JOBS}"

declare -a BUILD_CL
case $CMD in
    "deb") # Build Debian packages
	BUILD_CL=(
	    dpkg-buildpackage -uc -us ${BUILD_OPTS} ${JOBS+-j$JOBS}
	)
	;;
    "test") # RIP build and regression tests
	BUILD_CL=(
	    bash -xec "
		cd src;
		./autogen.sh;
		./configure --host=\$HOST_MULTIARCH;
		make -j${JOBS};
		sudo make setuid >& /dev/null || true;
		cd ..;
		. scripts/rip-environment;
		echo -e 'ANNOUNCE_IPV4=0\nANNOUNCE_IPV6=0' >> \
		    etc/linuxcnc/machinekit.ini
		${RUN_TESTS:-true}"
	)
	;;
    '')  echo "Please set CMD to 'deb' or 'test'" >&2; exit 1;;
    *)   echo "Unkown command '$CMD'" >&2; exit 1 ;;
esac

# Print debug info
echo "Environment build parameters:"
echo "    SOURCE_DIR='$SOURCE_DIR'"
if test "$CMD" = "deb"; then
    echo "    DH_VERBOSE='$DH_VERBOSE'"
    echo "    DEB_BUILD_OPTIONS='$DEB_BUILD_OPTIONS'"
fi
echo "Build command line:"
echo "    '${BUILD_CL[@]}'"

###########################################################
# Run build

# Show user what we're doing from now on
set -x

# For package builds, configure the source package
if test "$CMD" = "deb"; then
    # Configure source package
    cd ${SOURCE_DIR}
    debian/configure -prxt 8.6

    # Build source package; requires `dpkg-source`
    ${NOSOURCE} || .travis/deb_update_changelog.sh
fi

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
    -e DEB_BUILD_OPTIONS \
    -e DH_VERBOSE \
    ${IMAGE}:${TAG} \
    "${BUILD_CL[@]}"
