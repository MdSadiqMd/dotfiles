"""Where this machine's toolchain lives. The skill's setup.py builds it (nix activation runs it once per machine, a
weekly job keeps it on the newest versions that pass the self-test):
  <home>/render   venv with the newest Manim; its bin/ goes first on PATH for render.py
  <home>/voice    venv with Kokoro TTS + Whisper; make_voice.py and qa_asr.py move into it
  <home>/versions.json   what is installed, written after the self-test passed
<home> is ~/.local/share/manim-explainer, or $MANIM_EXPLAINER_HOME (the self-test points it at a staged build)."""
import importlib.util
import json
import os
import sys
from pathlib import Path

HOME = Path.home()
DATA = Path(os.environ.get("MANIM_EXPLAINER_HOME") or
            Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share") / "manim-explainer")
RENDER = DATA / "render"
VOICE = DATA / "voice"
SETUP = "python3 ~/.claude/skills/manim-explainer/setup.py"


def voice_python(module):
    """Re-run the calling script under the voice venv when `module` isn't installed here (e.g. system python3).
    Call before importing numpy. An old project's .kokoro python already has it and runs as is.
    find_spec, not import: importing kokoro would load huggingface_hub before hf_offline() can configure it."""
    if importlib.util.find_spec(module) is None:
        py = VOICE / "bin/python"
        if py.exists() and Path(sys.prefix).resolve() != VOICE.resolve():
            os.execv(py, [str(py), *sys.argv])
        raise SystemExit(f"{module} is missing: run {SETUP}")


def hf_offline(*repos):
    """Skip Hugging Face's network check on every model load once all `repos` are cached. On a bad connection
    that check stalled a one-line re-voice for 18 minutes. The weekly upgrade refreshes the models online."""
    hub = Path(os.environ.get("HF_HUB_CACHE") or Path(os.environ.get("HF_HOME", HOME / ".cache/huggingface")) / "hub")
    if all((hub / f"models--{r.replace('/', '--')}" / "snapshots").is_dir() for r in repos):
        os.environ.setdefault("HF_HUB_OFFLINE", "1")
    os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")  # progress bars only fill an agent's context


def quiet_torch():
    """Silence torch's deprecation chatter and its macOS logging note (printed on every voice run; agents had to
    grep it away). Real failures still raise, and setup.py's self-test catches a torch that breaks Kokoro."""
    import logging
    import warnings
    warnings.filterwarnings("ignore", category=FutureWarning, module="torch")
    warnings.filterwarnings("ignore", category=UserWarning, module="torch")
    # torch sets this logger's level itself when it creates it; a filter survives that
    logging.getLogger("torch.distributed.elastic.multiprocessing.redirects").addFilter(lambda record: False)


def tool_path():
    """PATH with the render venv's manim first, then LaTeX. Agent shells (opencode under T3) don't always have
    ~/.local/bin or the nix profiles; TinyTeX is the fallback on machines set up before LaTeX came from nix."""
    user = os.environ.get("USER", "")
    dirs = [RENDER / "bin", HOME / ".local/bin", Path("/run/current-system/sw/bin"),
            Path(f"/etc/profiles/per-user/{user}/bin"), HOME / ".nix-profile/bin",
            *sorted(HOME.glob("Library/TinyTeX/bin/*")), *sorted(HOME.glob(".TinyTeX/bin/*"))]
    path = [p for p in os.environ.get("PATH", "").split(os.pathsep) if p]
    first = [str(RENDER / "bin")] if (RENDER / "bin/manim").exists() else []
    return os.pathsep.join(first + [p for p in path if p not in first] +
                           [str(d) for d in dirs if d.is_dir() and str(d) not in path + first])


def versions():
    """{"render": {...}, "voice": {...}} as recorded by setup.py; {} on a machine set up the old way."""
    try:
        return json.loads((DATA / "versions.json").read_text())
    except (OSError, ValueError):
        return {}
