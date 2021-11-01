#!/usr/bin/env bash
set -o errexit

function die(){
    echo "$0: fatal error: $*" >&2
    exit 1
}

if [ -z $FALCON_PKG ] ; then
    die "The environment variable FALCON_PKG needs to be set" \
     "e.g. export FALCON_PKG=falcon-sensor-6.12.0-10912.el8.x86_64.rpm" \
     "Aborting..."
fi

if [ ! -d licenses ] ; then
    die "A directory called 'licenses' with license files is missing. This is needed with license files to properly add licenses to the container. Aborting..."
fi

if [ ! -f entrypoint.sh ] ; then
    die "The 'entrypoint.sh' script is missing. Aborting..."
fi

command -v buildah >/dev/null 2>&1 || { die "buildah is not installed or exists in your \$PATH. Aborting..."; }

# Create a container
CONTAINER=$(buildah from registry.access.redhat.com/ubi8/ubi-micro)

# Mount the container filesystem
MOUNTPOINT=$(buildah mount $CONTAINER)

# Copy required files and directories
buildah copy $CONTAINER 'licenses' '/licenses'
buildah copy $CONTAINER 'entrypoint.sh' '/entrypoint.sh'

# Install packages required for falcon sensor
INSTALL_PKGS="libnl3 net-tools zip openssl hostname iproute procps $FALCON_PKG"

# Install a basic filesystem and minimal set of packages,
yum install -y \
    --installroot $MOUNTPOINT \
    --releasever 8 \
    --setopt install_weak_deps=false \
    --nodocs \
    ${INSTALL_PKGS}

yum clean all -y \
    --installroot $MOUNTPOINT

# Cleanup
buildah unmount $CONTAINER

# Get version from RPM
VERSION=$(echo $FALCON_PKG | awk -F- '{printf "%s\n",$3}')
REL=$(echo $FALCON_PKG | awk -F'-|\\.' '{printf "%s\n",$6}')

# Container configurations required for falcon sensor
buildah config --arch x86_64 $CONTAINER
buildah config --env PATH=".:/bin:/usr/bin:/sbin:/usr/sbin" $CONTAINER
buildah config --workingdir /opt/CrowdStrike $CONTAINER
buildah config --volume /var/log $CONTAINER
buildah config --entrypoint /entrypoint.sh $CONTAINER
buildah config --user root $CONTAINER

buildah config --author "CrowdStrike, Inc." $CONTAINER
buildah config --created-by "CrowdStrike, Inc." $CONTAINER
buildah config --label name="CrowdStrike Falcon Sensor" $CONTAINER
buildah config --label maintainer="integrations@crowdstrike.com" $CONTAINER
buildah config --label vendor="CrowdStrike, Inc." $CONTAINER
buildah config --label version=$VERSION $CONTAINER
buildah config --label release=$REL $CONTAINER
buildah config --label summary="CrowdStrike Falcon Sensor" $CONTAINER
buildah config --label description="The falcon-node-sensor container provides the Crowdstrike Falcon Sensor daemon and kernel modules." $CONTAINER

# Save the container to an image
buildah commit --squash $CONTAINER falcon-node-sensor

