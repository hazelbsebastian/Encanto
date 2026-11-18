# Regenerates every HD (smooth, non-pixel) asset. The older pixel-art
# generators (gen_player.py, gen_enemies.py, ...) are kept for reference only.
import subprocess, os
import gen_audio, gen_maps_hd, gen_sprites_hd, gen_portraits, gen_audio_more

gen_audio.generate()
gen_maps_hd.generate()
for group in gen_sprites_hd.GROUPS.values():
    group()
for name, fn in gen_portraits.CARDS.items():
    fn().save(gen_portraits.path("puzzles", f"portrait_{name}.png"))
# voice lines: Windows TTS -> voice_raw/, then post-processed with the rest
here = os.path.dirname(os.path.abspath(__file__))
subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", os.path.join(here, "gen_voice_tts.ps1")], check=False)
gen_audio_more.voices()
gen_audio_more.sfx()
gen_audio_more.ambience()
gen_audio_more.music()
print("ALL ASSETS GENERATED")
