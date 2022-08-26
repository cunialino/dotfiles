#!/bin/bash

fontName="SourceCodePro"
fontDir="~/.local/share/fonts"

downloadFonts() {
	echo "[-] Download fonts [-]"
	echo "https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/$fontName.zip"
	wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/"$fontName".zip
	mkdir -p "$fontDir"
	unzip "$fontName".zip -d "$fontDir"
	fc-cache -fv
	rm "$fontName".zip
	echo "done!"
}

createLinks() {
	for f in .config/*; do
		[ -e "$HOME/$f" ] && rm "$HOME/$f"
		ln -s "$PWD/$f" "$HOME/$f"
	done
	for f in .*; do
		[ ! -d "$f" ] && ln -s "$PWD/$f" "$HOME/$f"
	done

}

createLinks
