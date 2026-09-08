"""F6 controller for the MetroCop radio recorder (Windows only)."""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

if sys.platform == "win32":
    import winsound

ROOT = Path(__file__).resolve().parent
STATE_FILE = ROOT / ".metrocop-state.json"
LOG_FILE = ROOT / "metrocop.log"
RAW_FILE = ROOT / "recording.pcm"
INPUT_FILE = ROOT / "input.wav"
OUTPUT_FILE = ROOT / "output_metrocop.wav"
HISTORY = ROOT / "recordings"
MIC_NAME = "Microphone (WO Mic Device)"
MAX_RECORDINGS = 11
READY_BYTES = 4_410  # 50 ms of 44.1 kHz, mono, signed 16-bit PCM.
READY_TIMEOUT_SECONDS = 5.0


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


def wait_until_microphone_is_ready(process: subprocess.Popen[bytes]) -> bool:
    """Wait until DirectShow has written audio, rather than only spawned FFmpeg."""
    deadline = time.monotonic() + READY_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        if RAW_FILE.exists() and RAW_FILE.stat().st_size >= READY_BYTES:
            return True
        if process.poll() is not None:
            return False
        time.sleep(0.05)
    return False


def notify_recording_ready() -> None:
    """Give a local ready cue only after the microphone has actual samples."""
    if sys.platform == "win32":
        winsound.MessageBeep(winsound.MB_ICONASTERISK)


def start_recording() -> None:
    RAW_FILE.unlink(missing_ok=True)
    command = [
        "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "warning", "-y",
        "-f", "dshow", "-rtbufsize", "64M", "-i", f"audio={MIC_NAME}",
        "-f", "s16le", "-ac", "1", "-ar", "44100", str(RAW_FILE),
    ]
    with LOG_FILE.open("a", encoding="utf-8") as stream:
        process = subprocess.Popen(
            command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP,
        )
    write_state({"pid": process.pid, "started": time.time()})
    # DirectShow often needs a short moment to open WO Mic.  Spawning FFmpeg is
    # not enough: speaking before its first samples arrive loses the beginning.
    if wait_until_microphone_is_ready(process):
        notify_recording_ready()
        log(f"Microphone ready; recording started (PID {process.pid}).")
    else:
        log("FFmpeg was started but WO Mic did not provide audio within 5 seconds.")


def archive() -> None:
    HISTORY.mkdir(exist_ok=True)
    # Keep 0..10, where 0 is oldest, exactly like a FIFO queue.
    if (HISTORY / f"{MAX_RECORDINGS - 1}_input.wav").exists():
        for suffix in ("input.wav", "metrocop.wav"):
            (HISTORY / f"0_{suffix}").unlink(missing_ok=True)
        # Shift upward in age order: 1 becomes 0, then 2 becomes 1, etc.
        for index in range(1, MAX_RECORDINGS):
            for suffix in ("input.wav", "metrocop.wav"):
                source = HISTORY / f"{index}_{suffix}"
                target = HISTORY / f"{index - 1}_{suffix}"
                if source.exists():
                    source.replace(target)
        target_index = MAX_RECORDINGS - 1
    else:
        target_index = sum((HISTORY / f"{index}_input.wav").exists()
                           for index in range(MAX_RECORDINGS))
    shutil.copy2(INPUT_FILE, HISTORY / f"{target_index}_input.wav")
    shutil.copy2(OUTPUT_FILE, HISTORY / f"{target_index}_metrocop.wav")


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
        archive()
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
