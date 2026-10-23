{
  # Start at login; pgrep avoids re-activating a running instance.
  launchd.user.agents.openwhispr = {
    script = ''
      if ! /usr/bin/pgrep -f "[O]penWhispr.app/Contents/MacOS/OpenWhispr" >/dev/null 2>&1; then
        /usr/bin/open -a /Applications/OpenWhispr.app
      fi
    '';
    serviceConfig.RunAtLoad = true;
  };
}
