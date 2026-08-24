{ pkgs, ... }:

# IST 256 (Programming for the Web) toolchain: HTML/CSS/JavaScript core,
# then APIs/AJAX and a Node + Mongo back end.
{
  home.packages = with pkgs; [
    # node ships npm + npx. Pinned to the major so a channel bump doesn't
    # silently move the course runtime mid-semester.
    nodejs_24

    # NOT `mongodb` — that attr builds the server from source via scons and
    # takes hours on this laptop. `mongodb-ce` fetches upstream's prebuilt
    # tarball from fastdl.mongodb.org and auto-patchelfs it. Both are SSPL
    # (unfree), so neither is on cache.nixos.org; only this one is cheap.
    mongodb-ce
    mongosh
    mongodb-tools

    # LSPs for the nvim setup: vscode-langservers-extracted covers
    # html/cssls/jsonls/eslint, ts_ls covers JavaScript.
    vscode-langservers-extracted
    typescript-language-server
    prettier

    # Poking JSON endpoints when the AJAX call is the thing that's broken.
    httpie
  ];
}
