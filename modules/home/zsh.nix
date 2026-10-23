{ pkgs, ... }:
{
  # Plugin paths for config/zsh/.zshrc, pinned by flake.lock (no plugin manager,
  # no runtime git clones). .zshrc decides the load order.
  xdg.dataFile."zsh/plugins.zsh".text = ''
    typeset -gA zplugin=(
      p10k ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      completions ${pkgs.zsh-completions}/share/zsh/site-functions
      fzf-tab ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
      autosuggestions ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
      highlighting ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    )
  '';
}
