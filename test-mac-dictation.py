#!/usr/bin/env python3
"""
Interactive Gemma 4 dictation tester for Mac.

Loads the model once, then loops: record audio → transcribe + clean → copy to clipboard.
Run with:
    uv run --with sounddevice --with scipy --with numpy test-mac-dictation.py

Or, if dependencies are already installed:
    python3 test-mac-dictation.py
"""

import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

# ── Model config ─────────────────────────────────────────────────────────────
# bf16 = unquantized, sidesteps the PLE quantization bug that makes 4bit output garbage.
# ~10 GB on disk, but your M1 Pro 16 GB handles it comfortably.
MODEL_ID = "mlx-community/gemma-4-e2b-it-bf16"

# You can switch to the 4bit model to test quantized quality (risk: PLE bug):
# MODEL_ID = "mlx-community/gemma-4-e2b-it-4bit"

SAMPLE_RATE = 16_000       # Gemma 4 audio tower expects 16kHz mono

SYSTEM_PROMPT = (
    "You are an expert multilingual dictation assistant. The user speaks German, "
    "English, French, or Dutch — detect the language from the audio and respond in "
    "the same language. Transcribe what the user said, then clean it up: remove "
    "filler words (um, uh, like, äh, alors, euh), fix mid-sentence corrections "
    "(honor the user's latest intent), and fix obvious grammar. Preserve meaning, "
    "names, and technical terms. Output ONLY the final cleaned text — no preamble, "
    "no commentary, no quotation marks, no language label."
)

# ── Dependency bootstrap ─────────────────────────────────────────────────────

def ensure(pkg: str, import_name: str | None = None) -> None:
    try:
        __import__(import_name or pkg)
    except ImportError:
        print(f"Installing {pkg}...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", pkg])

ensure("sounddevice")
ensure("scipy")
ensure("numpy")

import numpy as np
import sounddevice as sd
import scipy.io.wavfile as wavfile

from mlx_vlm import generate, load
from mlx_vlm.prompt_utils import apply_chat_template


# ── Core functions ───────────────────────────────────────────────────────────

def record_audio_interactive() -> Path:
    """Record from the default mic until the user presses Enter. Returns WAV path."""
    frames: list = []
    stop_timer = threading.Event()

    def audio_callback(indata, _frames, _time, _status):
        frames.append(indata.copy())

    def print_timer():
        start = time.time()
        while not stop_timer.is_set():
            elapsed = time.time() - start
            print(f"   🔴 Recording: {elapsed:5.1f}s — press Enter to STOP", end="\r", flush=True)
            time.sleep(0.1)

    with sd.InputStream(
        samplerate=SAMPLE_RATE,
        channels=1,
        dtype="float32",
        callback=audio_callback,
    ):
        timer_thread = threading.Thread(target=print_timer, daemon=True)
        timer_thread.start()
        input()  # Blocks until user hits Enter
        stop_timer.set()
        timer_thread.join(timeout=0.5)

    print("\n   ✅ Recording done                                      ")

    if not frames:
        raise RuntimeError("No audio captured — check your mic permissions.")

    # Concatenate all callback chunks into one buffer
    audio = np.concatenate(frames, axis=0).flatten()

    # scipy expects int16 for WAV — convert float32 [-1, 1] → int16
    audio_int16 = np.int16(audio * 32767)
    fd, temp_path_str = tempfile.mkstemp(suffix=".wav")
    import os
    os.close(fd)
    temp_path = Path(temp_path_str)
    wavfile.write(temp_path, SAMPLE_RATE, audio_int16)
    return temp_path


def copy_to_clipboard(text: str) -> None:
    subprocess.run(["pbcopy"], input=text.encode("utf-8"), check=False)


# ── Main loop ────────────────────────────────────────────────────────────────

def main() -> None:
    print(f"📦 Loading {MODEL_ID}...")
    print("   (first run downloads ~10 GB from HuggingFace)")
    t0 = time.time()
    model, processor = load(MODEL_ID)
    config = model.config
    print(f"✅ Loaded in {time.time() - t0:.1f}s\n")

    while True:
        try:
            raw = input("Press Enter to START recording (or 'q' to quit): ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nBye 👋")
            break

        if raw.lower() in {"q", "quit", "exit"}:
            print("Bye 👋")
            break

        audio_path = record_audio_interactive()

        print("🧠 Thinking...")
        t0 = time.time()

        # Build the chat-templated prompt (mlx_vlm handles the audio token insertion)
        formatted_prompt = apply_chat_template(
            processor,
            config,
            prompt="Transcribe and clean the following audio.",
            num_images=0,
            num_audios=1,
        )

        output = generate(
            model,
            processor,
            formatted_prompt,
            audio=str(audio_path),
            system=SYSTEM_PROMPT,
            max_tokens=256,
            temperature=0.1,
            verbose=False,
        )

        # `generate` returns a GenerationResult-like object; extract the text.
        text = output if isinstance(output, str) else getattr(output, "text", str(output))
        text = text.strip().strip('"')

        elapsed = time.time() - t0
        print(f"\n📝 Output ({elapsed:.1f}s):")
        print(f"   {text}\n")

        copy_to_clipboard(text)
        print("📋 Copied to clipboard.\n")

        # Clean up temp file
        try:
            audio_path.unlink()
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    main()
