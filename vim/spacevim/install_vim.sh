
mv ~/.cache/.vimfiles.backup
tar -xzf vimfiles.tar.gz -C ~/.cache/vimfiles
mv ~/.SpaceVim ~/SpaceVim.backup
mv ~/.SpaceVim.d ~/SpaceVim.d.backup 
tar -xzf SpaceVim-*.tar.gz -C ~/.SpaceVim/
bash install.sh
cp init.vim ~/SpaceVim.d/init.vim

