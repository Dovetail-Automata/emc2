#!/bin/bash -e
#
# Update the Changelog file to create packages with version/release
# that continuously increments (to ensure `apt-get upgrade` works) and
# that contains identifying information about the package's source (to
# indicate who built the package, how, and from what revision).


# Computed variables
SOURCE_DIR=$(readlink -f $(dirname ${0})/..)
test ${TRAVIS_PULL_REQUEST:-false} = false && IS_PR=false || IS_PR=true
DISTRO=${TAG%-*}; DISTRO=${DISTRO:-unk.distro}
MARCH=${TAG%*-}; MARCH=${MARCH:-64}
COMMIT_TIMESTAMP="$(git log -1 --pretty=format:%at)"
SHA1SHORT="$(git log -1 --pretty=format:%h)"
COMMITTER_NAME="$(git log -1 --pretty=format:%an)"
COMMITTER_EMAIL="$(git log -1 --pretty=format:%ae)"

# Supplied variables for package configuration
MAJOR_MINOR_VERSION="${MAJOR_MINOR_VERSION:-0.1}"
TRAVIS_REPO=${TRAVIS_REPO_SLUG:+travis.${TRAVIS_REPO_SLUG/\//.}}
PKGSOURCE="${PKGSOURCE:-${TRAVIS_REPO:-unk.repo}}"
DEBIAN_SUITE="${DEBIAN_SUITE:-experimental}"
REPO_URL="${REPO_URL:-https://github.com/machinekit/machinekit}"

# Compute version
if ${IS_PR}; then
    # Use build timestamp (now) as pkg version patchlevel
    TIMESTAMP="$(date +%s)"
    PR_OR_BRANCH="pr${TRAVIS_PULL_REQUEST}"
    COMMIT_URL="${REPO_URL}/pull/${TRAVIS_PULL_REQUEST}"
else
    # Use merge commit timestamp as pkg version patchlevel
    TIMESTAMP="$COMMIT_TIMESTAMP"
    PR_OR_BRANCH="${TRAVIS_BRANCH:-unk.branch}"
    COMMIT_URL="${REPO_URL}/commit/${SHA1SHORT}"
fi

# sanitize upstream identifier
UPSTREAM_ID=${PKGSOURCE//[-_]/}.${PR_OR_BRANCH//[-_]/}

VERSION="${MAJOR_MINOR_VERSION}.${TIMESTAMP}"

# Compute release
RELEASE="1${UPSTREAM_ID}.git${SHA1SHORT}~1${DISTRO}"

###########################################################
# Generate debian/changelog entry
#
# https://www.debian.org/doc/debian-policy/ch-source.html#s-dpkgchangelog

cd ${SOURCE_DIR}

mv debian/changelog debian/changelog.old
cat > debian/changelog <<EOF
machinekit (${VERSION}-${RELEASE}) ${DEBIAN_SUITE}; urgency=low

  * Travis CI rebuild for ${DISTRO}, ${PR_OR_BRANCH}, commit ${SHA1SHORT}
    - ${COMMIT_URL}

 -- ${COMMITTER_NAME} <${COMMITTER_EMAIL}>  $(date -R)

EOF
echo "New changelog entry:"
cat debian/changelog # debug output
cat debian/changelog.old >> debian/changelog

# build sources on amd64
if test ${MARCH} = 64; then
    # create upstream tarball only on amd64
    git archive HEAD | bzip2 -z > \
        ../machinekit_${VERSION}.orig.tar.bz2
    dpkg-source -b .
fi
