# MetroCop radio recorder

Press **F6** once to record from WO Mic and press **F6** again to stop. The
controller builds the radio message, retains it, then plays it through the
Windows default output device. It uses no Soundpad keys and no permanent
console window, so F6 does not rely on sending a character to `cmd.exe`.

There is deliberately no Windows ready beep: that sound can interfere with
some virtual-audio routes. The recorder flushes raw audio continuously, so a
forced stop on the second F6 does not discard the last part of the phrase.

## Files and responsibilities

* `metrocop.ahk` is a tiny AutoHotkey v1 F6 trigger.
* `metrocop.py` records, stops the exact FFmpeg process it started, keeps the
  history, and plays the finished result.
* `radio.bat` is **only** the requested FFmpeg voice converter plus the
  `on2.wav` / `off2.wav` concatenation. The supplied voice-filter command is
  preserved unchanged.

## Setup

1. Install **Python 3** using the standard Windows installer. It must provide
   `py.exe` (enable the launcher option during installation).
2. Install FFmpeg and ensure `ffmpeg` and `ffplay` are available in `PATH`.
3. Keep `on2.wav` and `off2.wav` beside the scripts.
4. Run `metrocop.ahk` with **AutoHotkey v1**. In VRChat, use F6 as the trigger:
   press once to start recording, speak, then press F6 again to stop and
   transmit.
5. If FFmpeg shows another DirectShow microphone name, edit only `MIC_NAME` in
   `metrocop.py`. To list names, run:
   ```bat
   ffmpeg -list_devices true -f dshow -i dummy
   ```

## Output and diagnostics

* `input.wav` is the latest captured phrase.
* `output_metrocop.wav` is the final `on2 + converted voice + off2` message.
* `recordings/` contains eleven input/output pairs. `0` is oldest and `10` is
  newest; recording a twelfth message drops index 0 and shifts the rest down.
* `metrocop.log` records start/stop and FFmpeg errors. If F6 seems to do
  nothing, open this file first. It will reveal missing Python, FFmpeg, or a
  wrong microphone name.
