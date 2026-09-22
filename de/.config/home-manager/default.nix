{ config, lib, pkgs, ... }:

{
  imports = [
  ./modules/cyber.nix
  ./modules/webdev.nix
  ./modules/virt.nix
  ];
}
