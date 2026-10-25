#!/usr/bin/env python3
"""M3.0 F Russia voices: male soldiers with a Russian accent. Chatterbox Multilingual (MIT) cloning
the M2.9 Piper-derived male prompts (new pitch shifts, so they are new speakers) with the Russian
language token, via the M2.7 intensity renderer (Whisper QA + retakes, radio chain). Lines never say
a unit, faction or nation name.

  nohup /workspace/tools/tts/venv_cb/bin/python tools/gen_voices_m30_ru.py [unit ...] [--jobs 2] &
Writes audio/voice_ai/ecc/<folder>/<event>_<n>.ogg and tools/voice_qa_m30_ru.json."""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_voices_intensity_m27 as m27
import import_voice as iv
m27.INTENSITY.update({"select": (0.6, 0.5, 2.6, 0.0, 0.0), "move": (0.75, 0.45, 2.9, 1.0, 0.0),
                      "created": (0.65, 0.5, 2.6, 0.0, 0.0), "veteran": (0.8, 0.4, 2.8, 1.5, 0.0),
                      "garrison": (0.65, 0.5, 2.7, 0.0, 0.0), "build": (0.6, 0.5, 2.6, 0.0, 0.0),
                      "harvest": (0.6, 0.5, 2.6, 0.0, 0.0)})
ROOT = iv.ROOT
REP = os.path.join(ROOT, "tools", "voice_qa_m30_ru.json")
A = lambda v, s: {"v": v, "shift": s, "exag": 0.6, "lang": "ru"}
UNITS = {
 "ecc_engineer": ("engineer", A("amir", -3.0), {
   "select": ["Engineers here.", "What do we build?"], "move": ["Moving out.", "On our way."],
   "build": ["We build it. Strong.", "Starting work now."], "under_fire": ["Taking fire! Cover the engineers!"],
   "created": ["Engineers ready to work."]}),
 "ecc_cargo_truck": ("cargo_truck", A("reza", -2.0), {
   "select": ["Truck ready.", "Where to, comrade?"], "move": ["Driving."],
   "harvest": ["Loading supplies.", "Cargo going home."], "under_fire": ["They hit the truck! Drive!"],
   "created": ["Cargo truck ready."]}),
 "ecc_rifleman": ("rifleman", A("ganji", -1.0), {
   "select": ["Ready.", "Yes, comrade?"], "move": ["Moving.", "Forward!"],
   "attack": ["Open fire!", "Fire! Fire!"], "under_fire": ["Contact! Take cover!"],
   "created": ["Rifleman reporting."], "veteran": ["We know this war now."], "garrison": ["Inside. Holding."]}),
 "ecc_machine_gunner": ("machine_gunner", A("amir", -1.0), {
   "select": ["Machine gun ready.", "Belt is loaded."], "move": ["Moving the gun."],
   "attack": ["Suppressing fire!", "Keep them down!"], "under_fire": ["Under fire! Changing belt!"],
   "created": ["Machine gunner ready."], "veteran": ["Nothing gets past my gun."], "garrison": ["Gun in the window."]}),
 "ecc_rpg": ("rpg", A("reza", 0.5), {
   "select": ["Rocket ready.", "Show me the tank."], "move": ["Going, keep low."],
   "attack": ["Rocket away!", "Hit the armour!"], "under_fire": ["They see me! Reloading!"],
   "created": ["Anti-tank soldier ready."], "veteran": ["Every rocket finds a tank."], "garrison": ["Window taken."]}),
 "ecc_infiltrator": ("infiltrator", A("ganji", -2.5), {
   "select": ["Quietly.", "I am listening."], "move": ["Moving in silence."],
   "attack": ["Grenade out!", "Eliminate them."], "under_fire": ["I am spotted. Changing position."],
   "created": ["Special operator ready."], "veteran": ["They never saw me."], "garrison": ["Inside. Watching."]}),
 "ecc_tigr": ("tigr", A("reza", 1.0), {
   "select": ["Armoured car ready.", "Gun is loaded."], "move": ["Driving fast!", "Go, go!"],
   "attack": ["Heavy gun, fire!", "Keep shooting!"], "under_fire": ["We are hit! Get us out!"],
   "created": ["Armoured car ready."], "veteran": ["Fast and deadly."]}),
 "ecc_btr": ("btr", A("amir", 0.5), {
   "select": ["Carrier ready.", "Men inside, ready."], "move": ["Rolling out!", "Wheels moving."],
   "attack": ["Cannon, fire!", "Thirty millimetre, hit them!"], "under_fire": ["We are hit! Armour holding!"],
   "created": ["Carrier ready to roll."], "veteran": ["Our crew fears nothing."]}),
 "ecc_typhoon": ("typhoon", A("ganji", 0.5), {
   "select": ["Heavy transport ready.", "Troops inside."], "move": ["Moving, hold on!"],
   "attack": ["Remote gun, fire!", "Shoot them!"], "under_fire": ["Taking fire! Protect the men!"],
   "created": ["Heavy transport ready."], "veteran": ["Nothing stops this truck."]}),
 "ecc_t90": ("t90", A("ganji", -3.5), {
   "select": ["Tank ready.", "Armour up. Give me a target."], "move": ["Tank moving!", "Tracks rolling!"],
   "attack": ["Main gun, fire!", "Kill that tank!"], "under_fire": ["We are hit! Armour holding!"],
   "created": ["Main battle tank ready."], "veteran": ["Our tank owns this field."]}),
 "ecc_msta": ("msta", A("amir", -2.0), {
   "select": ["Howitzer ready.", "Give coordinates."], "move": ["Moving the gun."],
   "attack": ["Gun, fire!", "Shell away!"], "under_fire": ["They found the gun! Protect it!"],
   "created": ["Self-propelled gun ready."], "veteran": ["Our gun shakes the earth."]}),
 "ecc_zeus": ("zeus", A("reza", -1.0), {
   "select": ["Air defence ready.", "Radar is up."], "move": ["Relocating the guns."],
   "attack": ["Aircraft! Fire, fire!", "Shoot them down!"], "under_fire": ["We are hit! Keep the radar up!"],
   "created": ["Anti-aircraft gun ready."], "veteran": ["No aircraft escapes us."]}),
 # M3.2 aircraft
 "ecc_su57": ("su57", A("ganji", 0.5), {
   "select": ["Fighter ready. Give me a target."], "move": ["Turning to heading."],
   "attack": ["Missile launched! Target is mine!"], "under_fire": ["Missile on my tail! Breaking!"]}),
 "ecc_ka52": ("ka52", A("amir", 0.5), {
   "select": ["Gunship here. Where do we hunt?"], "move": ["Moving low and fast."],
   "attack": ["Missiles away! Cannon firing!"], "under_fire": ["We are hit! Pulling back!"]}),
 "ecc_tu160": ("tu160", A("reza", -3.0), {
   "select": ["Bomber crew ready. Show us the target."], "move": ["Heavy bomber on course."],
   "attack": ["Bomb doors open! Release!"], "under_fire": ["Flak everywhere! Hold her steady!"]}),
}

def render(job):
    return m27.render(job)

# Rendered set (time budget ~20 min on CPU): one select / move / attack / under_fire line per unit
# (+ build / harvest); created, veteran and garrison reuse a rendered line (tools/integrate_voices_m30_ru.py).
CORE = ("select", "move", "attack", "under_fire", "build", "harvest")

def jobs(units):
    js = []
    for uid in units:
        folder, actor, says = UNITS[uid]
        rel = "ecc/" + folder
        for ev, lines in says.items():
            if ev not in CORE:
                continue
            for n, text in enumerate(lines[:1], 1):
                dst = os.path.join(ROOT, "audio", "voice_ai", rel, f"{ev}_{n}.ogg")
                # uid "tpla_militia" selects the M2.5 Chatterbox prompt path (Piper-derived male prompt)
                js.append(("ecc", "tpla_militia", rel, ev, n, text, f"ru_{folder}_{ev}_{n}", dst, actor, folder, True, iv.style_for(rel)))
    return js

def main(argv):
    arg = lambda k, d=None: argv[argv.index(k) + 1] if k in argv else d
    units = [a for a in argv if a in UNITS] or list(UNITS)
    rep = {r["file"]: r for r in (json.load(open(REP)) if os.path.exists(REP) else [])}
    js = [j for j in jobs(units) if os.path.relpath(j[7], ROOT) not in rep]
    lim = int(arg("--limit", 0))
    if lim:
        js = js[:lim]
    print("lines to render:", len(js), flush=True)
    import multiprocessing as mp
    with mp.get_context("spawn").Pool(int(arg("--jobs", 2)), maxtasksperchild=8) as pool:
        for r in pool.imap_unordered(render, js):
            folder = r["file"].split("/")[3]
            r["unit"] = next(u for u, v in UNITS.items() if v[0] == folder)
            a = UNITS[r["unit"]][1]
            r["voice"] = "chatterbox/%s%+.1fst/ru" % (a["v"], a["shift"])
            rep[r["file"]] = r
            print("%-48s %.2f t%d %r" % (r["file"], r["qa"], r["take"], r["heard"]), flush=True)
            json.dump(sorted(rep.values(), key=lambda x: x["file"]), open(REP + ".tmp", "w"), indent=0)
            os.replace(REP + ".tmp", REP)
    print("=== M30 RU VOICES DONE", len(rep), flush=True)

if __name__ == "__main__":
    main(sys.argv[1:])
