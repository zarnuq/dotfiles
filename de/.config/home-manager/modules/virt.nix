{ pkgs, ... }:

# Then virt-manager (below) connects to qemu:///system out of the box.

{
  home.packages = with pkgs; [
    virt-manager   # libvirt GUI (connects to system libvirtd via qemu:///system)
    virt-viewer    # SPICE/VNC console viewer (virt-viewer / remote-viewer)
    spice-gtk      # SPICE client libs for clipboard/USB redirection in the console
  ];
}
