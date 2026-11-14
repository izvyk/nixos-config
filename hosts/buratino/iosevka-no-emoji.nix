# Iosevka without its black-and-white emoji.
#
# Iosevka draws ~70 characters that Unicode says should look like emoji by
# default (🙂 🙃 ⭐ ⚡ ❌ 🕐 …). Apps that use Iosevka as the main font (Zed,
# Ghostty) take the glyph from it and never reach the color emoji font. This
# drops those characters from the character map, so they fall back to
# "Apple Emoji". Text-style symbols (❤ © ™ ↔, digits) stay in Iosevka.
# The list comes from Unicode's emoji data (Emoji_Presentation=Yes).
{
  runCommand,
  python3,
  unicode-character-database,
}:

font:

runCommand "${font.name}-no-emoji"
  {
    nativeBuildInputs = [ (python3.withPackages (ps: [ ps.fonttools ])) ];
  }
  ''
    cp -r --no-preserve=mode ${font} $out
    cat > drop-emoji.py <<'EOF'
    import sys
    from fontTools.ttLib import TTCollection, TTFont

    emoji = set()
    for line in open(sys.argv[1]):
        line = line.split("#")[0].strip()
        if not line:
            continue
        codes, prop = (x.strip() for x in line.split(";"))
        if prop == "Emoji_Presentation":
            first, _, last = codes.partition("..")
            emoji.update(range(int(first, 16), int(last or first, 16) + 1))

    for path in sys.argv[2:]:
        collection = path.endswith(".ttc")
        container = TTCollection(path) if collection else TTFont(path)
        for font in container.fonts if collection else [container]:
            for table in font["cmap"].tables:
                if table.format != 14:
                    for code in emoji & table.cmap.keys():
                        del table.cmap[code]
        container.save(path)
    EOF
    find $out \( -name '*.ttc' -o -name '*.ttf' \) -print0 \
      | xargs -0 python3 drop-emoji.py ${unicode-character-database}/share/unicode/emoji/emoji-data.txt
  ''
