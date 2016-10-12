#!/bin/bash -e

# Check variables
if test -z "${FTP_HOST}" -o -z "${FTP_USER}" -o -z "${FTP_PASS}"; then
    echo "FTP_HOST, FTP_USER and FTP_PASS not set; skipping failure upload" >&2
    exit 0
fi

# Create tarball
SOURCEDIR=$(readlink -f $(dirname $0)/..)
TARBALL="machinekit-fail-$(date +%FT%T)-${TRAVIS_COMMIT:0:8}.tgz"
tar czf /tmp/${TARBALL} ${SOURCEDIR}

# FTP to public place
lftp -u ${FTP_USER},${FTP_PASS} -e "put /tmp/${TARBALL};quit" ${FTP_HOST}

# Tell user
FTP_URL="ftp://${FTP_HOST}/${TARBALL}"
echo "Uploaded tarball of failed build to ${FTP_URL}" >&2
