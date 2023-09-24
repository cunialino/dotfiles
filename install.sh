d!/bin/bash

fontName="SourceCodePro"
fontDir="$HOME/.local/share/fonts"

downloadFonts() {
  echo "[-] Download fonts [-]"
  echo "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/$fontName.zip"
  wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/"$fontName".zip
  mkdir -p "$fontDir"
  unzip "$fontName".zip -d "$fontDir"
  fc-cache -fv
  rm "$fontName".zip
  echo "done!"
}

downloadFonts
#createLinks
