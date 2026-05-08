#!/bin/bash
# Copy files to their production locations.
sudo cp -v nvims /usr/local/bin/.
sudo chmod -v +x /usr/local/bin/nvims

# Create config directory and copy files there.
mkdir -p "$HOME"/.config/nvims
cp -v neovim_distros "$HOME"/.config/nvims/.
