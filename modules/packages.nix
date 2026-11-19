# Rust comes from rustup. Rarely used tools: `nix shell nixpkgs#<pkg>`.
pkgs:
with pkgs;
let
  # ponytail: agents/tools/bun.lock is lockfileVersion 2 (bun >= 1.4), and nixos-26.05
  # ships bun 1.3.13, which cannot read it. Prebuilt binaries, so no rebuild cost.
  # Drop once nixpkgs has bun >= 1.4.
  bun' = bun.overrideAttrs (
    finalAttrs: old: {
      version = "1.4.4";
      # src follows passthru.sources below, so the version check is a false alarm.
      __intentionallyOverridingVersion = true;
      passthru = old.passthru // {
        sources =
          lib.mapAttrs
            (
              system:
              { name, hash }:
              fetchurl {
                url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-${name}.zip";
                inherit hash;
              }
            )
            {
              aarch64-darwin = {
                name = "darwin-aarch64";
                hash = "sha256-wkDX8My5DCY6hJ/NsJt+5iYw2SE0jtaq/ahrnVd7xRA=";
              };
              x86_64-darwin = {
                name = "darwin-x64-baseline";
                hash = "sha256-1KFVrfv9CRVes7oFyeOlRPOSl9emhhbTx3WfZ6tcR9w=";
              };
              aarch64-linux = {
                name = "linux-aarch64";
                hash = "sha256-uqa7NvUdblhWHgK76oJQOKnfRU9nPW13bou/hvjHhQ4=";
              };
              x86_64-linux = {
                name = "linux-x64";
                hash = "sha256-v4zL+ysLgBWeD5ptFcVTF63YB3U028YTCj7bUvzLOVw=";
              };
            };
      };
    }
  );
in
{
  bun = bun';

  common = [
    vim
    neovim
    tmux
    git
    gh
    curl
    fd
    ripgrep
    shellcheck
    poppler-utils
    ast-grep
    watchexec
    nh
    nixfmt
    obsidian
    # hiPrio on Linux: ncurses ships its own share/terminfo/g/ghostty, which collides
    # in home-manager's profile; ghostty's matches the installed version.
    (if stdenv.isDarwin then ghostty-bin else lib.hiPrio ghostty)
    bun'
    imagemagick # image.nvim renders through `magick`
    # LaTeX for Manim's Tex/MathTex (manim-explainer skill): the default template plus what TinyTeX had.
    (texliveSmall.withPackages (
      ps: with ps; [
        standalone
        preview
        doublestroke
        relsize
        physics
        rsfs
        wasysym
        everysel
        setspace
        ragged2e
        calligra
        dvisvgm
        cm-super
        tipa
        microtype
        babel-english
        amsfonts
      ]
    ))
    lua-language-server
    stylua

    go_1_26
    nodejs_22
    typescript
    yarn
    pnpm_10 # pinned to 10: repos' node_modules are pnpm 10 layouts; pnpm 11 reinstalls them
    (python311.withPackages (ps: [
      ps.pip
      ps.virtualenv
    ]))
    uv
    rustup
    wasm-pack
    wasm-bindgen-cli
    binaryen
    anchor
    # elixir is built against beam27; one Erlang for both.
    beam27Packages.erlang
    beam27Packages.elixir
    beam27Packages.rebar3
    beam27Packages.hex

    clang
    pkg-config
    openssl
    libiconv
    libyaml
    ncurses
    perl
    protobuf
    postgresql_17
  ]
  # GNU timeout alone: agents wrap commands in it, and full coreutils would shadow BSD ls/sed/date.
  ++ lib.optional stdenv.isDarwin (
    runCommand "timeout" { } "mkdir -p $out/bin && ln -s ${coreutils}/bin/timeout $out/bin/timeout"
  );

  # Homebrew provides these on macOS (modules/darwin/homebrew.nix).
  linux = [
    backblaze-b2
    ffmpeg
    fzf
    gnumake
    gnupg
    pinentry-curses
    htop
    just
    kind
    kubectl
    kubeshark
    # ponytail: solana-cli 3.0.12 fails on nixos-26.05's rustc (solana-core denies
    # warnings and the newer compiler flags an unneeded `unsafe`); not on the binary
    # cache either way, so this costs no cache hits. Drop once nixpkgs builds it.
    (solana-cli.overrideAttrs (o: {
      env = o.env // {
        RUSTFLAGS = "${o.env.RUSTFLAGS} --cap-lints warn";
      };
    }))
    tree
    wl-clipboard # nvim/tmux clipboard (Wayland)
    xclip # nvim/tmux clipboard (X11)
    zoxide
    zsh # Ubuntu ships bash only; bootstrap makes this the login shell
  ];
}
