@echo off
setlocal
cd /d "%~dp0"

REM This file intentionally contains only the supplied voice conversion and
REM the radio click concatenation.  Recording, retention, and playback live
REM in combine.py.
if not exist "input.wav" exit /b 2
if not exist "on2.wav" exit /b 3
if not exist "off2.wav" exit /b 4

REM Do not change this filter: it is the requested Combine voice treatment.
ffmpeg -y -i input.wav -af "asetrate=44100*0.73,atempo=1.37,aresample=44100,highpass=f=380,lowpass=f=3200,tremolo=f=42:d=0.65,aecho=0.8:0.7:3:0.4,equalizer=f=950:width_type=h:w=200:g=6,equalizer=f=2100:width_type=h:w=300:g=8,volume=6dB,alimiter=limit=0.45,acompressor=threshold=-18dB:ratio=14:attack=5:release=70,volume=3dB,loudnorm" output_combine.wav
if errorlevel 1 exit /b 10

REM Append the radio sounds as: on2.wav + voice + off2.wav.
ffmpeg -y -hide_banner -loglevel warning -i "on2.wav" -i "output_combine.wav" -i "off2.wav" -filter_complex "[0:a]aresample=44100,aformat=channel_layouts=mono[on];[1:a]aresample=44100,aformat=channel_layouts=mono[voice];[2:a]aresample=44100,aformat=channel_layouts=mono[off];[on][voice][off]concat=n=3:v=0:a=1[out]" -map "[out]" "radio_message.wav"
if errorlevel 1 exit /b 11
move /y "radio_message.wav" "output_combine.wav" >nul
