#!/bin/bash -x
thisdir=$PWD
echo "this is primarily to install on a computer that is not online\n"
echo "This dir is $thisdir"
cd /home/`whoami`/.cache
tar -czf vimfiles.tar.gz vimfiles/
mv vimfiles.tar.gz $thisdir
#go in home dir
echo "CD to $HOME "

cd $HOME
echo "$PWD"
tar -czvf .SpaceVim.tar.gz .SpaceVim/
mv .SpaceVim.tar.gz $thisdir
tar -czvf .SpaceVim.d.tar.gz .SpaceVim.d/
mv .SpaceVim.d.tar.gz $thisdir
cd $thisdir
cp ~/.SpaceVim.d/init.vim init.vim


