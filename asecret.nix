{ coreutils
, docopts
, findutils
, gnused
, jq
, lib
, makeWrapper
, mkcert
, mkpasswd
, openssh
, pass
, pwgen
, rsync
, stdenv
, wireguard-tools
}:
stdenv.mkDerivation {
  name = "asecret";
  src = lib.cleanSource ./.;
  buildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin
    install src/asecret.sh $out/bin/asecret
    wrapProgram $out/bin/asecret \
      --inherit-argv0 \
      --set PATH ${lib.makeBinPath [
        coreutils
        docopts
        findutils
        gnused
        jq
        mkcert
        mkpasswd
        openssh
        pass
        pwgen
        rsync
        wireguard-tools
      ]}
  '';
}
