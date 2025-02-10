#! /usr/bin/env bash
# Usage: asecret export
#        asecret generate hashed-password SECRET_PATH
#        asecret generate password SECRET_PATH
#        asecret generate ssh-key-pair [--bits=BITS] [--type=TYPE] SECRET_PATH
#        asecret generate ssl-certificate CA_PATH CERT_PATH DOMAIN...

set -efou pipefail

eval "$(sed -rn '0,/^$/{ /#!/d; s/^# ?//p }' "$0" | docopts -h- : "$@")"

ASECRET_OUT=${ASECRET_OUT:-/var/src/secrets}
dry_run=$(test ! -z "${ASECRET_DRY_RUN-}" && echo true || echo false)

if test "$generate" = true; then
  if test "$hashed_password" = true; then
    if test "$dry_run" = false && ! pass show "$SECRET_PATH" &>/dev/null; then
      pwgen 24 1 | mkpasswd -s | pass insert -m "$SECRET_PATH" >/dev/null
    fi
    jq -n '"\($path)" | tojson' \
      --arg path "$ASECRET_OUT"/"$SECRET_PATH"
  elif test "$password" = true; then
    if test "$dry_run" = false && ! pass show "$SECRET_PATH" &>/dev/null; then
      pwgen 24 1 | pass insert -m "$SECRET_PATH" >/dev/null
    fi
    jq -n '"\($path)" | tojson' \
      --arg path "$ASECRET_OUT"/"$SECRET_PATH"
  elif test "$ssh_key_pair" = true; then
    if test "$dry_run" = false && ! pass show "$SECRET_PATH" &>/dev/null; then
      ( exec 3>&1 ; ssh-keygen"${bits:+ -b "$bits"}"${type:+ -t "$type"} -f /proc/self/fd/3 -N '' <<<y &>/dev/null || :) |
      pass insert -m "$SECRET_PATH" >/dev/null
    fi
    if test "$dry_run" = false && ! pass show "$SECRET_PATH".pub &>/dev/null; then
      pass show "$SECRET_PATH" | ssh-keygen -y -f /dev/stdin | pass insert -m "$SECRET_PATH".pub >/dev/null
    fi
    jq -n '$ARGS.named | tojson' \
      --arg privateKeyFile "$ASECRET_OUT"/"$SECRET_PATH" \
      --arg publicKeyFile "$ASECRET_OUT"/"$SECRET_PATH".pub
  elif test "$ssl_certificate" = true; then
    (
      set -efuo pipefail
      hasCA=$(pass show "$CA_PATH"/rootCA.pem &>/dev/null && echo true || echo false)
      hasDomain=$(pass show "$CERT_PATH".pem &>/dev/null && echo true || echo false)

      if test "$dry_run" = false && test "$hasDomain" = false; then
        readonly tmp=$(mktemp -d)
        trap 'rm -fr "$tmp"' EXIT

        umask 0277
        if test "$hasCA" = true; then
          pass show "$CA_PATH"/rootCA.pem > "$tmp"/rootCA.pem
          pass show "$CA_PATH"/rootCA-key.pem > "$tmp"/rootCA-key.pem
        fi

        CAROOT=$tmp mkcert -cert-file "$tmp"/"$(basename "$CERT_PATH")".pem -key-file "$tmp"/"$(basename "$CERT_PATH")"-key.pem "${DOMAIN[@]}" &>/dev/null

        umask 0022
        if test "$hasCA" = false; then
          cat "$tmp"/rootCA-key.pem | pass insert -m "$CA_PATH"/rootCA-key.pem >/dev/null
          cat "$tmp"/rootCA.pem | pass insert -m "$CA_PATH"/rootCA.pem >/dev/null
        fi

        cat "$tmp"/"$(basename "$CERT_PATH")"-key.pem | pass insert -m "$CERT_PATH"-key.pem >/dev/null
        cat "$tmp"/"$(basename "$CERT_PATH")".pem | pass insert -m "$CERT_PATH".pem >/dev/null
      fi
    )
    jq -n '$ARGS.named | tojson' \
      --arg certificateFile "$ASECRET_OUT"/"$CERT_PATH".pem \
      --arg certificateKeyFile "$ASECRET_OUT"/"$CERT_PATH"-key.pem
  fi
elif test "$export" = true; then
  readonly tmp=$(mktemp -d)
  trap 'rm -fr "$tmp"' EXIT

  umask 0077
  (
    cd $PASSWORD_STORE_DIR
    find . -type f
  ) | while read -r fn; do
    if test "$(basename "$fn")" = ".gpg-id"; then
      continue
    fi
    mkdir -p "$(dirname "$tmp"/"${fn%.gpg}")"
  done

  umask 0277
  (
    cd $PASSWORD_STORE_DIR
    find . -type f
  ) | while read -r fn; do
    if test "$(basename "$fn")" = ".gpg-id"; then
      continue
    fi
    pass show "${fn%.gpg}" > "$tmp"/"${fn%.gpg}"
  done

  if test "$dry_run" = true; then
    rsync -a "$tmp/"
  else
    mkdir -p "$ASECRET_OUT"
    rsync -a --delete-after "$tmp/" "$ASECRET_OUT"
  fi
fi
