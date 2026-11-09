# Hardening macOS leaves off by default.
{
  # Signed apps keep their current auto-allow; unsigned listeners (nix node,
  # python dev servers) prompt before taking outside connections. Loopback is unaffected.
  networking.applicationFirewall = {
    enable = true;
    # No replies to pings or probes of closed ports.
    enableStealthMode = true;
  };

  # "Install Security Responses and system files": Rapid Security Responses plus
  # XProtect/Gatekeeper data. Full macOS updates stay manual since they reboot.
  system.defaults.CustomSystemPreferences."/Library/Preferences/com.apple.SoftwareUpdate" = {
    AutomaticCheckEnabled = true;
    CriticalUpdateInstall = true;
    ConfigDataInstall = true;
  };

  # Touch ID for sudo; reattach makes it work inside tmux.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };
}
