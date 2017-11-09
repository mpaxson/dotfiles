sudo cp backgrounds/dark-mastersword.jpg /usr/share/dark-mastersword.jpg

cd arc-theme-master
./autogen.sh --prefix=/usr
sudo make install

cd ../arc-icon-theme-master
./autogen.sh --prefix=/usr
sudo make install

