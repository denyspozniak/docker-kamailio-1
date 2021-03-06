#!/bin/bash -l

set -e

# Use local cache proxy if it can be reached, else nothing.
eval $(detect-proxy enable)

build::user::create $USER


log::m-info "Installing curl ..."
apt-get update -qq
apt-get install -yqq ca-certificates curl jq

RELEASE_DATA=$(curl -sSL https://api.github.com/repos/telephoneorg/kamailio-builder/releases/latest)
RELEASE_TAG=$(jq -r '.tag_name' <(echo $RELEASE_DATA))
RELEASE_DATE=$(jq -r '.published_at' <(echo $RELEASE_DATA))
RELEASE_DOWNLOAD_URL=https://github.com/telephoneorg/kamailio-builder/releases/download/$RELEASE_TAG/kamailio-debs-all.tar.gz


log::m-info "Downloading $APP Release ..."
echo -e "  branch: 	  $RELEASE_TAG
  published:  $RELEASE_DATE
  from: 	  $RELEASE_DOWNLOAD_URL
"

mkdir /tmp/kamailio
pushd $_
	curl -sSL $RELEASE_DOWNLOAD_URL | tar xzf - -C .
	apt install -y ./kamailio_*.deb
    for mod in ${KAMAILIO_INSTALL_MODS//,/ }; do
        apt install -y ./kamailio-${mod}-modules*.deb
    done

    rm -rf /etc/kamailio/*
    dpkg -i --force-overwrite kamailio-kazoo-configs*.deb
    dpkg -i kamailio-dbkazoo-modules*.deb

    popd && rm -rf $OLDPWD


# fixes
sed -i '/cseq_offset/s/^/# /' /etc/kamailio/presence-role.cfg


log::m-info "Removing curl ..."
apt-get purge -y --auto-remove curl


# needed by kamctl monitor
apt-get install -yqq ncurses-bin bsdmainutils


log::m-info "Creating directories and links ..."
rm -rf /etc/kamailio/{certs,db}
mkdir -p /volumes/$APP/{tls,db}
ln -s /volumes/$APP/tls /etc/kamailio/certs
ln -s /volumes/$APP/db /etc/kamailio/db


log::m-info "Adding fixattr files ..."
tee /etc/fixattrs.d/20-${APP}-perms <<EOF
/volumes/$APP/db true $USER:$USER 0755 0755
/volumes/$APP/tls true $USER:$USER 0700 0700
/var/run/$APP true $USER:$USER 0755 0755
EOF


log::m-info "Setting Ownership & Permissions ..."
chown -R $USER:$USER ~ /etc/kamailio /volumes/$APP


log::m-info "Cleaning up ..."
apt-clean --aggressive

# if applicable, clean up after detect-proxy enable
eval $(detect-proxy disable)

rm -r -- "$0"
