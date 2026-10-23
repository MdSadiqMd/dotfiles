# Rust comes from rustup. Rarely used tools: `nix shell nixpkgs#<pkg>`.
pkgs: with pkgs; {
  common = [
    vim
    neovim
    tmux
    git
    gh
    curl
    fd
    ast-grep
    watchexec
    nh
    nixfmt
    obsidian
    (if stdenv.isDarwin then ghostty-bin else ghostty)
    bun
    imagemagick # image.nvim renders through `magick`
    lua-language-server
    stylua

    go_1_24
    nodejs_20
    typescript
    yarn
    nodePackages.node2nix
    (python311.withPackages (ps: [
      ps.pip
      ps.virtualenv
    ]))
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
  ];

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
    solana-cli
    tree
    wl-clipboard # nvim/tmux clipboard (Wayland)
    xclip # nvim/tmux clipboard (X11)
    zoxide
    zsh # Ubuntu ships bash only; bootstrap makes this the login shell
  ];
}
