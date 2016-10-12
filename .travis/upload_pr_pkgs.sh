#!/bin/bash -e

# Don't upload unless this is a PR
if test "${TRAVIS_PULL_REQUEST}" = false; then
    echo "$0 skipping upload:  not a PR" >&2
    exit 0
fi

# Check variables
if test -z "${FTP_HOST}" -o -z "${FTP_USER}" -o -z "${FTP_PASS}"; then
    echo "$0 skipping upload:  FTP_HOST, FTP_USER and FTP_PASS not set" >&2
    exit 0
fi

# Create tarball
TARBALL="machinekit-pr-pkgs.tgz"
MARCH=${TAG#*-}
PKG_GLOB="*.deb *.changes"
test "${MARCH}" != 64 || PKG_GLOB+="*.debian.tar.* *.dsc *.orig.tar.*"
cd ..
tar czf /tmp/${TARBALL} ${PKG_GLOB}

# FTP to public place
lftp -u ${FTP_USER},${FTP_PASS} \
    -e "put /tmp/${TARBALL};quit" \
    ${FTP_HOST}

# Tell user
FTP_URL="ftp://${FTP_HOST}/${TARBALL}"
echo "Uploaded tarball of PR packages to ${FTP_URL}" >&2



