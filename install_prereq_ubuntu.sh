sudo apt-get install fortune cowsay powerline thefuck python python-pip python-dev build-essential autoconf libgtk-3-dev gnome-tweak-tool tmux -y



sudo apt-get install guake git exfat-fuse vim-gnome xclip python-pigments -y


sudo apt install zsh

python -m pip install -r python_requirements.txt
python3 -m pip install -r python3_requirements.txt

mkdir ~/git_repos
cd ~/git_repos
git clone https://github.com/powerline/fonts.git #Paste this address in your browser to go to repo.
cd fonts && sh ./install.sh #See stuff below about this file
