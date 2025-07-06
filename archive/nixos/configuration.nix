{ config, pkgs, lib, ... }:
{
  nix.settings.experimental-features = ["nix-command" "flakes"];
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./flatpak.nix
  ];

services.pipewire = {
  enable = true;
  audio.enable = true;
  alsa.enable = true;
  pulse.enable = true;
  jack.enable = false; # Unless you're using pro audio tools
};
services.dbus.enable = true;
systemd.user.services.xdg-desktop-portal.enable = true;
systemd.user.services.xdg-desktop-portal-wlr.enable = true;

environment.variables = {
  XDG_CURRENT_DESKTOP = "river";
  XDG_SESSION_TYPE = "wayland";
  XDG_PORTAL_FORCE_BACKEND = "wlr";
};
  
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [

    #needed software
    linux-firmware
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    xdg-desktop-portal
    kdePackages.dolphin
    pipewire
    pulseaudio
    pavucontrol
    nwg-look

    #applications 
    vlc mpv
    firefox brave ungoogled-chromium
    git github-desktop git-lfs gh
    wezterm ghostty kitty
    vscodium openjdk21 openjdk17 gcc
    steam qbittorrent obsidian

    #cli stuff
    protonvpn-cli_2
    prismlauncher
    flatpak
    fastfetch stow zsh fzf fd zoxide killall tree 
    vim neovim nil
    btop 
    python312Packages.deemix

    #theming
    catppuccin catppuccin-sddm catppuccin-gtk nwg-look font-awesome

    #desktop environment
    river wlr-randr
    swaybg yambar hypridle hyprlock hyprshot
    dunst brightnessctl 
    rofi-wayland

    #Files
    nemo gvfs yazi baobab

    gnome-keyring seahorse

  ];


xdg.portal = {
  enable = true;
  config.common.default = "gtk";
  wlr.enable = true;
  extraPortals = with pkgs; [
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
  ];
};
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
    zsh.enable = true;
    river.enable = true;
    seahorse.enable = true;
  };

  services = {
    displayManager.sddm = {
      enable = true;
      theme = "catppuccin-mocha";
      package = pkgs.kdePackages.sddm; # Use the Qt6 version
      wayland.enable = true;
    };
    flatpak.enable = true;
    gnome.gnome-keyring.enable = true;
    udisks2.enable = true;

    xremap = {
      withHypr = true;
      userName = "miles";
      yamlConfig = ''
        modmap: 
          - name: main remaps
            remap:
              KEY_CAPSLOCK: KEY_ESC
              KEY_KPSLASH: KEY_PREVIOUSSONG
              KEY_KPASTERISK: KEY_PLAYPAUSE
              KEY_KPMINUS: KEY_NEXTSONG
      '';
    };
  };
  swapDevices = [{
    device = "/swapfile";
    size = 16 * 1024; # 16GB
  }];
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.miles = {
    isNormalUser = true;
    description = "miles";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  };

  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  # services.openssh.enable = true;
  # networking.firewall.allowedTCPPorts = [ 22 ];
  # networking.firewall.allowedUDPPorts = [ 22 ];
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  #boot.kernelParams = [ "pcie_aspm=off" ];



  networking.hostName = "nixos"; # Define your hostname.
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  
  #Locale stuff
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  system.stateVersion = "25.05"; # Did you read the comment?
}
