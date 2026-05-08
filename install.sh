#!/bin/bash

# Clone to /tmp and run from there.
git clone https://github.com/JustAHobbyDev/nvims /tmp/JustAHobbyDev/nvims
cd /tmp/JustAHobbyDev/nvims

# Copy files to their production locationg
sudo cp -v nvims /usr/local/bin/.
sudo chmod -v +x /usr/local/bin/nvims

# Create config directory and copy files there.
mkdir -p "$HOME"/.config/nvims
cp -v neovim_distros "$HOME"/.config/nvims/.

# Cleanup temporary directory.
rm -rfv /tmp/JustAHobbyDev

echo "Installation complete."
echo "Add /usr/local/bin to your PATH if it's not already."
