from pathlib import Path
import subprocess,numpy as np,wave,json
out=Path('assets/sounds/combat');out.mkdir(exist_ok=True)
sources={p.name: p for p in Path('audio 11').glob('*.mp3')}
recipes=[('pistol','9mm',[(.10,1.15)]),('rifle','pkm',[(.19,.78),(1.02,1.6),(2.24,2.82)]),('shotgun','shotgun',[(.73,1.9),(3.06,4.05),(6.93,8.02)]),('step','freeeverythingxx-running-on-concrete',[(.29,.49),(.85,1.05),(1.12,1.32),(1.41,1.61)]),('step_run','spinopel-run-fast',[(.32,.49),(1.57,1.75),(3.45,3.63),(5.40,5.58)]),('reload_start','dragon-studio-gun-reload-2',[(.14,.43)]),('reload_end','dragon-studio-gun-reload-2',[(1.04,1.32)]),('roll_contact','universfield-body-fall',[(.075,.46)]),('plasma_cutter','audiopapkin-science-fiction-gunshot',[(.33,1.0)])]
manifest=[]
for name,pattern,spans in recipes:
 p=next(p for n,p in sources.items() if pattern in n)
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ac','1','-ar','44100','-']); a=np.frombuffer(raw,np.float32)
 for i,(start,end) in enumerate(spans):
  clip=a[int(start*44100):int(end*44100)].copy();clip-=clip.mean()
  onset=np.flatnonzero(np.abs(clip)>np.max(np.abs(clip))*(.12 if name.startswith("step") else .04))
  if len(onset): clip=clip[max(0,int(onset[0])-88):]
  clip*=.88/max(float(np.max(np.abs(clip))),.001)
  fade=min(441,int(len(clip)*.1));clip[-fade:]*=np.linspace(1,0,fade);clip[:88]*=np.linspace(0,1,88)
  f=out/f'{name}_{i+1}.wav'
  with wave.open(str(f),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes((np.clip(clip,-1,1)*32767).astype('<i2').tobytes())
  manifest.append({'file':str(f),'source':str(p),'span':[start,end]})
Path('docs/combat_audio_sources.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf-8')
