#!/bin/bash

VERSION=v3.1.1

fontName="SourceCodePro"
fontDir="$HOME/.local/share/fonts"

downloadFonts() {
  echo "[-] Download fonts [-]"
  echo "https://github.com/ryanoasis/nerd-fonts/releases/download/$VERSION/$fontName.zip"
  wget https://github.com/ryanoasis/nerd-fonts/releases/download/$VERSION/"$fontName".zip
  mkdir -p "$fontDir/$fontName"
  unzip "$fontName".zip -d "$fontDir/$fontName"
  fc-cache -fv
  rm "$fontName".zip
  echo "done!"
}

downloadFonts
#createLinks
