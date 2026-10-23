#!/usr/bin/env python3
"""M2.9 TPLA voices for the new / renamed units, in the M2.5 Militia style (Malachi's reference):
Chatterbox Multilingual (MIT) cloning the Militia's Piper-Persian-derived male prompts with the
Arabic language token (Middle Eastern accent), via the M2.7 intensity renderer (Whisper QA + retakes,
radio chain). Combat events (attack / under_fire) are shouted; calm events less exaggerated.

  nohup /workspace/tools/tts/venv_cb/bin/python tools/gen_voices_m29.py [unit ...] [--jobs 2] &
Writes audio/voice_ai/tpla/<folder>/<event>_<n>.ogg and tools/voice_qa_m29.json."""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_voices_intensity_m27 as m27
import import_voice as iv
# calm events for the new sets: (exaggeration, cfg, words/s, loudness offset, gravel)
m27.INTENSITY.update({"select": (0.6, 0.5, 2.6, 0.0, 0.0), "move": (0.75, 0.45, 2.9, 1.0, 0.0),
                      "created": (0.65, 0.5, 2.6, 0.0, 0.0), "veteran": (0.8, 0.4, 2.8, 1.5, 0.0),
                      "garrison": (0.65, 0.5, 2.7, 0.0, 0.0), "build": (0.6, 0.5, 2.6, 0.0, 0.0),
                      "harvest": (0.6, 0.5, 2.6, 0.0, 0.0)})
ROOT = iv.ROOT
REP = os.path.join(ROOT, "tools", "voice_qa_m29.json")
A = lambda v, s: {"v": v, "shift": s, "exag": 0.6}
# uid: (folder, actor, {event: [lines]})
UNITS = {
 "tpla_scrapback": ("striker", A("ganji", -2.0), {
   "select": ["Striker ready.", "Striker. Armor is up.", "This is Striker. Give me a target."],
   "move": ["Striker moving!", "Tracks rolling, going now!"],
   "attack": ["Striker, fire! Fire!", "Main gun, kill that tank!", "Hit them! Burn them down!"],
   "under_fire": ["We are hit! Armor holding!", "They are on us! Turn the turret!"],
   "created": ["The Striker is ready for war."], "veteran": ["Striker crew has blood on the tracks!"]}),
 "tpla_rattler": ("technical", A("reza", 1.5), {
   "select": ["Technical here.", "Technical. Gun is loaded.", "Yes? The fifty is ready."],
   "move": ["Technical moving! Drive!", "Go, go, hit the gas!"],
   "attack": ["Open fire! Fifty cal, shoot!", "Light them up! Shoot!", "Kill them all, keep firing!"],
   "under_fire": ["They hit the truck! Drive, drive!", "Taking fire! Get us out!"],
   "created": ["Technical ready. Let us ride."], "veteran": ["This Technical never stops!"]}),
 "tpla_hailstorm": ("bhx35", A("amir", -1.5), {
   "select": ["BHX thirty five.", "Air defense ready. Radar is up.", "BHX. Sky is ours."],
   "move": ["BHX moving!", "Relocating the guns, now!"],
   "attack": ["Aircraft! Fire, fire!", "Thirty five, shred them in the sky!", "Shoot them down! Now!"],
   "under_fire": ["We are hit! Keep the radar up!", "They found us! Return fire!"],
   "created": ["BHX thirty five online."], "veteran": ["No aircraft escapes the BHX!"]}),
 "tpla_shrike": ("fajr", A("ganji", 2.0), {
   "select": ["Fajr launcher.", "Fajr ready. Tubes are full.", "Rockets loaded. Where?"],
   "move": ["Fajr moving!", "Moving the launcher, go!"],
   "attack": ["Fajr, launch! Launch all!", "Rockets away! Burn it!", "Fire the salvo! Now!"],
   "under_fire": ["They are hitting the launcher! Move!", "We are hit! Save the rockets!"],
   "created": ["Fajr rocket launcher ready."], "veteran": ["The Fajr rains fire!"]}),
 "tpla_blight": ("koksan", A("amir", 1.5), {
   "select": ["Koksan gun.", "Koksan ready. Give coordinates.", "Heavy gun here."],
   "move": ["Koksan moving.", "Pack the gun, we move!"],
   "attack": ["Koksan, fire! Fire the big gun!", "Shell away! Hit them hard!", "Bring the thunder! Fire!"],
   "under_fire": ["They found the gun! Protect it!", "Taking fire! Move the Koksan!"],
   "created": ["Koksan heavy gun ready."], "veteran": ["The Koksan shakes the earth!"]}),
 "tpla_bus": ("bmp2", A("reza", 0.0), {
   "select": ["BMP two.", "BMP ready. Men inside.", "Transport ready."],
   "move": ["BMP moving!", "Rolling out, hold on!"],
   "attack": ["Cannon, fire! Fire!", "Thirty mil, hit them!", "Shoot! Keep shooting!"],
   "under_fire": ["We are hit! Armor holding!", "Taking fire! Protect the men!"],
   "created": ["BMP two ready to roll."], "veteran": ["This BMP fears nothing!"]}),
 "tpla_rocket_cell": ("rocket_man", A("ganji", 1.0), {
   "select": ["Rocket Man.", "Rocket ready.", "RPG loaded. Show me the tank."],
   "move": ["Moving!", "Going, keep low!"],
   "attack": ["RPG! Fire!", "Rocket away! Kill the tank!", "Hit it! Hit it again!"],
   "under_fire": ["They are shooting at me! Cover!", "Taking fire! Reload, reload!"],
   "created": ["Rocket Man ready."], "veteran": ["Every rocket finds a tank!"], "garrison": ["Inside. Rockets ready at the window."]}),
 "tpla_marksman": ("marksman", A("amir", 0.5), {
   "select": ["Marksman.", "Eyes on.", "I see everything."],
   "move": ["Moving quiet.", "Changing position."],
   "attack": ["Target down! Next!", "One shot, one kill!", "Fire! Drop him!"],
   "under_fire": ["They spotted me! Move!", "I am hit! Find cover!"],
   "created": ["Marksman ready. Rifle zeroed."], "veteran": ["My rifle never misses!"], "garrison": ["Window taken. I watch the street."]}),
 "tpla_insurgent": ("insurgent", A("reza", 2.0), {
   "select": ["Yes?", "I am here. No one sees me.", "Insurgent. Ready."],
   "move": ["I go.", "Moving through the streets."],
   "attack": ["Now! Strike!", "Go, go, attack!", "For the cause!"],
   "under_fire": ["They see me! Run!", "I am spotted! Scatter!"],
   "created": ["Insurgent ready. Like a shadow."], "veteran": ["They never see me coming!"], "garrison": ["Inside. I hide with the people."]}),
 "tpla_backhoe": ("backhoe", A("ganji", -1.5), {
   "select": ["Backhoe.", "Ready to dig.", "What do we build?"],
   "move": ["Backhoe moving.", "Going there."],
   "build": ["I will build it.", "Digging now. It will be strong."],
   "under_fire": ["They shoot at the backhoe! Help!", "Taking fire! I am only a digger!"],
   "created": ["Backhoe ready to work."]}),
 "tpla_pickup": ("pickup", A("reza", -1.0), {
   "select": ["Supply pickup.", "Pickup ready.", "Load the cargo?"],
   "move": ["Pickup moving.", "Driving now."],
   "harvest": ["Loading supplies.", "Taking the cargo home."],
   "under_fire": ["They hit the pickup! Drive!", "Taking fire! Save the supplies!"],
   "created": ["Supply pickup ready."]}),
 "tpla_mirage": ("mirage", A("amir", 1.0), {
   "select": ["Mirage pilot.", "Mirage ready. Engines hot.", "Mirage. Give me a target."],
   "move": ["Mirage moving!", "Turning now!"],
   "attack": ["Missiles away! Fire!", "Mirage, attack! Hit them!", "Rockets! Burn them!"],
   "under_fire": ["I am hit! Mirage is hit!", "Missile lock! Break, break!"],
   "created": ["Mirage fighter ready."], "veteran": ["The Mirage owns the sky!"]}),
 "tpla_mig29": ("mig29", A("ganji", 0.5), {
   "select": ["Fulcrum here.", "MiG ready. Weapons hot.", "Fulcrum. Where is the enemy?"],
   "move": ["Fulcrum moving!", "Climbing now!"],
   "attack": ["Missile away! Kill him!", "Fulcrum, engage! Shoot him down!", "Fox two! Fire!"],
   "under_fire": ["They are on my tail! Help!", "I am hit! Fulcrum hit!"],
   "created": ["Fulcrum interceptor ready."], "veteran": ["The Fulcrum hunts them all!"]}),
 "tpla_f16": ("f16", A("reza", -0.5), {
   "select": ["Falcon here.", "Falcon ready. Bombs loaded.", "Falcon. Show me the target."],
   "move": ["Falcon moving!", "On my way!"],
   "attack": ["Bombs away! Bombs away!", "Falcon, attack! Destroy it!", "Drop everything! Now!"],
   "under_fire": ["Flak! I am hit!", "They are shooting at me! Pull up!"],
   "created": ["Falcon bomber ready."], "veteran": ["The Falcon brings the fire!"]}),
}

def render(job):
    r = m27.render(job)
    return r

def jobs(units):
    js = []
    for uid in units:
        folder, actor, says = UNITS[uid]
        rel = "tpla/" + folder
        for ev, lines in says.items():
            for n, text in enumerate(lines, 1):
                dst = os.path.join(ROOT, "audio", "voice_ai", rel, f"{ev}_{n}.ogg")
                # uid "tpla_militia" selects the M2.5 Militia Chatterbox prompt path in the renderer
                js.append(("tpla", "tpla_militia", rel, ev, n, text, f"{folder}_{ev}_{n}", dst, actor, folder, True, iv.style_for(rel)))
    return js

def main(argv):
    arg = lambda k, d=None: argv[argv.index(k) + 1] if k in argv else d
    units = [a for a in argv if a in UNITS] or list(UNITS)
    rep = {r["file"]: r for r in (json.load(open(REP)) if os.path.exists(REP) else [])}
    js = [j for j in jobs(units) if os.path.relpath(j[7], ROOT) not in rep]
    print("lines to render:", len(js), flush=True)
    import multiprocessing as mp
    with mp.get_context("spawn").Pool(int(arg("--jobs", 2)), maxtasksperchild=8) as pool:
        for r in pool.imap_unordered(render, js):
            folder = r["file"].split("/")[3]
            r["unit"] = next(u for u, v in UNITS.items() if v[0] == folder)
            a = UNITS[r["unit"]][1]
            r["voice"] = "chatterbox/%s%+.1fst/ar-v2" % (a["v"], a["shift"])
            rep[r["file"]] = r
            print("%-48s %.2f t%d %r" % (r["file"], r["qa"], r["take"], r["heard"]), flush=True)
            json.dump(sorted(rep.values(), key=lambda x: x["file"]), open(REP + ".tmp", "w"), indent=0)
            os.replace(REP + ".tmp", REP)
    print("=== M29 VOICES DONE", len(rep), flush=True)

if __name__ == "__main__":
    main(sys.argv[1:])
