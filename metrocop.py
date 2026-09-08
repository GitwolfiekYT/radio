"""F6 controller for the MetroCop radio recorder (Windows only)."""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
STATE_FILE = ROOT / ".metrocop-state.json"
LOG_FILE = ROOT / "metrocop.log"
RAW_FILE = ROOT / "recording.pcm"
INPUT_FILE = ROOT / "input.wav"
OUTPUT_FILE = ROOT / "output_metrocop.wav"
MIC_NAME = "Microphone (WO Mic Device)"


def log(message: str) -> None:
    stamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with LOG_FILE.open("a", encoding="utf-8") as stream:
        stream.write(f"[{stamp}] {message}\n")


def read_state() -> dict:
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def write_state(state: dict) -> None:
    STATE_FILE.write_text(json.dumps(state), encoding="utf-8")


def clear_state() -> None:
    STATE_FILE.unlink(missing_ok=True)


def run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT, check=True, creationflags=subprocess.CREATE_NO_WINDOW)


def start_recording() -> None:
    # A new transmission always replaces the previous one. Do this before
    # FFmpeg opens the microphone so stale files cannot be used by mistake.
    INPUT_FILE.unlink(missing_ok=True)
    OUTPUT_FILE.unlink(missing_ok=True)
    RAW_FILE.unlink(missing_ok=True)
    command = [
        "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "warning", "-y",
        "-f", "dshow", "-rtbufsize", "64M", "-i", f"audio={MIC_NAME}",
        # The controller has to force-stop FFmpeg from a later F6 press.
        # Flush every raw PCM packet so that stop cannot leave the spoken tail
        # sitting in FFmpeg's output buffer.
        "-f", "s16le", "-ac", "1", "-ar", "44100", "-flush_packets", "1",
        str(RAW_FILE),
    ]
    with LOG_FILE.open("a", encoding="utf-8") as stream:
        process = subprocess.Popen(
            command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP,
        )
    write_state({"pid": process.pid, "started": time.time()})
    log(f"Recording started (PID {process.pid}).")


def stop_and_process(state: dict) -> None:
    pid = state.get("pid")
    if not isinstance(pid, int):
        clear_state()
        log("Invalid recording state was cleared.")
        return
    # Raw PCM has no WAV header, so force-stopping FFmpeg cannot corrupt it.
    subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True,
                   creationflags=subprocess.CREATE_NO_WINDOW)
    time.sleep(0.4)
    clear_state()
    if not RAW_FILE.exists() or RAW_FILE.stat().st_size < 4000:
        log("Recording was empty; nothing was processed.")
        return
    try:
        run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "warning", "-f", "s16le",
             "-ar", "44100", "-ac", "1", "-i", str(RAW_FILE), str(INPUT_FILE)])
        run(["cmd.exe", "/d", "/c", str(ROOT / "radio.bat")])
        log("Playing output_metrocop.wav on the Windows default output device.")
        run(["ffplay", "-nodisp", "-autoexit", "-hide_banner", "-loglevel", "warning", str(OUTPUT_FILE)])
        log("Message complete.")
    except (OSError, subprocess.CalledProcessError) as error:
        log(f"Processing failed: {error}")


def toggle() -> None:
    state = read_state()
    if state:
        stop_and_process(state)
    else:
        try:
            start_recording()
        except OSError as error:
            log(f"Could not start FFmpeg: {error}")


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "toggle":
        toggle()
    else:
        raise SystemExit("Usage: py -3 metrocop.py toggle")
