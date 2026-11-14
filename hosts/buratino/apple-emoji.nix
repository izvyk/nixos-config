{
  lib,
  stdenvNoCC,
  fetchurl,
  python3,
}:

stdenvNoCC.mkDerivation rec {
  pname = "apple-emoji";
  version = "macos-26-20260722-484daf4e";

  src = fetchurl {
    url = "https://github.com/samuelngs/apple-emoji-linux/releases/download/${version}/AppleColorEmoji-Linux.ttf";
    hash = "sha256:e37c7af6265ac4a0af6d57bc65e86109a776d9966e8343334557f63da482516f";
  };

  dontUnpack = true;
  nativeBuildInputs = [
    (python3.withPackages (ps: [ ps.fonttools ]))
  ];

  buildPhase = ''
    runHook preBuild

    # 1. Extract the internal font name table to an XML file
    ttx -t name -o name.ttx $src

    # 2. Replace the internal name with your custom name
    sed -i 's/Apple Color Emoji/Apple Emoji/g' name.ttx

    # 3. Replace the PostScript name. Zed draws a font in color only if its
    #    PostScript name is exactly "NotoColorEmoji" (check_is_known_emoji_font
    #    in gpui_wgpu); anything else is drawn as outlines, and this font has
    #    none, so emoji came out blank. Apps match on the family name, so this
    #    doesn't make the font stand in for Noto anywhere else.
    sed -i 's/AppleColorEmoji/NotoColorEmoji/g' name.ttx

    # 4. Merge the patched XML back into a new TTF file
    ttx -m $src name.ttx -o AppleEmoji.ttf

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 AppleEmoji.ttf $out/share/fonts/truetype/AppleEmoji.ttf
    runHook postInstall
  '';

  meta = with lib; {
    description = "Apple Color Emoji font (renamed to Apple Emoji so bizarre sites like Reddit don't pick it up by directly matching the name)";
    homepage = "https://github.com/samuelngs/apple-emoji-linux";
    license = licenses.unfreeRedistributable;
    platforms = platforms.all;
  };
}
