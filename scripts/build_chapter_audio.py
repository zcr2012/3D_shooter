"""Original layered procedural effects, not licensed field recordings or music.

Deterministic: the shared RNG is consumed in a fixed order, so re-running the script
reproduces every file byte for byte. New cues are generated after the ambience bed
so earlier files keep their hashes; the carbine shot itself gained a sharper crack,
a short mid-body and a brass casing tick at 190 ms / 270 ms (hit-feedback batch).
"""
import math,random,wave,struct,pathlib,json,hashlib
ROOT=pathlib.Path(__file__).resolve().parents[1];OUT=ROOT/'godot_project/assets/audio/sfx';OUT.mkdir(parents=True,exist_ok=True)
RATE=22050
rng=random.Random(90427)
def noise_signal(seconds):return [rng.uniform(-1,1) for _ in range(int(RATE*seconds))]
def save(name,samples):
 peak=max(.01,max(abs(s) for s in samples));pcm=b''.join(struct.pack('<h',int(max(-1,min(1,s/peak*.65))*32767)) for s in samples)
 with wave.open(str(OUT/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(pcm)
def casing_tick(t,start,gain):
 # Brass ringing partials: an ejected case landing on asphalt, folded into the shot tail.
 u=t-start
 if u<0:return 0.0
 return gain*math.exp(-u*90)*(math.sin(2*math.pi*3150*u)*.5+math.sin(2*math.pi*4700*u)*.3+math.sin(2*math.pi*6200*u)*.2)
base=noise_signal(.7);low=0;gun=[]
for i,n in enumerate(base):
 t=i/RATE;low=.86*low+.14*n
 s=n*math.exp(-t*95)*.65+math.sin(2*math.pi*74*t)*math.exp(-t*29)*.35+low*math.exp(-t*12)*.22
 s+=n*math.exp(-t*700)*.55+math.sin(2*math.pi*210*t)*math.exp(-t*60)*.18 # crack transient and mid body
 s+=casing_tick(t,.19,.11)+casing_tick(t,.27,.05)
 gun.append(s)
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

# --- Hit-feedback batch (appended so the files above keep their hashes) ---------------
def tone(f,t,decay,gain=1.0):return math.sin(math.tau*f*t)*math.exp(-t*decay)*gain
# Confirm ticks are UI-side cues played at the listener, distinct from the 3D impacts.
out=[]
for i,n in enumerate(noise_signal(.07)):
 t=i/RATE;out.append(tone(1900,t,70,.6)+n*.25*math.exp(-t*300))
save('hit_confirm',out)
out=[]
for i,n in enumerate(noise_signal(.18)):
 t=i/RATE;u=max(0.0,t-.05)
 out.append(tone(1500,t,45,.55)+(tone(950,u,40,.6) if t>=.05 else 0.0)+tone(240,t,40,.3)+n*.2*math.exp(-t*160))
save('kill_confirm',out)
out=[]
for i,n in enumerate(noise_signal(.12)):
 t=i/RATE;out.append(n*math.exp(-t*140)*.7+tone(2600,t,60,.4)+tone(3900,t,80,.2))
save('headshot',out)
# Body hit: low wet thud with a low-passed noise slap.
out=[];low=0
for i,n in enumerate(noise_signal(.14)):
 t=i/RATE;low=.7*low+.3*n
 out.append(tone(85,t,35,.7)+low*math.exp(-t*40)*.5)
save('flesh_impact',out)
# Concrete/asphalt strike: broadband crack plus a few debris ticks.
debris=[rng.uniform(.03,.12) for _ in range(4)]
out=[]
for i,n in enumerate(noise_signal(.16)):
 t=i/RATE;s=n*math.exp(-t*120)*.8+tone(1200,t,90,.15)
 for d in debris:
  u=t-d
  if u>=0:s+=tone(2200+d*9000,u,260,.12)
 out.append(s)
save('bullet_impact',out)
# Low-health heartbeat: lub-dub in a 1.15 s loop with crossfaded ends.
out=[];low=0
for i,n in enumerate(noise_signal(1.15)):
 t=i/RATE;low=.97*low+.03*n;u=max(0.0,t-.2)
 out.append(tone(55,t,22,.9)+(tone(48,u,26,.7) if t>=.2 else 0.0)+low*.06*math.exp(-t*6))
fade=int(RATE*.08)
for i in range(fade):
 f=i/fade;v=out[i]*f+out[-fade+i]*(1-f);out[i]=v;out[-fade+i]=v
save('heartbeat',out)
def godot_uid(name):
 # Same alphabet as ResourceUID::id_to_text (letters a-y, digits 0-8, base 34); derived
 # from the file name so re-running never rewrites a committed .import file.
 value=int.from_bytes(hashlib.sha256(('sfx:'+name).encode()).digest()[:8],'big')&0x7fffffffffffffff or 1
 text=''
 while value:
  value,c=divmod(value,34);text=(chr(ord('a')+c) if c<25 else chr(ord('0')+c-25))+text
 return 'uid://'+text
def write_import_stub(path):
 # The editor would generate exactly this on first import; committing it keeps GitHub Desktop quiet.
 target=path.with_name(path.name+'.import')
 if target.exists():return
 res='res://assets/audio/sfx/'+path.name;digest=hashlib.md5(res.encode()).hexdigest()
 dest=f'res://.godot/imported/{path.name}-{digest}.sample'
 target.write_text('[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\nuid="%s"\npath="%s"\n\n[deps]\n\nsource_file="%s"\ndest_files=["%s"]\n\n[params]\n\nforce/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\nedit/trim=false\nedit/normalize=false\nedit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=2\n'%(godot_uid(path.name),dest,res,dest))
for p in sorted(OUT.glob('*.wav')):write_import_stub(p)
records={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.glob('*.wav'))}
(OUT/'manifest.json').write_text(json.dumps({'source':'Original deterministic synthesis; scripts/build_chapter_audio.py','sample_rate':RATE,'files':records},indent=2))
