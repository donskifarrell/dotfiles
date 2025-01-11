#!/bin/bash

wallpapers_path=$XDG_CACHE_HOME/wallpapers
mkdir -p "$wallpapers_path"
wget -q -O "$wallpapers_path/$(date +%Y:%m:%d-%T).jpg" https://source.unsplash.com/3840x2160/?city,abstract,ocean,space,fire,earth,landscape,architecture,forest,bright
