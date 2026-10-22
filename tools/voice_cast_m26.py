#!/usr/bin/env python3
"""M2.6 voice cast: one clearly distinct, all-male character per unit (announcers may be female).

Malachi (M2.5 feedback): "most voices sound too similar" -> every unit now differs in speaker
(Kokoro-82M male style blend, Apache-2.0), accent (tools/accent_eu.py rules: EU = European
first languages; US = General American, Southern for a few old hands; TPLA = Arabic / Persian
rules from tools/accent_tts.py), pitch (rubberband, natural male range, formants shifted with it
for "bigger" men or preserved), pace, and a grit profile (FX below: saturation, intercom /
helmet / oxygen-mask colour, vocal roughness, breath) applied before the faction radio.

Fields: v = Kokoro blend, acc = accent kind, s = accent strength (0..1), st = pitch semitones,
fmt = 'shift' (formants follow pitch: bigger / smaller man) or 'keep', spd = speed,
fx = FX profile, rough = vocal roughness 0..0.4 (gravel), lufs = loudness target.
TPLA: engine 'kokoro' (licence-clean baseline) or 'chatterbox' with a Kokoro prompt (pv)."""

# ffmpeg chains run on the dry voice before the faction radio (tools/import_voice.py).
FX = {
    "clean":    "",
    "grit":     "volume=4dB,asoftclip=type=tanh:threshold=0.7",
    "gruff":    "equalizer=f=450:t=q:w=1:g=3,equalizer=f=2400:t=q:w=1:g=2,volume=7dB,asoftclip=type=atan:threshold=0.55",
    "shout":    "equalizer=f=2200:t=q:w=1.2:g=4,volume=9dB,asoftclip=type=tanh:threshold=0.45",
    "intercom": "highpass=f=380,lowpass=f=2700,equalizer=f=900:t=q:w=1:g=3,volume=7dB,asoftclip=type=atan:threshold=0.5,acrusher=bits=12:mix=0.12:mode=log",
    "helmet":   "equalizer=f=1500:t=q:w=1:g=3,equalizer=f=300:t=q:w=1:g=-4,volume=4dB,asoftclip=type=tanh:threshold=0.7",
    "mask":     "equalizer=f=1100:t=q:w=0.8:g=6,equalizer=f=2700:t=q:w=1:g=-5,aecho=0.8:0.5:2.5:0.3,volume=4dB,asoftclip=type=tanh:threshold=0.65",
    "close":    "equalizer=f=170:t=q:w=1:g=3,equalizer=f=3200:t=q:w=1:g=-2,acompressor=threshold=-26dB:ratio=3:attack=10:release=150",
    "bullhorn": "highpass=f=500,lowpass=f=3400,equalizer=f=1800:t=q:w=0.7:g=6,volume=8dB,asoftclip=type=atan:threshold=0.5",
}

EU = {"lang": "en-gb", "units": {
    "eu_crawler":   [dict(v="bm_george:0.5,am_fenrir:0.5", acc="de", s=0.6, st=-2.0, fmt="shift", spd=0.9, fx="gruff", rough=0.18,
                          who="Gruff German combat engineer, dry humour")],
    "eu_harvester": [dict(v="em_alex:0.7,bm_lewis:0.3", acc="es", s=0.6, st=0.5, fmt="keep", spd=1.02, fx="grit", rough=0.05,
                          who="Upbeat Spanish supply driver")],
    "eu_grenadier": [dict(v="bm_daniel:0.6,pm_alex:0.4", acc="fr", s=0.7, st=-0.8, fmt="shift", spd=1.06, fx="shout", rough=0.12,
                          who="French squad sergeant, clipped and hard"),
                     dict(v="bm_lewis:0.5,im_nicola:0.5", acc="fr", s=0.5, st=0.6, fmt="keep", spd=1.08, fx="shout", rough=0.08,
                          who="Younger French grenadier")],
    "eu_lancer":    [dict(v="am_liam:0.5,bm_fable:0.5", acc="pl", s=0.7, st=-1.0, fmt="keep", spd=0.98, fx="grit", rough=0.1,
                          who="Calm, cocky Polish anti-tank gunner")],
    "eu_wolfhound": [dict(v="im_nicola:0.8,am_puck:0.2", acc="it", s=0.75, st=0.8, fmt="keep", spd=1.12, fx="intercom", rough=0.05,
                          who="Fast-talking Italian recon driver")],
    "eu_leopold":   [dict(v="am_onyx:0.5,bm_george:0.5", acc="de", s=0.9, st=-2.6, fmt="shift", spd=0.86, fx="intercom", rough=0.3,
                          who="Rough veteran German tank commander, measured and heavy")],
    "eu_aegis":     [dict(v="bm_fable:0.6,am_eric:0.4", acc="nl", s=0.75, st=0.3, fmt="keep", spd=0.97, fx="clean", rough=0.0,
                          who="Precise, calm Dutch systems operator")],
    "eu_flakwerk":  [dict(v="am_echo:0.5,bm_lewis:0.5", acc="sv", s=0.75, st=-0.6, fmt="shift", spd=1.04, fx="grit", rough=0.08,
                          who="Sharp, watchful Swedish air-defence gunner")],
}}

US = {"lang": "en-us", "units": {
    "us_dozer":        [dict(v="am_michael:0.5,am_santa:0.5", acc="south", s=0.6, st=-1.2, fmt="shift", spd=0.9, fx="grit", rough=0.15,
                             who="Easygoing Southern Seabee operator")],
    "us_supply_truck": [dict(v="am_eric:0.6,am_puck:0.4", acc="none", s=0, st=0.6, fmt="keep", spd=0.95, fx="grit", rough=0.03,
                             who="Laid-back motor-pool driver")],
    "us_grunt":        [dict(v="am_adam:0.6,am_fenrir:0.4", acc="none", s=0, st=-1.2, fmt="shift", spd=1.1, fx="shout", rough=0.16,
                             who="Tough Marine rifleman, barked"),
                        dict(v="am_puck:0.7,am_liam:0.3", acc="none", s=0, st=0.4, fmt="keep", spd=1.12, fx="shout", rough=0.1,
                             who="Young Marine rifleman"),
                        dict(v="am_liam:0.6,am_onyx:0.4", acc="south", s=0.3, st=-0.6, fmt="shift", spd=1.08, fx="shout", rough=0.14,
                             who="Marine rifleman, Southern")],
    "us_javelin":      [dict(v="am_echo:0.6,am_michael:0.4", acc="none", s=0, st=-0.4, fmt="keep", spd=1.0, fx="grit", rough=0.06,
                             who="Calm Javelin gunner"),
                        dict(v="am_liam:0.7,am_eric:0.3", acc="none", s=0, st=0.3, fmt="keep", spd=1.04, fx="grit", rough=0.06,
                             who="Assistant gunner, quicker")],
    "us_jtac":         [dict(v="am_michael:0.8,am_echo:0.2", acc="none", s=0, st=0.0, fmt="keep", spd=1.02, fx="helmet", rough=0.0,
                             who="Unflappable JTAC, textbook radio procedure")],
    "us_sniper":       [dict(v="am_onyx:0.7,am_echo:0.3", acc="none", s=0, st=-1.6, fmt="keep", spd=0.84, fx="close", rough=0.08, lufs=-19,
                             who="Calm, quiet scout sniper, almost a murmur")],
    "us_lynx":         [dict(v="am_puck:0.6,am_adam:0.4", acc="none", s=0, st=1.0, fmt="keep", spd=1.14, fx="intercom", rough=0.04,
                             who="Cocky, fast light-vehicle crew")],
    "us_halberd":      [dict(v="am_fenrir:0.6,am_onyx:0.4", acc="south", s=0.5, st=-3.0, fmt="shift", spd=0.86, fx="intercom", rough=0.32,
                             who="Rough veteran tank commander, gravel voice")],
    "us_picket":       [dict(v="am_liam:0.5,am_eric:0.5", acc="none", s=0, st=0.6, fmt="keep", spd=1.06, fx="helmet", rough=0.0,
                             who="Crisp, alert air-defence gunner")],
    "us_longreach":    [dict(v="am_adam:0.5,am_santa:0.5", acc="none", s=0, st=-1.6, fmt="shift", spd=0.95, fx="bullhorn", rough=0.2,
                             who="Loud, half-deaf artillery section chief")],
    "us_harrier":      [dict(v="am_eric:0.6,am_echo:0.4", acc="none", s=0, st=-0.5, fmt="keep", spd=1.02, fx="helmet", rough=0.02,
                             who="Cool attack-helicopter pilot")],
    "us_wraith":       [dict(v="am_puck:0.5,am_liam:0.5", acc="none", s=0, st=0.9, fmt="keep", spd=1.12, fx="mask", rough=0.0,
                             who="Cocky fighter pilot in an oxygen mask")],
    "us_thunderlance": [dict(v="am_onyx:0.6,am_santa:0.4", acc="none", s=0, st=-2.2, fmt="shift", spd=0.86, fx="mask", rough=0.1,
                             who="Deep, deadpan bomber pilot")],
}}

# TPLA: Arabic-rule ('me') or Persian-rule without w->v ('fa2') phonemes from tools/accent_tts.py.
TPLA = {"lang": "en-us", "units": {
    "tpla_laborer":     [dict(v="am_michael:0.45,hm_psi:0.35,am_eric:0.2", acc="me", s=1, st=-0.8, fmt="keep", spd=0.95, fx="grit", rough=0.12,
                              who="Tired, wry scavenger worker")],
    "tpla_militia":     [dict(v="hm_omega:0.6,am_adam:0.4", acc="me", s=1, st=0.3, fmt="keep", spd=1.04, fx="grit", rough=0.1,
                              who="Scrappy volunteer fighter (reference voice)"),
                         dict(v="em_alex:0.5,hm_psi:0.5", acc="me", s=1, st=1.0, fmt="keep", spd=1.06, fx="grit", rough=0.08, who="Militia fighter"),
                         dict(v="pm_santa:0.5,hm_omega:0.5", acc="me", s=1, st=0.6, fmt="keep", spd=1.04, fx="grit", rough=0.12, who="Militia fighter")],
    "tpla_rocket_cell": [dict(v="am_liam:0.6,hm_psi:0.4", acc="me", s=1, st=-0.3, fmt="keep", spd=1.0, fx="grit", rough=0.08,
                              who="Wary, tense insurgent rocket team, low voice"),
                         dict(v="em_santa:0.5,hm_omega:0.5", acc="fa2", s=1, st=0.4, fmt="keep", spd=1.02, fx="grit", rough=0.1, who="Rocket loader")],
    "tpla_rattler":     [dict(v="pm_alex:0.6,am_puck:0.4", acc="me", s=1, st=1.2, fmt="keep", spd=1.12, fx="shout", rough=0.12,
                              who="Reckless grinning technical driver")],
    "tpla_hailstorm":   [dict(v="am_michael:0.5,hm_omega:0.5", acc="fa2", s=1, st=-1.0, fmt="shift", spd=0.98, fx="grit", rough=0.14,
                              who="Gruff heavy gunner on the quad gun")],
    "tpla_scrapback":   [dict(v="em_santa:0.5,am_fenrir:0.5", acc="me", s=1, st=-2.5, fmt="shift", spd=0.88, fx="intercom", rough=0.3,
                              who="Proud, stubborn old scrap-tank commander")],
    "tpla_shrike":      [dict(v="im_nicola:0.5,hm_psi:0.5", acc="me", s=1, st=1.5, fmt="keep", spd=1.14, fx="grit", rough=0.04,
                              who="Cocky young buggy driver")],
    "tpla_mule":        [dict(v="am_onyx:0.5,hm_psi:0.5", acc="fa2", s=1, st=-1.5, fmt="keep", spd=0.88, fx="close", rough=0.06,
                              who="Unnervingly calm demolition driver")],
    "tpla_blight":      [dict(v="hm_omega:0.7,bm_fable:0.3", acc="fa2", s=1, st=-0.5, fmt="keep", spd=0.86, fx="close", rough=0.05, lufs=-18,
                              who="Quiet, eerie chemist-gunner")],
}, "announcer": [dict(v="hm_omega:0.5,am_michael:0.5", acc="me", s=1, st=-1.0, fmt="shift", spd=0.95, fx="clean", rough=0.04,
                      who="TPLA underground radio voice, warm and defiant")]}

CAST = {"eu": EU, "us": US, "tpla": TPLA}

# per-event delivery: (extra semitones, speed factor, extra roughness)
EVENT_MOD = {"select": (0.0, 1.0, 0.0), "move": (0.0, 1.05, 0.0), "attack": (0.4, 1.08, 0.04),
             "under_fire": (0.9, 1.15, 0.06), "created": (0.0, 1.0, 0.0), "veteran": (-0.2, 0.97, 0.0),
             "build": (0.0, 1.0, 0.0), "harvest": (0.0, 1.0, 0.0), "garrison": (0.2, 1.06, 0.0)}

def check_male():
    for f, c in CAST.items():
        for uid, actors in c["units"].items():
            for a in actors:
                for part in a["v"].split(","):
                    n = part.split(":")[0]
                    assert n[1] == "m", (uid, a)
                assert -3.5 <= a["st"] <= 1.6, ("pitch outside natural male range", uid, a)

check_male()
