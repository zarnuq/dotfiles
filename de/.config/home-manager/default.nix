{ config, lib, pkgs, ... }:

{
  imports = [
  ./modules/cyber.nix
  ./modules/virt.nix
  ];
}
