{
  lib,
  pkgs,
  vars,
  ...
}:
let
  # Scheduled and background jobs, defined once for launchd (macOS) and systemd (Linux).
  #   script:    path in this repo, or command: a shell command line
  #   at:        daily { hour, minute }; missed runs happen on wake/boot
  #   keepAlive: a long-running service, restarted if it exits
  #   darwinOnly
  #   enable:    false keeps the job defined but never installs it
  # Output goes to ~/.local/state/jobs/<name>.log.

  # macOS hands the default input to Bluetooth headphones or earbuds after a call,
  # which opens their hands-free mic and drops all Mac output to 16 kHz mono. This
  # keeps the preferred non-Bluetooth mic selected instead and, once the mic is
  # released, renegotiates an output stuck on the HFP profile. It listens for
  # default-input changes rather than polling, so it costs nothing while idle, and
  # the rule is transport-based, so it covers every Bluetooth device. The launchd
  # agent uses RunAtLoad/KeepAlive, so it survives reboots, logins, crashes and
  # coreaudiod restarts.
  audio-input-guard-src = pkgs.writeText "audio-input-guard.c" ''
    #include <CoreAudio/CoreAudio.h>
    #include <CoreFoundation/CoreFoundation.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    static AudioObjectPropertyAddress prop(AudioObjectPropertySelector selector, AudioObjectPropertyScope scope) {
      AudioObjectPropertyAddress address = { selector, scope, kAudioObjectPropertyElementMain };
      return address;
    }

    static int channelCount(AudioDeviceID device, AudioObjectPropertyScope scope) {
      AudioObjectPropertyAddress address = prop(kAudioDevicePropertyStreamConfiguration, scope);
      UInt32 size = 0;
      if (AudioObjectGetPropertyDataSize(device, &address, 0, NULL, &size) != noErr || size == 0) return 0;
      AudioBufferList *buffers = malloc(size);
      if (buffers == NULL) return 0;
      int total = 0;
      if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size, buffers) == noErr) {
        for (UInt32 i = 0; i < buffers->mNumberBuffers; i++) total += (int)buffers->mBuffers[i].mNumberChannels;
      }
      free(buffers);
      return total;
    }

    static UInt32 transportType(AudioDeviceID device) {
      UInt32 transport = 0, size = sizeof(transport);
      AudioObjectPropertyAddress address = prop(kAudioDevicePropertyTransportType, kAudioObjectPropertyScopeGlobal);
      if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size, &transport) != noErr) return 0;
      return transport;
    }

    static int isBluetooth(AudioDeviceID device) {
      UInt32 transport = transportType(device);
      return transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE;
    }

    // Built-in first, then any other non-Bluetooth device. This keeps the guard
    // working on Macs without a built-in mic or speakers, and never routes back
    // to the Bluetooth device that caused the problem.
    static AudioDeviceID preferredDevice(AudioObjectPropertyScope scope) {
      AudioObjectPropertyAddress address = prop(kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal);
      UInt32 size = 0;
      if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &address, 0, NULL, &size) != noErr) return 0;
      AudioDeviceID *devices = malloc(size);
      if (devices == NULL) return 0;
      AudioDeviceID found = 0;
      if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, devices) == noErr) {
        for (UInt32 i = 0; i < size / sizeof(AudioDeviceID); i++) {
          if (channelCount(devices[i], scope) == 0 || isBluetooth(devices[i])) continue;
          UInt32 transport = transportType(devices[i]);
          if (transport == kAudioDeviceTransportTypeAggregate) continue;
          if (transport == kAudioDeviceTransportTypeBuiltIn) {
            found = devices[i];
            break;
          }
          if (found == 0) found = devices[i];
        }
      }
      free(devices);
      return found;
    }

    static AudioDeviceID preferredInput(void) { return preferredDevice(kAudioObjectPropertyScopeInput); }
    static AudioDeviceID preferredOutput(void) { return preferredDevice(kAudioObjectPropertyScopeOutput); }

    static AudioDeviceID defaultInput(void) {
      AudioDeviceID device = 0;
      UInt32 size = sizeof(device);
      AudioObjectPropertyAddress address = prop(kAudioHardwarePropertyDefaultInputDevice, kAudioObjectPropertyScopeGlobal);
      AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, &device);
      return device;
    }

    static void setDefaultInput(AudioDeviceID device) {
      AudioObjectPropertyAddress address = prop(kAudioHardwarePropertyDefaultInputDevice, kAudioObjectPropertyScopeGlobal);
      AudioObjectSetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, sizeof(device), &device);
    }

    static AudioDeviceID defaultOutput(void) {
      AudioDeviceID device = 0;
      UInt32 size = sizeof(device);
      AudioObjectPropertyAddress address = prop(kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal);
      AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, &device);
      return device;
    }

    static void setDefaultOutput(AudioDeviceID device) {
      AudioObjectPropertyAddress address = prop(kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal);
      AudioObjectSetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, sizeof(device), &device);
    }

    static double nominalSampleRate(AudioDeviceID device) {
      Float64 rate = 0;
      UInt32 size = sizeof(rate);
      AudioObjectPropertyAddress address = prop(kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal);
      if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size, &rate) != noErr) return 0;
      return rate;
    }

    static int deviceName(AudioDeviceID device, char *text, size_t size) {
      CFStringRef name = NULL;
      UInt32 nameSize = sizeof(name);
      AudioObjectPropertyAddress address = prop(kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal);
      if (AudioObjectGetPropertyData(device, &address, 0, NULL, &nameSize, &name) != noErr || name == NULL) return 0;
      Boolean converted = CFStringGetCString(name, text, size, kCFStringEncodingUTF8);
      CFRelease(name);
      return converted ? 1 : 0;
    }

    static int nameIs(AudioDeviceID device, const char *name) {
      char current[256] = { 0 };
      if (!deviceName(device, current, sizeof(current))) return 0;
      return strcmp(current, name) == 0;
    }

    static AudioDeviceID deviceByName(const char *name, AudioObjectPropertyScope scope) {
      AudioObjectPropertyAddress address = prop(kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal);
      UInt32 size = 0;
      if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &address, 0, NULL, &size) != noErr) return 0;
      AudioDeviceID *devices = malloc(size);
      if (devices == NULL) return 0;
      AudioDeviceID found = 0;
      if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, devices) == noErr) {
        for (UInt32 i = 0; i < size / sizeof(AudioDeviceID) && found == 0; i++) {
          if (channelCount(devices[i], scope) > 0 && nameIs(devices[i], name)) found = devices[i];
        }
      }
      free(devices);
      return found;
    }

    // HFP presents a headset as separate input and output endpoints with one name.
    // Lookups by name keep working when an HFP transition or coreaudiod restart
    // re-enumerates devices with new numeric IDs.
    static AudioDeviceID sibling(AudioDeviceID device, AudioObjectPropertyScope scope) {
      if (channelCount(device, scope) > 0) return device;
      char name[256] = { 0 };
      if (!deviceName(device, name, sizeof(name))) return 0;
      return deviceByName(name, scope);
    }

    static int isRunningSomewhere(AudioDeviceID device) {
      UInt32 running = 0, size = sizeof(running);
      AudioObjectPropertyAddress address = prop(kAudioDevicePropertyDeviceIsRunningSomewhere, kAudioObjectPropertyScopeGlobal);
      if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size, &running) != noErr) return 0;
      return running != 0;
    }

    // Policy seam: a device needs protecting when it is a Bluetooth microphone
    // that shares its transport with an output endpoint. Add transports here.
    static int needsProtection(AudioDeviceID input) {
      if (input == 0 || !isBluetooth(input)) return 0;
      return sibling(input, kAudioObjectPropertyScopeOutput) != 0;
    }

    static char g_headsetName[256] = { 0 };
    static char g_speakerName[256] = { 0 };
    static int g_bouncePending = 0;
    static CFAbsoluteTime g_lastBounce = 0;

    static int isDefaultOutput(const char *name) {
      AudioDeviceID current = defaultOutput();
      return current != 0 && nameIs(current, name);
    }

    static void restoreOutput(CFRunLoopTimerRef timer, void *info) {
      if (g_bouncePending && isDefaultOutput(g_speakerName)) {
        AudioDeviceID headset = deviceByName(g_headsetName, kAudioObjectPropertyScopeOutput);
        if (headset != 0) setDefaultOutput(headset);
      }
      g_bouncePending = 0;
      g_headsetName[0] = g_speakerName[0] = '\0';
    }

    // Some earbuds keep the 16 kHz mono HFP endpoint after their mic is released.
    // Reselecting the output forces A2DP again. A process still holding the
    // microphone means HFP is intentional, so never steal its output then.
    static void recoverOutput(CFRunLoopTimerRef timer, void *info) {
      AudioDeviceID output = defaultOutput();
      if (output == 0 || !isBluetooth(output)) return;
      int channels = channelCount(output, kAudioObjectPropertyScopeOutput);
      if (channels == 0 || channels > 1) return;
      if (nominalSampleRate(output) > 16000) return;
      AudioDeviceID mic = sibling(output, kAudioObjectPropertyScopeInput);
      if (mic == 0 || isRunningSomewhere(mic)) return;
      AudioDeviceID speakers = preferredOutput();
      if (speakers == 0 || speakers == output) return;
      CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
      if (now - g_lastBounce < 5) return;
      char headsetName[256] = { 0 }, speakerName[256] = { 0 };
      if (!deviceName(output, headsetName, sizeof(headsetName))) return;
      if (!deviceName(speakers, speakerName, sizeof(speakerName))) return;
      g_lastBounce = now;
      strlcpy(g_headsetName, headsetName, sizeof(g_headsetName));
      strlcpy(g_speakerName, speakerName, sizeof(g_speakerName));
      g_bouncePending = 1;
      setDefaultOutput(speakers);
      printf("output: %s -> forced A2DP renegotiation via %s\n", headsetName, speakerName);
      fflush(stdout);
      CFRunLoopTimerRef restore = CFRunLoopTimerCreate(NULL, CFAbsoluteTimeGetCurrent() + 0.6, 0, 0, 0, restoreOutput, NULL);
      if (restore == NULL) return;
      CFRunLoopAddTimer(CFRunLoopGetMain(), restore, kCFRunLoopCommonModes);
      CFRelease(restore);
    }

    static void scheduleOutputRecovery(void) {
      CFRunLoopTimerRef check = CFRunLoopTimerCreate(NULL, CFAbsoluteTimeGetCurrent() + 0.8, 0, 0, 0, recoverOutput, NULL);
      if (check == NULL) return;
      CFRunLoopAddTimer(CFRunLoopGetMain(), check, kCFRunLoopCommonModes);
      CFRelease(check);
    }

    static CFAbsoluteTime g_lastInputLog = 0;

    // Policy: never let a Bluetooth device with an output endpoint be the default
    // input. Add another transport predicate here if a new device class needs the
    // same protection.
    static void enforceInput(void) {
      AudioDeviceID input = defaultInput();
      if (!needsProtection(input)) return;
      AudioDeviceID mic = preferredInput();
      if (mic == 0 || mic == input) return;
      setDefaultInput(mic);
      scheduleOutputRecovery();
      CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
      if (now - g_lastInputLog > 60) {
        g_lastInputLog = now;
        char inputName[256] = "Bluetooth input";
        char micName[256] = "preferred input";
        deviceName(input, inputName, sizeof(inputName));
        deviceName(mic, micName, sizeof(micName));
        printf("input: %s -> %s\n", inputName, micName);
        fflush(stdout);
      }
    }

    static OSStatus inputChanged(AudioObjectID object, UInt32 count, const AudioObjectPropertyAddress addresses[], void *context) {
      CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ enforceInput(); });
      CFRunLoopWakeUp(CFRunLoopGetMain());
      return noErr;
    }

    int main(void) {
      enforceInput();

      AudioObjectPropertyAddress address = prop(kAudioHardwarePropertyDefaultInputDevice, kAudioObjectPropertyScopeGlobal);
      if (AudioObjectAddPropertyListener(kAudioObjectSystemObject, &address, inputChanged, NULL) != noErr) {
        fprintf(stderr, "failed to listen for default input changes\n");
        return 1;
      }

      // Safety net: re-check once a minute in case a listener is lost across
      // sleep/wake, and heal an output left in HFP after its mic was released.
      CFRunLoopTimerRef timer = CFRunLoopTimerCreateWithHandler(
          NULL, CFAbsoluteTimeGetCurrent() + 60, 60, 0, 0,
          ^(CFRunLoopTimerRef timer) {
            enforceInput();
            recoverOutput(NULL, NULL);
          });
      CFRunLoopAddTimer(CFRunLoopGetMain(), timer, kCFRunLoopCommonModes);
      CFRelease(timer);

      CFRunLoopRun();
      return 0;
    }
  '';

  audio-input-guard = pkgs.stdenv.mkDerivation {
    pname = "audio-input-guard";
    version = "1";
    dontUnpack = true;
    buildPhase = ''
      runHook preBuild
      $CC -O2 -fblocks -Wall -o audio-input-guard ${audio-input-guard-src} -framework CoreAudio -framework CoreFoundation
      runHook postBuild
    '';
    installPhase = ''
      install -Dm755 audio-input-guard $out/bin/audio-input-guard
    '';
  };

  jobs = {
    # Keeps the preferred non-Bluetooth mic as the default input so Bluetooth
    # headsets stay on A2DP. Transport-based, so it covers every headset.
    audio-input-guard = {
      command = "${audio-input-guard}/bin/audio-input-guard";
      keepAlive = true;
      darwinOnly = true;
    };
    # Off: Claude Code no longer has a 5-hour usage limit, so there is no window to anchor.
    claude-warmup = {
      enable = false;
      script = "jobs/claude-warmup.sh";
      at = {
        hour = 9;
        minute = 0;
      };
    };
    # The script is the sops secret daily-report: it names a work project.
    daily-report = {
      command = "bash ${vars.home}/.config/sops-nix/secrets/daily-report";
      at = {
        hour = 8;
        minute = 0;
      };
      darwinOnly = true;
    };
    # manim-explainer skill: moves Manim, Kokoro, Whisper and their Python to the newest releases, but only after
    # its self-test passes (a held upgrade posts a notification). A no-op takes seconds.
    manim-explainer-upgrade = {
      command = "python3 ${vars.repoDir}/agents/skills/manim-explainer/setup.py --upgrade";
      at = {
        hour = 4;
        minute = 30;
      };
    };
    # Stale build output and oversized package caches; `DRY_RUN=1 just clean` previews it.
    dev-cleanup = {
      script = "jobs/dev-cleanup.sh";
      at = {
        hour = 4;
        minute = 0;
      };
    };
    docker-vm-trim = {
      script = "jobs/docker-vm-trim.sh";
      keepAlive = true;
      darwinOnly = true;
    };
    t3-network-guard = {
      script = "jobs/t3-network-guard.sh";
      keepAlive = true;
      darwinOnly = true;
    };
  };

  logDir = "${vars.home}/.local/state/jobs";
  path = lib.concatStringsSep ":" [
    "${vars.home}/.local/bin"
    "/etc/profiles/per-user/${vars.user}/bin"
    "/run/current-system/sw/bin"
    "${vars.home}/.nix-profile/bin"
    "/opt/homebrew/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
  run = job: if job ? script then "${vars.repoDir}/${job.script}" else job.command;
  active = lib.filterAttrs (
    _: job: (job.enable or true) && (pkgs.stdenv.isDarwin || !(job.darwinOnly or false))
  ) jobs;
  scheduled = lib.filterAttrs (_: job: job ? at) active;
in
{
  launchd.agents = lib.mkIf pkgs.stdenv.isDarwin (
    lib.mapAttrs (name: job: {
      enable = true;
      config = {
        ProgramArguments = [
          "${pkgs.bash}/bin/bash"
          "-c"
          (run job)
        ];
        EnvironmentVariables.PATH = path;
        StandardOutPath = "${logDir}/${name}.log";
        StandardErrorPath = "${logDir}/${name}.log";
        LowPriorityIO = true;
      }
      // lib.optionalAttrs (job ? at) {
        StartCalendarInterval = [
          {
            Hour = job.at.hour;
            Minute = job.at.minute;
          }
        ];
        ProcessType = "Background";
      }
      // lib.optionalAttrs (job.keepAlive or false) {
        RunAtLoad = true;
        KeepAlive = true;
      };
    }) active
  );

  systemd.user.services = lib.mkIf pkgs.stdenv.isLinux (
    lib.mapAttrs (
      name: job:
      {
        Unit.Description = name;
        Service = {
          ExecStart = "${pkgs.bash}/bin/bash -c ${lib.escapeShellArg (run job)}";
          Environment = "PATH=${path}";
          StandardOutput = "append:${logDir}/${name}.log";
          StandardError = "append:${logDir}/${name}.log";
          Nice = 10;
          IOSchedulingClass = "idle";
        }
        // (if job.keepAlive or false then { Restart = "always"; } else { Type = "oneshot"; });
      }
      // lib.optionalAttrs (job.keepAlive or false) { Install.WantedBy = [ "default.target" ]; }
    ) active
  );

  systemd.user.timers = lib.mkIf pkgs.stdenv.isLinux (
    lib.mapAttrs (name: job: {
      Unit.Description = name;
      Timer = {
        OnCalendar = "*-*-* ${toString job.at.hour}:${lib.fixedWidthNumber 2 job.at.minute}:00";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    }) scheduled
  );

  home.activation.jobLogDir = lib.hm.dag.entryAfter [ "writeBoundary" ] "run mkdir -p ${logDir}";
}
