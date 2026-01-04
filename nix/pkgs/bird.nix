{ lib, stdenv, fetchurl }:

stdenv.mkDerivation {
  pname = "bird";
  version = "0.5.1";

  src = fetchurl {
    url = "https://github.com/steipete/bird/releases/download/v0.5.1/bird-macos-universal-v0.5.1.tar.gz";
    hash = "sha256-fpWxvUG8nZu9VYSNvkzZ5y5nlLZK6O97a5UWDPgNkj0=";
  };

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    tar -xzf "$src"
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    cp bird "$out/bin/bird"
    chmod 0755 "$out/bin/bird"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Fast X CLI for tweeting, replying, and reading";
    homepage = "https://github.com/steipete/bird";
    license = licenses.mit;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "bird";
  };
}
