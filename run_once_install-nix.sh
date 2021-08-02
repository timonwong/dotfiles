#!/usr/bin/env bash

set -eu -o pipefail

if [[ ! -d /nix/store ]]; then
    {{ if eq .chezmoi.os "darwin" -}}
    sh <(curl -L https://nixos.org/nix/install) --darwin-use-unencrypted-nix-store-volume
    {{ else -}}
    sh <(curl -L https://nixos.org/nix/install)
    {{ end }}
fi

# if [[ ! -e ~/.nix-profile/bin/home-manager ]]; then
#     . ~/.nix-profile/etc/profile.d/nix.sh;
#     nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
#     nix-channel --update
#     nix-shell '<home-manager>' -A install
# fi
