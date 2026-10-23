{
  config,
  lib,
  vars,
  ...
}:
let
  # Out-of-store links stay writable, so tools that edit their own config write
  # back into the repo. force: replace whatever an installer left at the target.
  link = path: {
    source = config.lib.file.mkOutOfStoreSymlink "${vars.repoDir}/${path}";
    force = true;
  };
  linkEach =
    target: src: names:
    lib.listToAttrs (map (n: lib.nameValuePair "${target}/${n}" (link "${src}/${n}")) names);
in
{
  home.file = {
    ".zshrc" = link "config/zsh/.zshrc";
    ".zshenv" = link "config/zsh/.zshenv";
    ".zprofile" = link "config/zsh/.zprofile";
    ".p10k.zsh" = link "config/zsh/.p10k.zsh";
    ".gitconfig" = link "config/git/config";
    ".gitconfig-work" = link "config/git/config-work";
    ".config/git/ignore" = link "config/git/ignore";
    # Whole folder: htop saves htoprc by swapping in a new file.
    ".config/htop" = link "config/htop";
    ".config/tmux" = link "config/tmux";
    ".config/ghostty" = link "config/ghostty";
    ".config/nvim" = link "config/nvim";
    ".config/zed/settings.json" = link "config/zed/settings.json";
    ".config/herdr/config.toml" = link "config/herdr/config.toml";

    # T3 Code runs the claude and opencode CLIs, so it gets these too.
    ".agents" = link "agents";
    ".claude/skills" = link "agents/skills";
    ".pi" = link "agents/pi";
    # Whole folder: OpenCode saves files by swapping in new copies, which would
    # replace per-file symlinks; inside a linked folder the swap lands in the repo.
    ".config/opencode" = link "agents/opencode";
  }
  // linkEach ".claude" "agents" [
    "CLAUDE.md"
    "RTK.md"
  ]
  // linkEach ".claude" "agents/claude" [
    "settings.json"
    "commands"
    "hooks"
  ]
  // linkEach ".omp/agent" "agents/omp" [
    "config.yml"
    "extensions"
  ]
  // lib.optionalAttrs vars.isDarwin {
    ".hammerspoon/init.lua" = link "config/hammerspoon/init.lua";
    ".zsh_sessions" = link "config/zsh/sessions";
  };
}
