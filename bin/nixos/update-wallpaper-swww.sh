#!/bin/bash

wallpapers_path=$XDG_CACHE_HOME/wallpapers
mkdir -p "$wallpapers_path"

wallpaper=$(find "$wallpapers_path" -type f | shuf -n 1)
echo $wallpaper
wallpaper_name=$(echo $wallpaper | sed "s|$wallpapers_path/||g")
echo $wallpaper_name

cp $wallpaper $XDG_CACHE_HOME/current_wallpaper.jpg

swww img $XDG_CACHE_HOME/current_wallpaper.jpg --transition-step 20 --transition-fps=20

sleep 1
notify-send "Colors and Wallpaper updated" "with image $wallpaper_name"

echo "DONE!"
