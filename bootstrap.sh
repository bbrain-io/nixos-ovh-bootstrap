#!/bin/bash

BOOTSTRAP_USER=jscherrer
BOOTSTRAP_REPO="https://github.com/bbrain-io/nixos-ovh-bootstrap.git"
BOOTSTRAP_PATH=/tmp/nixos-ovh-bootstrap

error() {
    printf "%s\n" "$*" >&2
    exit 1
}

create_user() {
    useradd -m "$BOOTSTRAP_USER" -G sudo -s /bin/bash
    mkdir -p /home/$BOOTSTRAP_USER/.ssh
    curl -L https://github.com/joscherrer.keys >>/home/$BOOTSTRAP_USER/.ssh/authorized_keys
    echo "$BOOTSTRAP_USER    ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/$BOOTSTRAP_USER
}

create_user

apt install -y git sudo curl
git clone "$BOOTSTRAP_REPO" "$BOOTSTRAP_PATH"

sudo -u $BOOTSTRAP_USER bash -c 'sh <(curl -L https://nixos.org/nix/install) < /dev/null --daemon'
sudo -u $BOOTSTRAP_USER bash -i "$BOOTSTRAP_PATH/install_nix.sh"
