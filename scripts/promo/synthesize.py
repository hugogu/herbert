"""Generate chapter voiceovers with cached Kokoro; compose an original pulse bed.

Requires kokoro-onnx, numpy and soundfile. Models are supplied explicitly; this
script never downloads models or contacts a voice service.
"""
import argparse
import json
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--models", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--story", type=Path, default=Path(__file__).with_name("storyboard.json"))
    parser.add_argument("--chapter", type=int, help="Regenerate one voice chapter and update its report")
    args = parser.parse_args()
    # espeak's data-path buffer is short; deep uv environments need a short link.
    import espeakng_loader
    from phonemizer.backend.espeak.wrapper import EspeakWrapper

    data = Path(espeakng_loader.get_data_path())
    with tempfile.TemporaryDirectory() as temporary:
        if len(str(data)) >= 150:
            link = Path(temporary) / "espeak-ng-data"
            link.symlink_to(data)
            EspeakWrapper.data_path = property(lambda self: link)
        from kokoro_onnx import Kokoro

        story = json.loads(args.story.read_text())
        args.output.mkdir(parents=True, exist_ok=True)
        model = Kokoro(str(args.models / "kokoro-v1.0.onnx"), str(args.models / "voices-v1.0.bin"))
        report_path = args.output / "voice-report.json"
        report = json.loads(report_path.read_text()) if args.chapter is not None else []
        for index, chapter in enumerate(story["chapters"]):
            if args.chapter is not None and args.chapter != index:
                continue
            samples, rate = model.create(chapter["narration"], voice=story["voice"],
                                         speed=story["speed"], lang="en-us")
            # Retain natural internal pauses; remove leading/trailing model padding.
            audible = np.flatnonzero(np.abs(samples) > 0.006)
            if not audible.size:
                raise ValueError("Kokoro produced no audible speech")
            samples = samples[max(0, audible[0] - int(rate * .04)):
                              min(len(samples), audible[-1] + int(rate * .16))]
            filename = f"voice-{index:02d}.wav"
            sf.write(args.output / filename, samples, rate)
            entry = {"file": filename, "duration": len(samples) / rate,
                           "slot": chapter["end"] - chapter["start"], "engine": "Kokoro-82M v1.0",
                           "voice": story["voice"], "speed": story["speed"]}
            if args.chapter is None:
                report.append(entry)
            else:
                report[index] = entry
            print(entry, flush=True)
        report_path.write_text(json.dumps(report, indent=2) + "\n")

    rate = 48000
    bed = np.zeros(int(story["duration"] * rate), dtype=np.float64)
    rng = np.random.default_rng(39)

    def add(start, wave, level):
        offset = int(start * rate)
        if offset >= len(bed):
            return
        end = min(len(bed), offset + len(wave))
        bed[offset:end] += wave[:end - offset] * level

    # 120 BPM, original synthesized percussion and D-minor arpeggios.
    for beat in range(story["duration"] * 2):
        start = beat * .5
        intensity = .45 if start < story["chapters"][0]["end"] or start >= story["duration"] - 4 else 1
        t = np.arange(int(.28 * rate)) / rate
        kick = np.sin(2 * np.pi * (48 * t + 32 * .035 * (1 - np.exp(-t / .035)))) * np.exp(-t * 19)
        add(start, kick, .34 * intensity)
        if beat % 2:
            t = np.arange(int(.16 * rate)) / rate
            snare = rng.normal(size=len(t)) * np.exp(-t * 35)
            add(start, snare, .065 * intensity)
        for off in (0, .25):
            t = np.arange(int(.045 * rate)) / rate
            noise = rng.normal(size=len(t))
            hat = np.diff(noise, prepend=0) * np.exp(-t * 100)
            add(start + off, hat, .025 * intensity)
        notes = [146.832, 220, 293.665, 349.228, 130.813, 196, 261.626, 329.628]
        frequency = notes[(beat // 8 % 2) * 4 + beat % 4]
        t = np.arange(int(.42 * rate)) / rate
        envelope = (1 - np.exp(-t * 130)) * np.exp(-t * 9)
        arp = (np.sin(2 * np.pi * frequency * t) + .22 * np.sin(4 * np.pi * frequency * t)) * envelope
        add(start, arp, .10 * intensity)
    for start in (chapter["start"] for chapter in story["chapters"][1:]):
        t = np.arange(int(.45 * rate)) / rate
        impact = np.sin(2 * np.pi * (85 * t - 24 * t * t)) * np.exp(-t * 11)
        add(start, impact, .35)
    fade = np.minimum(1, np.arange(len(bed)) / rate / .1)
    fade *= np.minimum(1, (len(bed) - np.arange(len(bed))) / rate / 2)
    bed *= fade
    sf.write(args.output / "original-pulse-bed.wav", np.column_stack((bed, np.roll(bed, 520) * .95)), rate)


if __name__ == "__main__":
    main()
