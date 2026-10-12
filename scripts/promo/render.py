"""Edit real macOS captures into a 45s feature film or 30s cut.

Requires Pillow and ffmpeg/ffprobe. Typography is rendered locally; source app
pixels are preserved. The source capture sequences run at their recorded speed.
"""
import argparse
import json
import subprocess
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[2]
BG, MINT, WHITE, MUTED, GOLD = "#0c1d24", "#a5efcf", "#f7f6ef", "#9ab4b6", "#ffcd75"
FONT = "/System/Library/Fonts/Avenir Next.ttc"
MONO = "/System/Library/Fonts/Menlo.ttc"


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True, stdout=subprocess.DEVNULL)


def text(draw, xy, value, size, fill=WHITE, mono=False, width=None, spacing=8):
    font = ImageFont.truetype(MONO if mono else FONT, size)
    if width:
        lines, line = [], ""
        for word in value.split():
            candidate = (line + " " + word).strip()
            if draw.textlength(candidate, font=font) > width and line:
                lines.append(line)
                line = word
            else:
                line = candidate
        lines.append(line)
        value = "\n".join(lines)
    draw.multiline_text(xy, value, font=font, fill=fill, spacing=spacing)


def canvas(chapter, headline, detail, index, *, hero=False, note=""):
    image = Image.new("RGBA", (1920, 1080), BG)
    d = ImageDraw.Draw(image)
    for x in range(36, 1920, 48):
        for y in range(140, 950, 48):
            d.ellipse((x, y, x + 2, y + 2), fill="#19333b")
    d.rounded_rectangle((64, 46, 99, 81), radius=10, fill=MINT)
    d.line((81, 73, 81, 55), fill=BG, width=3)
    d.line((74, 62, 81, 55, 88, 62), fill=BG, width=3)
    text(d, (116, 43), "HERBOT BOT", 29)
    text(d, (1370, 52), chapter, 18, MINT, mono=True)
    d.line((64, 111, 1856, 111), fill="#2b444b", width=2)
    if not hero:
        text(d, (64, 198), f"{index:02d}", 20, GOLD, mono=True)
        text(d, (64, 267), headline, 68, width=355, spacing=8)
        text(d, (67, 584), detail, 25, MUTED, width=335, spacing=12)
        d.rounded_rectangle((65, 785, 372, 790), radius=2, fill=MINT)
        text(d, (65, 821), "THINK IN PATTERNS", 17, MINT, mono=True)
    if note:
        text(d, (500, 912), note, 19, GOLD)
    # Opaque lower band keeps captions readable over every source.
    d.rectangle((0, 960, 1920, 1080), fill=BG)
    return image


def compose_static(base, source, crop, hero=False):
    image = Image.open(source).convert("RGB")
    if crop:
        image = image.crop(tuple(int(v) for v in crop))
    box = (64, 140, 1856, 928) if hero else (480, 154, 1856, 904)
    size = (box[2] - box[0], box[3] - box[1])
    image = ImageOps.contain(image, size, Image.Resampling.LANCZOS)
    position = (box[0] + (size[0] - image.width) // 2, box[1] + (size[1] - image.height) // 2)
    base.alpha_composite(image.convert("RGBA"), position)
    return base


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--short", action="store_true")
    parser.add_argument("--reuse-shots", action="store_true", help="Reuse encoded shots when only audio or captions changed")
    args = parser.parse_args()
    output = args.output.resolve()
    work = output / ("short-render" if args.short else "render")
    work.mkdir(parents=True, exist_ok=True)
    story = json.loads(Path(__file__).with_name("storyboard-short.json" if args.short else "storyboard.json").read_text())
    audio = output / ("short-audio" if args.short else "audio")
    captures = ROOT / "outputs/app-store-macos/0.4.0/en-US"
    sources = output / "sources"
    run_video = captures / "raw-video/render/02-run.mp4"
    step_video = captures / "raw-video/render/03-step.mp4"
    # Each chapter is split into short visual phrases, with purposeful reframing.
    # Crops below reference verified native screenshot coordinates, not mock UI.
    shots = [
        (0, .30, "Three\ncommands.", "s   l   r", captures / "06-guide.png", (540, 100, 2290, 640), None),
        (0, .30, "Thirty\npuzzles.", "A complete original course.", captures / "01-library.png", (510, 600, 2330, 1180), None),
        (0, .40, "One tiny\nrobot.", "A beautiful piece of thinking.", run_video, (650, 520, 420, 420), 9),
        (1, .34, "WRITE\nLESS.", "An entire pattern.\nA few lines of H.", captures / "02-code.png", (2070, 710, 750, 760), None),
        (1, .41, "MAKE IT\nMOVE.", "Your code becomes a path.", run_video, (600, 500, 550, 500), 4),
        (1, .25, "EVERY\nBYTE\nCOUNTS.", "Solve within the limit.", captures / "02-code.png", (1295, 530, 680, 135), None),
        (2, .34, "RUN.\nPAUSE.", "Stay in control.", run_video, (1340, 865, 460, 195), 8),
        (2, .33, "STEP.\nSEE.", "Trace a program one move at a time.", step_video, (1340, 850, 460, 205), .1),
        (2, .33, "FOLLOW\nTHE\nTHOUGHT.", "Real moves.\nVisible feedback.", step_video, (600, 500, 550, 500), .4),
        (3, .32, "START\nSIMPLE.", "30 original lessons.\nLearn in order.", captures / "01-library.png", (510, 300, 2330, 1260), None),
        (3, .29, "BUILD\nPATTERNS.", "Procedures. Parameters.\nRecursion.", sources / "guide-recursion.png", (980, 210, 1420, 1100), None),
        (3, .39, "GO\nFURTHER.", "L30 / Astral cathedral", captures / "05-advanced.png", (700, 800, 1300, 880), None),
        (4, .34, "MODERN.", "A fresh perspective.", captures / "03-step.png", (580, 710, 1440, 1030), None),
        (4, .33, "CLASSIC.", "The same challenge.\nA different look.", captures / "04-classic.png", (580, 710, 1440, 1030), None),
        (4, .33, "KEEP\nGROWING.", "Drafts. Best solutions.\nOffline progress.", sources / "progress.png", (540, 120, 2280, 1200), None),
        (5, .27, "DIFFERENT\nMINDS.", "Meet AI Battlefield.", sources / "ai-setup.png", (540, 150, 2280, 1100), None),
        (5, .33, "YOUR\nMODELS.", "Bring your own API access.", sources / "ai-models.png", (0, 0, 1400, 1170), None),
        (5, .40, "LET CODE\nDECIDE.", "Same puzzles. Same rules.\nA real native judge.", sources / "ai-setup.png", (1690, 670, 1130, 530), None),
        (6, .28, "THINK\nSMALLER.", "Solve bigger.", run_video, (600, 500, 550, 500), 16),
        (6, .72, "Herbot Bot", "How elegant is your solution?", captures / "05-advanced.png", (700, 800, 1300, 880), "end"),
    ]
    timeline, chapter_offsets = [], [0.0] * 7
    for shot_index, (chapter_index, fraction, headline, detail, source, crop, source_time) in enumerate(shots):
        chapter = story["chapters"][chapter_index]
        duration = (chapter["end"] - chapter["start"]) * fraction
        # Quantize to frames and give the final shot the chapter remainder.
        prior = chapter_offsets[chapter_index]
        next_is_same = shot_index + 1 < len(shots) and shots[shot_index + 1][0] == chapter_index
        frames = max(15, round(duration * 2) * 15) if next_is_same else round((chapter["end"] - chapter["start"] - prior) * 30)
        duration = frames / 30
        chapter_offsets[chapter_index] += duration
        stem = work / f"shot-{shot_index:02d}"
        note = "Optional AI feature · Your API key required · Provider charges may apply" if chapter_index == 5 else ""
        base = canvas(chapter["title"], headline, detail, chapter_index, note=note)
        if chapter_index == 0:
            d = ImageDraw.Draw(base)
            d.rectangle((60, 190, 430, 754), fill=BG)
            number, label = [("3", "COMMANDS"), ("30", "PUZZLES"), ("1", "TINY ROBOT")][shot_index]
            text(d, (60, 205), number, 220, MINT)
            text(d, (65, 497), label, 41)
            text(d, (67, 633), detail, 25, MUTED, width=335)
        if source_time == "end":
            # Final identity card: large typography and a real puzzle, no fake controls.
            base = canvas("THINK IN PATTERNS", "", "", chapter_index, hero=True)
            board = Image.open(source).crop((crop[0], crop[1], crop[0]+crop[2], crop[1]+crop[3]))
            board = ImageOps.contain(board, (720, 630), Image.Resampling.LANCZOS)
            base.alpha_composite(board.convert("RGBA"), (1110, 205))
            d = ImageDraw.Draw(base)
            text(d, (90, 250), "Herbot Bot", 110)
            text(d, (95, 435), "THINK SMALLER.\nSOLVE BIGGER.", 55, MINT)
            text(d, (95, 665), "How elegant is your solution?", 34)
            text(d, (96, 827), "30 ORIGINAL PUZZLES  /  macOS", 21, GOLD, mono=True)
            base.save(stem.with_suffix(".png"))
        elif source_time is None:
            x, y, w, h = crop
            compose_static(base, source, (x, y, x+w, y+h)).save(stem.with_suffix(".png"))
        else:
            # Transparent viewport receives actual recorded motion at normal speed.
            ImageDraw.Draw(base).rectangle((480, 154, 1856, 904), fill=(0, 0, 0, 0))
            base.save(stem.with_suffix(".png"))
        destination = stem.with_suffix(".mp4")
        common = ["-an", "-c:v", "libx264", "-preset", "fast", "-b:v", "10M", "-maxrate", "12M", "-bufsize", "20M",
                  "-profile:v", "high", "-level:v", "4.0", "-pix_fmt", "yuv420p", "-r", "30", "-frames:v", str(frames)]
        if args.reuse_shots and destination.exists():
            pass
        elif isinstance(source_time, (int, float)):
            x, y, w, h = crop
            filters = (f"[0:v]crop={w}:{h}:{x}:{y},scale=1376:750:force_original_aspect_ratio=decrease,"
                       f"pad=1376:750:(ow-iw)/2:(oh-ih)/2:color=0x0c1d24,setsar=1[ui];"
                       f"color=c=0x0c1d24:s=1920x1080:r=30[bg];[bg][ui]overlay=480:154[scene];"
                       f"[scene][1:v]overlay=0:0,format=yuv420p[v]")
            run("ffmpeg", "-v", "error", "-y", "-ss", source_time, "-i", source, "-loop", "1", "-i", stem.with_suffix(".png"),
                "-filter_complex", filters, "-map", "[v]", *common, destination)
        else:
            # A small push gives still captures motion without inventing app behavior.
            run("ffmpeg", "-v", "error", "-y", "-loop", "1", "-i", stem.with_suffix(".png"),
                "-vf", f"scale=2400:1350,zoompan=z='1+0.009*(1-exp(-on/4))+0.006*on/{frames}':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=1:s=1920x1080:fps=30,setsar=1",
                *common, destination)
        timeline.append({"start": chapter["start"] + prior, "duration": duration, "chapter": chapter_index,
                         "headline": headline.replace("\n", " "), "source": str(source.relative_to(ROOT)), "source_time": source_time})
        print(f"Rendered {shot_index + 1}/{len(shots)}: {headline.replace(chr(10), ' ')}", flush=True)
    concat = work / "concat.txt"
    concat.write_text("".join(f"file '{(work / f'shot-{i:02d}.mp4').as_posix()}'\n" for i in range(len(shots))))
    clean = work / "clean.mp4"
    run("ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", concat, "-c", "copy", clean)

    report = json.loads((audio / "voice-report.json").read_text())
    inputs, filters, tracks, subtitles, subtitle_index = [], [], [], [], 1
    for i, chapter in enumerate(story["chapters"]):
        inputs.extend(["-i", audio / f"voice-{i:02d}.wav"])
        available = chapter["end"] - chapter["start"] - .25
        speed = max(1, report[i]["duration"] / available)
        if speed > 1.15:
            raise ValueError("Voice does not fit its chapter; rewrite the script")
        filters.append(f"[{i}:a]atempo={speed},aresample=48000,adelay={round((chapter['start']+.15)*1000)}:all=1[a{i}]")
        tracks.append(f"[a{i}]")
        speech_duration = report[i]["duration"] / speed
        phrases = textwrap.wrap(chapter["narration"].replace("A I", "AI"), width=62)
        full = "\n".join(phrases)
        subtitles.append((subtitle_index, chapter["start"]+.1, chapter["start"]+.2+speech_duration, full))
        subtitle_index += 1
    filters.append("".join(tracks) + f"amix=inputs=7:normalize=0,apad,atrim=0:{story['duration']},loudnorm=I=-17:TP=-2:LRA=8[vo]")
    voice = output / ("voiceover-30s.wav" if args.short else "voiceover-45s.wav")
    run("ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", ";".join(filters), "-map", "[vo]", "-ar", "48000", voice)

    def timestamp(value):
        ms = round(value * 1000)
        return f"{ms // 3600000:02}:{ms // 60000 % 60:02}:{ms // 1000 % 60:02},{ms % 1000:03}"

    srt = output / ("captions-30s.srt" if args.short else "captions-45s.srt")
    srt.write_text("\n\n".join(f"{i}\n{timestamp(start)} --> {timestamp(end)}\n{value}" for i,start,end,value in subtitles) + "\n")
    # Caption PNGs avoid a dependency on an ffmpeg build with libfreetype/libass.
    overlays, overlay_filters, previous = [], [], "[0:v]"
    for j, (_, start, end, value) in enumerate(subtitles):
        image = Image.new("RGBA", (1920,1080))
        d = ImageDraw.Draw(image)
        font = ImageFont.truetype(FONT, 28)
        bounds = d.multiline_textbbox((0,0),value,font=font,spacing=5)
        d.multiline_text(((1920-(bounds[2]-bounds[0]))/2, 978),value,font=font,fill=WHITE,spacing=5,align="center")
        caption = work / f"subtitle-{j}.png"
        image.save(caption)
        overlays.extend(["-loop", "1", "-i", caption])
        output_label = f"[v{j}]"
        overlay_filters.append(f"{previous}[{j+3}:v]overlay=0:0:enable='between(t,{start},{end})'{output_label}")
        previous = output_label
    mix = ("[1:a]asplit=2[voice][side];[2:a]volume=0.36[music];"
           "[music][side]sidechaincompress=threshold=0.06:ratio=4:attack=8:release=180[duck];"
           "[voice][duck]amix=inputs=2:normalize=0,loudnorm=I=-16:TP=-1.5:LRA=8,aformat=channel_layouts=stereo[mix]")
    final = output / ("herbot-bot-preview-30s.mp4" if args.short else "herbot-bot-feature-film-45s.mp4")
    run("ffmpeg", "-v", "error", "-y", "-i", clean, "-i", voice, "-i", audio / "original-pulse-bed.wav", *overlays,
        "-filter_complex", ";".join(overlay_filters+[mix]), "-map", previous, "-map", "[mix]", "-t", story["duration"],
        "-c:v", "libx264", "-preset", "fast", "-b:v", "10M", "-maxrate", "12M", "-bufsize", "20M",
        "-profile:v", "high", "-level:v", "4.0", "-pix_fmt", "yuv420p", "-r", "30",
        "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2", "-movflags", "+faststart", final)
    (work / "timeline.json").write_text(json.dumps(timeline,indent=2)+"\n")
    result = subprocess.check_output(["ffprobe","-v","error","-show_format","-show_streams","-of","json",str(final)])
    final.with_suffix(".json").write_bytes(result)
    run("ffmpeg", "-v", "error", "-y", "-ss", "5", "-i", final, "-frames:v", "1", "-q:v", "2", final.with_suffix(".jpg"))
    print(final, flush=True)


if __name__ == "__main__":
    main()
