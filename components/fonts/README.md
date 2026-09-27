# Caption font

`Caption-Regular.ttf` is a renamed, merged derivative of Noto Sans Regular (Latin/punctuation) and Noto Naskh Arabic Regular (Persian/Arabic). Both upstream fonts are licensed under the SIL Open Font License 1.1; see `OFL.txt`. Internal family name: **30nama Caption**.

Sources: `https://github.com/notofonts/noto-fonts/tree/main/hinted/ttf/NotoSans` and `https://github.com/notofonts/noto-fonts/tree/main/hinted/ttf/NotoNaskhArabic`.

Built using `fontTools.merge.Merger().merge([latin_path, arabic_path])`, with family/full/PostScript/typographic names changed to 30nama Caption. Keep the upstream copyright/license records. The merge is necessary because the Arabic-only font does not include Latin letters or parentheses.

Arabic presentation forms are selected at runtime from Unicode compatibility decompositions; the app renders shaped RTL runs and preserves LTR numbers/Latin runs. This is a caption-focused implementation, not a claim to implement every Unicode bidirectional control sequence.
