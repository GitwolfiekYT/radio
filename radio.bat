@echo off
setlocal
cd /d "%~dp0"

REM This file intentionally contains only the supplied voice conversion and
REM the radio click concatenation.  Recording, retention, and playback live
REM in metrocop.py.
if not exist "input.wav" exit /b 2
if not exist "on2.wav" exit /b 3
if not exist "off2.wav" exit /b 4

REM Never leave a prior transmission available if this conversion fails.
del /q "output_metrocop.wav" "radio_message.wav" 2>nul

REM Do not change this filter: it is the requested MetroCop voice treatment.
ffmpeg -y -i input.wav -af "asetrate=44100*0.8165,atempo=1.2247,aresample=44100,highpass=f=650,lowpass=f=3200,equalizer=f=1800:width_type=h:w=400:g=12,equalizer=f=900:width_type=h:w=200:g=6,volume=8dB,alimiter=limit=0.5,acompressor=threshold=-14dB:ratio=12:attack=10:release=100,volume=4dB,loudnorm" output_metrocop.wav
if errorlevel 1 exit /b 10

REM Append the radio sounds as: on2.wav + voice + off2.wav.
ffmpeg -y -hide_banner -loglevel warning -i "on2.wav" -i "output_metrocop.wav" -i "off2.wav" -filter_complex "[0:a]aresample=44100,aformat=channel_layouts=mono[on];[1:a]aresample=44100,aformat=channel_layouts=mono[voice];[2:a]aresample=44100,aformat=channel_layouts=mono[off];[on][voice][off]concat=n=3:v=0:a=1[out]" -map "[out]" "radio_message.wav"
if errorlevel 1 exit /b 11
move /y "radio_message.wav" "output_metrocop.wav" >nul
