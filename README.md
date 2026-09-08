# MetroCop radio recorder

`metrocop.ahk` uses **only F6**. The first press starts microphone capture; the
second press stops it, builds the radio transmission, saves it, and plays it on
the Windows default output device. It does not send any Soundpad shortcuts.

## Setup

1. Install FFmpeg and make sure both `ffmpeg` and `ffplay` are available in
   `PATH`.
2. Put `on2.wav` and `off2.wav` next to `radio.bat`.
3. Confirm that `ffmpeg -list_devices true -f dshow -i dummy` reports the
   microphone as `Microphone (WO Mic Device)`. If Windows reports a different
   name, change only `MIC_NAME` at the top of `radio.bat`.
4. Run `metrocop.ahk` with AutoHotkey v1. The console opens once and remains
   open; keep it running while using F6 in VRChat.

## Files produced

* `input.wav` is the last captured microphone phrase.
* `output_metrocop.wav` is the final playback file: `on2.wav`, the supplied
  MetroCop FFmpeg voice filter, then `off2.wav`.
* `recordings/` retains 11 complete input/output pairs, numbered `0` through
  `10`. Index `0` is the oldest; when another message arrives, it is removed
  and the remaining pairs shift down one index.

Temporary `recording.pcm` is deliberately retained after failures so a broken
recording can be diagnosed.
