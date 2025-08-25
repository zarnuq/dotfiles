!#/bin/sh
export WINEPREFIX=~/.steam/steam/steamapps/compatdata/960090/pfx
winetricks dotnet6
# then copy MelonLoader files from the zip into ~/.steam/steam/steamapps/common/BloonsTD6 in same folder make a "Mods" folder then add Btd6ModHelper.dll
# in steam launch option "WINEDLLOVERRIDES="version=n,b" %command%"
