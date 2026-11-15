# /etc/zsh/zprofile sources /etc/profile.env, which resets PATH to the
# baselayout default and drops nix/home-manager. This runs after it, so put
# them back in front for login shells.
path=($HOME/.nix-profile/bin /nix/var/nix/profiles/default/bin $HOME/.local/bin $path)
typeset -U path
