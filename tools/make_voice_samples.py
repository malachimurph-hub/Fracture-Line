#!/usr/bin/env python3
"""Build short listening samples (mp3) from the generated voice lines -> builds/m2_5/voice_samples."""
import os, subprocess, tempfile
ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "..", "builds", "m2_5", "voice_samples")
A = os.path.join(ROOT, "audio", "voice_ai")
SAMPLES = {
    "tpla_announcer": ["announcer_tpla/battle_start_1", "announcer_tpla/base_under_attack_1", "announcer_tpla/unit_ready_1", "announcer_tpla/construction_complete_1", "announcer_tpla/victory_1"],
    "tpla_militia": ["tpla/militia/select_1", "tpla/militia/move_3", "tpla/militia/attack_1", "tpla/militia/under_fire_1", "tpla/militia/created_1"],
    "tpla_rattler": ["tpla/rattler/select_1", "tpla/rattler/move_3", "tpla/rattler/attack_2", "tpla/rattler/created_1"],
    "tpla_scrapback_rocket_cell": ["tpla/scrapback/select_1", "tpla/scrapback/move_3", "tpla/scrapback/attack_1", "tpla/rocket_cell/select_1", "tpla/rocket_cell/attack_3", "tpla/rocket_cell/under_fire_1"],
    "us_announcer": ["announcer_us/battle_start_1", "announcer_us/unit_ready_1", "announcer_us/air_support_1", "announcer_us/base_under_attack_1", "announcer_us/victory_1"],
    "us_soldiers": ["us/grunt/select_3", "us/grunt/attack_2", "us/jtac/attack_3", "us/javelin/attack_2", "us/halberd/attack_1", "us/wraith/attack_1", "us/sniper/attack_3"],
}
if os.environ.get("FL_SAMPLES") == "v2":   # M2.5 TPLA v2 retune (Arabic-rule prompts)
    SAMPLES = {
        "tpla_announcer_v2": ["announcer_tpla/battle_start_1", "announcer_tpla/enemy_power_detected_1", "announcer_tpla/unit_ready_1",
                              "announcer_tpla/construction_complete_1", "announcer_tpla/insufficient_funds_1", "announcer_tpla/victory_1"],
        "tpla_rattler_v2": ["tpla/rattler/select_1", "tpla/rattler/move_3", "tpla/rattler/attack_1", "tpla/rattler/attack_3", "tpla/rattler/created_1"],
        "tpla_hailstorm_v2": ["tpla/hailstorm/select_2", "tpla/hailstorm/move_1", "tpla/hailstorm/attack_1", "tpla/hailstorm/attack_3", "tpla/hailstorm/under_fire_2"],
    }
os.makedirs(OUT, exist_ok=True)
with tempfile.TemporaryDirectory() as td:
    gap = os.path.join(td, "gap.wav")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "anullsrc=r=48000:cl=mono", "-t", "0.4", gap], check=True)
    for name, parts in SAMPLES.items():
        lst = os.path.join(td, name + ".txt")
        with open(lst, "w") as fh:
            for i, p in enumerate(parts):
                w = os.path.join(td, f"{name}_{i}.wav")
                subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", os.path.join(A, p + ".ogg"), "-ac", "1", "-ar", "48000", w], check=True)
                fh.write(f"file '{w}'\nfile '{gap}'\n")
        dst = os.path.join(OUT, name + ".mp3")
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c:a", "libmp3lame", "-q:a", "3", dst], check=True)
        print(os.path.abspath(dst))
