#! /usr/bin/env bash
# Usage: asecret export
#        asecret generate hashed-password SECRET_PATH
#        asecret generate password SECRET_PATH
#        asecret generate ssh-key-pair [--bits=BITS] [--type=TYPE] SECRET_PATH
#        asecret generate ssl-certificate SECRET_PATH DOMAIN...
#        asecret generate wireguard SECRET_PATH

set -efou pipefail

if test "${ASECRET_DEBUG-}" != ""; then
  set -x
fi

eval "$(sed -rn '0,/^$/{ /#!/d; s/^# ?//p }' "$0" | docopts -h- : "$@")"

ASECRET_OUT=${ASECRET_OUT:-/var/src/secrets}
dry_run=$(test ! -z "${ASECRET_DRY_RUN-}" && echo true || echo false)

if test "$generate" = true; then
  if test "$hashed_password" = true; then
    if test "$dry_run" = false && ! test -f "$PASSWORD_STORE_DIR"/"$SECRET_PATH".gpg; then
      pwgen 24 1 | mkpasswd -s | pass insert -m "$SECRET_PATH" >/dev/null
    fi
    jq -n '"\($path)" | tojson' \
      --arg path "$ASECRET_OUT"/"$SECRET_PATH"
  elif test "$password" = true; then
    if test "$dry_run" = false && ! test -f "$PASSWORD_STORE_DIR"/"$SECRET_PATH".gpg; then
      pwgen 24 1 | pass insert -m "$SECRET_PATH" >/dev/null
    fi
    jq -n '"\($path)" | tojson' \
      --arg path "$ASECRET_OUT"/"$SECRET_PATH"
  elif test "$ssh_key_pair" = true; then
    if test "$dry_run" = false && ! test -f "$PASSWORD_STORE_DIR"/"$SECRET_PATH".gpg; then
      ( exec 3>&1 ; ssh-keygen"${bits:+ -b "$bits"}"${type:+ -t "$type"} -f /proc/self/fd/3 -N '' <<<y &>/dev/null || :) |
      pass insert -m "$SECRET_PATH" >/dev/null
    fi
    if test "$dry_run" = false && ! test -f "$PASSWORD_STORE_DIR"/"$SECRET_PATH".pub.gpg &>/dev/null; then
      pass show "$SECRET_PATH" | ssh-keygen -y -f /dev/stdin | pass insert -m "$SECRET_PATH".pub >/dev/null
    fi
    jq -n '$ARGS.named | tojson' \
      --arg privateKeyFile "$ASECRET_OUT"/"$SECRET_PATH" \
      --arg publicKey "$(pass show "$SECRET_PATH".pub)" \
      --arg publicKeyFile "$ASECRET_OUT"/"$SECRET_PATH".pub
  elif test "$ssl_certificate" = true; then
    (
      set -efuo pipefail
      hasCA=$(test -f "$PASSWORD_STORE_DIR"/"$SECRET_PATH"/rootCA.pem.gpg &>/dev/null && echo true || echo false)
      hasDomain=$(test -f "$PASSWORD_STORE_DIR"/"$SECRET_PATH"/"${DOMAIN[0]}".pem.gpg &>/dev/null && echo true || echo false)

      if test "$dry_run" = false && test "$hasDomain" = false; then
        readonly tmp=$(mktemp -d)
        trap 'rm -fr "$tmp"' EXIT

        umask 0277
        if test "$hasCA" = true; then
          pass show "$SECRET_PATH"/rootCA.pem > "$tmp"/rootCA.pem
          pass show "$SECRET_PATH"/rootCA-key.pem > "$tmp"/rootCA-key.pem
        fi

        CAROOT=$tmp mkcert -cert-file "$tmp"/"${DOMAIN[0]}".pem -key-file "$tmp"/"${DOMAIN[0]}"-key.pem "${DOMAIN[@]}" &>/dev/null

        umask 0022
        if test "$hasCA" = false; then
          cat "$tmp"/rootCA-key.pem | pass insert -m "$SECRET_PATH"/rootCA-key.pem >/dev/null
          cat "$tmp"/rootCA.pem | pass insert -m "$SECRET_PATH"/rootCA.pem >/dev/null
        fi

        cat "$tmp"/"${DOMAIN[0]}"-key.pem | pass insert -m "$SECRET_PATH"/"${DOMAIN[0]}"-key.pem >/dev/null
        cat "$tmp"/"${DOMAIN[0]}".pem | pass insert -m "$SECRET_PATH"/"${DOMAIN[0]}".pem >/dev/null
      fi
    )
    jq -n '$ARGS.named | tojson' \
      --arg certificate "$(pass show "$SECRET_PATH"/"${DOMAIN[0]}".pem)" \
      --arg certificateFile "$ASECRET_OUT"/"$SECRET_PATH"/"${DOMAIN[0]}".pem \
      --arg certificateKeyFile "$ASECRET_OUT"/"$SECRET_PATH"/"${DOMAIN[0]}"-key.pem \
      --argjson root "$(
          jq -n '$ARGS.named' \
            --arg certificate "$(pass show "$SECRET_PATH"/rootCA.pem)" \
            --arg certificateFile "$ASECRET_OUT"/"$SECRET_PATH"/rootCA.pem \
            --arg certificateKeyFile "$ASECRET_OUT"/"$SECRET_PATH"/rootCA-key.pem
          )"
  elif test "$wireguard" = true; then
    if test "$dry_run" = false && ! test -f "$PASSWORD_STORE_DIR"/"$SECRET_PATH".gpg; then
      wg genkey | pass insert -m "$SECRET_PATH" >/dev/null
    fi
    if test "$dry_run" = false && ! test -f "$PASSWORD_STORE_DIR"/"$SECRET_PATH".pub.gpg &>/dev/null; then
      pass show "$SECRET_PATH" | wg pubkey | pass insert -m "$SECRET_PATH".pub >/dev/null
    fi
    jq -n '$ARGS.named | tojson' \
      --arg privateKeyFile "$ASECRET_OUT"/"$SECRET_PATH" \
      --arg publicKey "$(pass show "$SECRET_PATH".pub)" \
      --arg publicKeyFile "$ASECRET_OUT"/"$SECRET_PATH".pub
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
    rsync --archive --chown=root:root "$tmp/"
  else
    rsync --archive --chown=root:root --mkpath --delete-after "$tmp/" "$ASECRET_OUT"
  fi
fi
