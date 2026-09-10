# Combine radio recorder

Windows utility for role-playing a Combine soldier in VRChat. Press **F6** once
to begin capturing speech from WO Mic, then press **F6** again to stop,
process the phrase, add radio click sounds, and play the finished message on
the default Windows playback device.

## Project layout

| File or directory | Purpose |
| --- | --- |
| `combine.ahk` | The AutoHotkey v1 entry point. F6 is its only hotkey; it starts `combine.py toggle` without relying on a visible console window. |
| `combine.py` | Controller for the entire recording workflow: it starts and stops FFmpeg, creates `input.wav`, calls `radio.bat`, maintains the archive, plays the finished audio, and logs errors. |
| `radio.bat` | The **Combine voice converter only**. It applies the requested Combine FFmpeg filter and joins `on2.wav`, the processed voice, and `off2.wav`. It does not record from the microphone or handle F6. |
| `on2.wav` | Radio activation/click sound prepended to every message. |
| `off2.wav` | Radio deactivation/click sound appended to every message. |
| `input.wav` | Latest unprocessed phrase captured from the microphone. Generated at runtime. |
| `output_combine.wav` | Latest finished Combine radio message: `on2.wav + processed phrase + off2.wav`. Generated at runtime. |
| `recording.pcm` | Temporary raw microphone data. Generated at runtime. |
| `recordings/` | FIFO archive of up to eleven input/output pairs. Index `0` is oldest and `10` is newest. |
| `.combine-state.json` | Temporary state identifying the FFmpeg recording process between the first and second F6 presses. |
| `combine.log` | Timestamped controller and FFmpeg diagnostic log. |

## How one transmission works

1. `combine.ahk` receives the first F6 and runs `py.exe -3 combine.py toggle`.
2. `combine.py` starts FFmpeg's DirectShow capture from
   `Microphone (WO Mic Device)` and continuously writes raw 44.1 kHz mono PCM
   to `recording.pcm`.
3. The second F6 finds that recording process and stops it. The raw PCM is
   converted into `input.wav`.
4. `combine.py` runs `radio.bat`. The batch file uses the Combine FFmpeg filter
   and produces `output_combine.wav`, with `on2.wav` at the beginning and
   `off2.wav` at the end.
5. The controller copies `input.wav` and `output_combine.wav` into the rolling
   `recordings/` archive, then uses `ffplay` to play the current finished file
   through the default Windows output device.

There is intentionally no Windows ready beep. Speak immediately after the
first F6; the raw PCM output is flushed continuously so the second F6 does not
lose the end of the phrase.

## Installation and use

1. Install **Python 3** for Windows and enable the Python launcher, so
   `py.exe` is available.
2. Install an FFmpeg build that provides both `ffmpeg.exe` and `ffplay.exe`,
   and add its `bin` directory to `PATH`.
3. Install **AutoHotkey v1** (not v2) and run `combine.ahk`.
4. Keep `combine.ahk`, `combine.py`, `radio.bat`, `on2.wav`, and `off2.wav` in
   the same directory.
5. In VRChat: press F6, speak into WO Mic, then press F6 again.

If the microphone has a different DirectShow name on this PC, edit only
`MIC_NAME` in `combine.py`. To list Windows DirectShow devices, run:

```bat
ffmpeg -list_devices true -f dshow -i dummy
```

## Maintenance and troubleshooting

* Do not modify the FFmpeg filter in `radio.bat` unless deliberately changing
  the Combine voice effect. It is the supplied Combine filter.
* `radio.bat` requires `input.wav`, `on2.wav`, and `off2.wav`; it returns a
  non-zero error code if any is absent or either FFmpeg command fails.
* If F6 appears to do nothing, open `combine.log`. It includes FFmpeg output
  and errors such as a missing executable or an incorrect microphone name.
* The state file normally disappears after recording stops. If Windows or the
  script was forcibly closed during a recording, delete `.combine-state.json`
  before pressing F6 again.
* Runtime audio, archive files, state, and logs are excluded by `.gitignore`.
