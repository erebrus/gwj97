DIR=$(pwd)

mkdir -p $1
cd $1
mkdir godot
mkdir godot/assets
mkdir godot/assets/gfx
mkdir godot/assets/gfx/world
touch godot/assets/gfx/world/.keepme
mkdir godot/assets/gfx/player
touch godot/assets/gfx/player/.keepme
mkdir godot/assets/gfx/npcs
touch godot/assets/gfx/npcs/.keepme
mkdir godot/assets/gfx/ui
touch godot/assets/gfx/ui/.keepme
mkdir godot/assets/fonts
touch godot/assets/fonts/.keepme
mkdir godot/assets/sfx
touch godot/assets/sfx/.keepme
mkdir godot/assets/music
touch godot/assets/music/.keepme
mkdir godot/src/
mkdir godot/src/.keepme

mkdir itch
touch itch/.keepme

mkdir master
mkdir master/gfx
mkdir master/gfx/world
touch master/gfx/world/.keepme
mkdir master/gfx/player
touch master/gfx/player/.keepme
mkdir master/gfx/npcs
touch master/gfx/npcs/.keepme
mkdir master/gfx/ui
touch master/gfx/ui/.keepme
mkdir master/fonts
touch master/fonts/.keepme

mkdir -p build/win
mkdir -p build/mac
mkdir -p build/web
touch build/win/.keepme
touch build/mac/.keepme
touch build/web/.keepme

mkdir tools
cd $DIR
cp -r ../godot_helper $1/tools/
