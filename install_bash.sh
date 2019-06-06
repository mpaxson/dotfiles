#!/bin/bash
sh install_prereq_ubuntu.sh
echo 'moving /etc/update-motd.d to /etc/update'
sudo mv /etc/update-motd.d /etc/update-motd.d.backup

echo 'copying motd/update-motd.d to /etc/update-motd.d'
sudo mkdir /etc/update-motd.d
sudo cp -r  motd/update-motd.d/* /etc/update-motd.d

echo 'moving ~/.bashrc to ~/.bashrc.backup\n...'
mv ~/.bashrc ~/.bashrc.backup

echo 'copying .bashrc to ~/.bashrc'
sudo cp .bashrc ~/.bashrc

echo 'backing up .vim_runime and .vimrc'
mv ~/.vim_runtime ~/.vim_runtime.backup
mv ~/.vimrc ~/.vimrc.backup
echo 'Copying .vim_runtime to ~/.vim_runtime'
cp -r vim/.vim_runtime ~/.vim_runtime
cp vim/.vimrc ~/.vimrc
python ~/.vim_runtime/update_plugins.py

echo 'copying tmux config and backing up ~/.tmux.conf'
mv ~/.tmux.conf ~/.tmux.conf.backup
cp .tmux.conf ~/.tmux.conf



sudo mv /usr/share/powerline/config_files /usr/share/powerline/config_files.backup
./fonts/install.sh
sudo cp -r powerline /usr/share/powerline/config_files

sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

cp oh_my-zsh/themes/* ~/.oh_my-zsh/themes/

echo "backing up zhsrc"
mv ~/.zshrc ~/.zshrc.backup

ln ./.zshrc ~/.zshrc

