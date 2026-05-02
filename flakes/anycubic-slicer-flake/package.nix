{ lib, appimageTools, fetchurl }:

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

  extraInstallCommands = ''
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