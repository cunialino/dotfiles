echo "[-] Download fonts [-]"
fontName="SourceCodePro"
fontDir="~/.local/share/fonts"
echo "https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/$fontName.zip"
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/$fontName.zip
mkdir -p "$fontDir"
unzip "$fontName".zip -d "$fontDir"
fc-cache -fv
echo "done!"
