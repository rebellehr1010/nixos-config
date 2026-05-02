{
  lib,
  appimageTools,
  fetchurl,
  runtimeShell,
}:

let
  pname = "anycubic-slicer-next";
  version = "1.3.9.4";

  src = fetchurl {
    url = "https://github.com/thecalamityjoe87/anycubic-slicer-next-packages/releases/download/v${version}/AnycubicSlicer-${version}-x86_64.AppImage";
    hash = "sha256-4foQjgwnmx4S5LjfTulAb5jc3EqkBN/20/MrUtzZoHg=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };

in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs =
    pkgs: with pkgs; [
      stdenv.cc.cc.lib
      cairo
      dbus
      expat
      fontconfig
      gdk-pixbuf
      glib
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gtk3
      mesa
      libglvnd
      libsoup_3
      libx11
      pango
      wayland
      webkitgtk_4_1
      zlib
    ];

  extraInstallCommands = ''
        mv $out/bin/${pname} $out/bin/.${pname}-wrapped
        cat > $out/bin/${pname} <<'EOF'
    #!${runtimeShell}
    script_dir=''${BASH_SOURCE[0]%/*}
    if [ "$script_dir" = "''${BASH_SOURCE[0]}" ]; then
      script_dir=$PWD
    fi
    case "$script_dir" in
      /*) ;;
      *) script_dir="$PWD/$script_dir" ;;
    esac
    if [ -n "''${HOME:-}" ] && [ -d "''${HOME}" ]; then
      cd "''${HOME}"
    else
      cd /tmp
    fi
    exec "$script_dir/.${pname}-wrapped" "$@"
    EOF
        chmod 755 $out/bin/${pname}

        install -Dm444 ${appimageContents}/AnycubicSlicer.desktop \
          $out/share/applications/AnycubicSlicer.desktop
        install -Dm444 ${appimageContents}/share/icons/hicolor/256x256/apps/AnycubicSlicer.png \
          $out/share/icons/hicolor/256x256/apps/AnycubicSlicer.png
        install -Dm444 ${appimageContents}/AnycubicSlicer.svg \
          $out/share/icons/hicolor/scalable/apps/AnycubicSlicer.svg

        ln -s $out/bin/${pname} $out/bin/AnycubicSlicerNext
  '';

  meta = {
    description = "Anycubic Slicer Next packaged from the community AppImage release";
    homepage = "https://github.com/thecalamityjoe87/anycubic-slicer-next-packages";
    mainProgram = "AnycubicSlicerNext";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
