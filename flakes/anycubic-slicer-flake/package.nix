{
  lib,
  stdenvNoCC,
  buildFHSEnv,
  dpkg,
  fetchurl,
  writeShellScript,
}:

let
  pname = "anycubic-slicer-next";
  version = "2.0.06";

  # Version from the vendor's Debian index. Its filename uses a different version.
  src = fetchurl {
    url = "https://cdn-universe-slicer.anycubic.com/prod/pool/main/a/anycubicslicernext/AnycubicSlicerNext_linux-v2.0.0.5-20260913065625.deb";
    hash = "sha256-/gh6VgFO0lzf5MPCk7UXra7gqbLh3tefXjlLeWiBfBU=";
  };

  payload = stdenvNoCC.mkDerivation {
    pname = "${pname}-payload";
    inherit version src;
    nativeBuildInputs = [ dpkg ];
    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x "$src" source
      runHook postUnpack
    '';
    dontBuild = true;
    # The unmodified binaries run inside the FHS environment below.
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib" "$out/share/licenses/${pname}"
      cp -r source/usr/bin source/usr/share "$out/"
      cp -P source/usr/lib/*.so* "$out/lib/"
      cp source/usr/LICENSE.txt "$out/share/licenses/${pname}/LICENSE.txt"
      runHook postInstall
    '';
  };
in
buildFHSEnv {
  inherit pname version;

  # The binary hardcodes /usr/share/AnycubicSlicerNext/resources and loads vendor
  # libraries from /usr/lib. buildFHSEnv supplies both without changing the host.
  targetPkgs =
    pkgs: with pkgs; [
      payload
      stdenv.cc.cc.lib
      cairo
      dbus
      expat
      fontconfig
      gdk-pixbuf
      glib
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-libav
      gtk3
      libglvnd
      libpsl
      libsoup_3
      libtiff
      libx11
      mesa
      pango
      webkitgtk_4_1
      zlib
    ];

  # Use this runtime's plugins even when the host exports its own plugin path.
  profile = ''
    export GST_PLUGIN_SYSTEM_PATH_1_0=/usr/lib/gstreamer-1.0
  '';

  # /etc/nixos, for example, is not visible inside the FHS environment. Avoid
  # failing before the launcher can choose an accessible working directory.
  chdirToPwd = false;
  extraPreBwrapCmds = ''
    export ANYCUBIC_SLICER_CWD="$PWD"
  '';
  runScript = writeShellScript "${pname}-launch" ''
    # Upstream creates its settings directory without creating this parent.
    if [ -n "''${HOME:-}" ] && [ -d "$HOME" ]; then
      mkdir -p "$HOME/.config"
    fi
    if [ -d "$ANYCUBIC_SLICER_CWD" ]; then
      cd "$ANYCUBIC_SLICER_CWD"
    elif [ -n "''${HOME:-}" ] && [ -d "$HOME" ]; then
      cd "$HOME"
    else
      cd /tmp
    fi
    unset ANYCUBIC_SLICER_CWD
    exec /usr/bin/AnycubicSlicerNext "$@"
  '';

  extraInstallCommands = ''
    ln -s "$out/bin/${pname}" "$out/bin/AnycubicSlicerNext"
    install -Dm444 ${payload}/share/applications/AnycubicSlicer.desktop \
      "$out/share/applications/AnycubicSlicer.desktop"
    substituteInPlace "$out/share/applications/AnycubicSlicer.desktop" \
      --replace-fail 'Exec=AnycubicSlicerNext %U' "Exec=$out/bin/AnycubicSlicerNext %U" \
      --replace-fail 'Icon=/usr/share/AnycubicSlicerNext/resources/images/AnycubicSlicer.png' 'Icon=AnycubicSlicer'
    install -Dm444 ${payload}/share/AnycubicSlicerNext/resources/images/AnycubicSlicer.png \
      "$out/share/pixmaps/AnycubicSlicer.png"
    install -Dm444 ${payload}/share/AnycubicSlicerNext/resources/images/AnycubicSlicer.svg \
      "$out/share/icons/hicolor/scalable/apps/AnycubicSlicer.svg"
  '';

  passthru = { inherit src payload; };

  meta = {
    description = "Anycubic Slicer Next packaged from the official Debian release";
    homepage = "https://github.com/ANYCUBIC-3D/AnycubicSlicerNext";
    mainProgram = "AnycubicSlicerNext";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
