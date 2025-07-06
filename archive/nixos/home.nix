#home.nix
{ config, pkgs, system, inputs, home-manager, ... }:

{
  home = {
  username = "miles";
  homeDirectory = "/home/miles";

  packages = with pkgs; [
    inputs.zen-browser.packages."${system}".default
    pkgs.bibata-cursors
  ];
  sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };
  };

  gtk = { 
    enable = true;
    theme = {
      name = "Catppuccin-Mocha-Mauve";
    };
    cursorTheme = {
      name = "Bibata-Mordern-Classic";
    };
    iconTheme = {
      name = "Papirus";
      package=pkgs.papirus-icon-theme;
    };
  };


  qt = {
    enable = true;
    style.name = "Catppuccin-Mocha-Mauve";
    style.package = pkgs.catppuccin-qt5ct;
  };
  programs = {
    git = { enable = true;
      userName = "alfordm999";
      userEmail = "alfordm999@gmail.com";
      includes = [ { path = "~/.gitconfig_local"; } ];
      lfs.enable = true;
    };

    vscode = { enable = true;
      package = pkgs.vscodium;
      profiles.default.extensions = with pkgs.vscode-extensions; [
        redhat.java
        vscjava.vscode-java-dependency
        vscjava.vscode-java-pack
        vscjava.vscode-java-debug
        vscjava.vscode-java-test
        vscjava.vscode-maven
        asvetliakov.vscode-neovim
      ];
    };

  };

  home.stateVersion = "25.05";
}
