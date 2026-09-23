#!/usr/bin/env bash
# Mirrors the deck system's source into mod/ for versioning.
#
# This repository is about one thing: how a deck of cards was built on top of Baldur's Gate 3. So it
# tracks the Lua that runs the deck, the Khonsu conditions the boosts ask questions with, and the
# engine-side data those boosts and costs live in -- and nothing else. The class's own content
# (summon templates, Osiris goals, localisation, icons, VFX) is not part of that story and stays out.
#
# The copy is one-way and the game directory always wins: never edit anything under mod/ and expect
# it to reach the game.
#
#   tools/sync-mod.sh
#
# Reading the game directory is safe at any time; only writing to it needs the game and the Toolkit
# closed.

set -euo pipefail

MOD="AspectClass_9d734fbd-cb67-95c0-e2c9-46f05fe2f8a7"
GAME="${BG3_DATA:-/c/Program Files (x86)/Steam/steamapps/common/Baldurs Gate 3/Data}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$HERE/mod"

[ -d "$GAME/Mods/$MOD" ] || { echo "nao achei o mod em $GAME -- defina BG3_DATA" >&2; exit 1; }

copy() {  # copy <origem relativa a Data> <destino relativo a mod/>
    local src="$GAME/$1" dst="$DEST/$2"
    [ -e "$src" ] || { echo "  faltando: $1" >&2; return 0; }
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
}

rm -rf "$DEST"

# o deck, em Lua -- edicao PC
copy "Mods/$MOD/ScriptExtender/Lua"                     "ScriptExtender/Lua"
# condicoes Khonsu usadas pelos boosts
copy "Mods/$MOD/Scripts"                                "Scripts"

# lado do motor: os recursos, o status que converte o custo, os custos das cartas
copy "Public/$MOD/Stats"                                "Public/Stats"
copy "Public/$MOD/ActionResourceDefinitions"            "Public/ActionResourceDefinitions"
# o grupo e quem os 255 custos das cartas nomeiam -- sem ele nada e conjuravel
copy "Public/$MOD/ActionResourceGroupDefinitions"       "Public/ActionResourceGroupDefinitions"
copy "Public/$MOD/Lists"                                "Public/Lists"
copy "Public/$MOD/Progressions"                         "Public/Progressions"

# os mesmos dados do lado do Toolkit: tem de bater com os de cima, sempre
copy "Editor/Mods/$MOD/Stats"                           "Editor/Stats"
copy "Editor/Mods/$MOD/ActionResourceDefinitions"       "Editor/ActionResourceDefinitions"
copy "Editor/Mods/$MOD/ActionResourceGroupDefinitions"  "Editor/ActionResourceGroupDefinitions"
copy "Editor/Mods/$MOD/Lists"                           "Editor/Lists"
copy "Editor/Mods/$MOD/Progressions"                    "Editor/Progressions"

# o ScriptExtender e um repositorio proprio la na pasta do jogo
rm -rf "$DEST/ScriptExtender/.git"
find "$DEST" -name '*.bak*' -delete

echo "espelhado em mod/  ($(find "$DEST" -type f | wc -l) arquivos, $(du -sh "$DEST" | cut -f1))"
