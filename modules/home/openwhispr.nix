{ pkgs, lib, ... }:
{
  home.activation = {
    # Merge these keys into the app's .env, keeping its other settings.
    openwhisprSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ENV_DIR="$HOME/Library/Application Support/open-whispr"
      ENV_FILE="$ENV_DIR/.env"
      run mkdir -p "$ENV_DIR"
      tmp="$(mktemp)"
      if [ -f "$ENV_FILE" ]; then
        # Also drop the voice-agent hotkeys: only Right Option dictates.
        ${pkgs.gawk}/bin/awk -v keys="START_MINIMIZED FLOATING_ICON_AUTO_HIDE HIDE_DICTATION_UI PANEL_START_POSITION DICTATION_LANGUAGE VOICE_AGENT_KEY CHAT_AGENT_KEY" '
          BEGIN { n = split(keys, k, " "); for (i = 1; i <= n; i++) skip[k[i]] = 1 }
          { key = $0; sub(/=.*/, "", key); if (!(key in skip)) print }
        ' "$ENV_FILE" > "$tmp"
      else
        printf '# OpenWhispr Environment Variables\n' > "$tmp"
      fi
      cat >> "$tmp" <<'OPENWHISPR_ENV'
      START_MINIMIZED=true
      FLOATING_ICON_AUTO_HIDE=true
      PANEL_START_POSITION=bottom-right
      DICTATION_LANGUAGE=auto
      OPENWHISPR_ENV
      run mv "$tmp" "$ENV_FILE"
    '';

    # The custom dictionary is the only text OpenWhispr passes as Whisper's prompt.
    # Romanized Telugu phrases stop Whisper translating Telugu into English; the
    # trailing English phrases keep English dictation in English.
    openwhisprTinglishPrompt = lib.hm.dag.entryAfter [ "openwhisprSettings" ] ''
      DB="$HOME/Library/Application Support/open-whispr/transcriptions.db"
      PROMPT="ela unnav raa. nenu baga unnanu. meeru ela unnaru. repu office ki veltunnanu. meeting padhi gantalaki undhi. idi enti raa. naku telusu. manam ekkadiki veltunnam. em chestunnav. please update cheyandi. real or not real. yo bro whats up."
      if [ -f "$DB" ]; then
        run ${pkgs.sqlite}/bin/sqlite3 -cmd ".timeout 5000" "$DB" \
          "DELETE FROM custom_dictionary WHERE word LIKE 'The following is Telugu speech%' OR word LIKE 'ela unnav raa%'; DELETE FROM custom_dictionary WHERE word = 'OpenWhispr'; INSERT INTO custom_dictionary (word, source) VALUES ('$PROMPT', 'manual'); INSERT INTO custom_dictionary (word, source) VALUES ('OpenWhispr', 'manual');" \
          || echo "warning: could not seed OpenWhispr Tinglish prompt (database busy?)"
        # Fix "yela" spelling; the English entry is a no-op anchor that ends the prompt in English.
        run ${pkgs.sqlite}/bin/sqlite3 -cmd ".timeout 5000" "$DB" \
          "DELETE FROM snippets WHERE trigger IN ('yela unnav raa', 'please send the report'); INSERT INTO snippets (trigger, replacement) VALUES ('yela unnav raa', 'ela unnav raa'); INSERT INTO snippets (trigger, replacement) VALUES ('please send the report', 'please send the report');" \
          || echo "warning: could not seed OpenWhispr Tinglish snippets (database busy?)"
      fi
    '';
  };
}
