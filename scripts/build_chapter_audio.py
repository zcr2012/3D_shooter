"""Original layered procedural effects, not licensed field recordings or music."""
import math,random,wave,struct,pathlib,json,hashlib
ROOT=pathlib.Path(__file__).resolve().parents[1];OUT=ROOT/'godot_project/assets/audio/sfx';OUT.mkdir(parents=True,exist_ok=True)
RATE=22050
rng=random.Random(90427)
def noise_signal(seconds):return [rng.uniform(-1,1) for _ in range(int(RATE*seconds))]
def save(name,samples):
 peak=max(.01,max(abs(s) for s in samples));pcm=b''.join(struct.pack('<h',int(max(-1,min(1,s/peak*.65))*32767)) for s in samples)
 with wave.open(str(OUT/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(pcm)
base=noise_signal(.7);low=0;gun=[]
for i,n in enumerate(base):
 t=i/RATE;low=.86*low+.14*n
 gun.append(n*math.exp(-t*95)*.65+math.sin(2*math.pi*74*t)*math.exp(-t*29)*.35+low*math.exp(-t*12)*.22)
save('carbine_dry',gun)
room=gun.copy()
for delay,gain in [(.032,.24),(.069,.17),(.13,.12),(.21,.07)]:
 shift=int(delay*RATE)
 for i in range(shift,len(room)):room[i]+=gun[i-shift]*gain
save('carbine_room',room)
for name,freq,decay,seconds in [('footstep',95,35,.20),('magazine',940,60,.23),('terminal',880,8,.35),('hurt',120,18,.24)]:
 out=[]
 for i,n in enumerate(noise_signal(seconds)):
  t=i/RATE
  out.append((math.sin(math.tau*freq*t)*(.75 if name=='terminal' else .24)+n*.4)*math.exp(-t*decay))
 save(name,out)
# Deterministic low wind and generator bed; crossfade ends for a quiet seamless loop.
out=[];low=0
for i,n in enumerate(noise_signal(12)):
 t=i/RATE;low=.995*low+.005*n
 out.append(low*.55+math.sin(math.tau*55*t)*.007*(.8+.2*math.sin(math.tau*t/12)))
fade=int(RATE*.4)
for i in range(fade):
 f=i/fade;v=out[i]*f+out[-fade+i]*(1-f);out[i]=v;out[-fade+i]=v
save('dock_ambience',out)
records={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.glob('*.wav'))}
(OUT/'manifest.json').write_text(json.dumps({'source':'Original deterministic synthesis; scripts/build_chapter_audio.py','sample_rate':RATE,'files':records},indent=2))
