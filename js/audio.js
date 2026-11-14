/* audio: everything is synthesised, there is nothing to download.
   Pops climb a scale with the chain, the wind follows your speed, and the wall is the gong. */
let AC=null,master=null,noiseBuf=null,windG=null,windF=null,sqG=null,sqO=null,chimeT=0;

function audioOn(){
  if(AC){if(AC.state==='suspended')AC.resume();return;}
  const C=window.AudioContext||window.webkitAudioContext;if(!C)return;
  try{AC=new C();}catch(e){AC=null;return;}
  master=AC.createGain();master.gain.value=save.mute?0:.85;
  const comp=AC.createDynamicsCompressor();master.connect(comp);comp.connect(AC.destination);
  const n=AC.sampleRate*2;noiseBuf=AC.createBuffer(1,n,AC.sampleRate);
  const d=noiseBuf.getChannelData(0);for(let i=0;i<n;i++)d[i]=Math.random()*2-1;
  const src=AC.createBufferSource();src.buffer=noiseBuf;src.loop=true;
  windF=AC.createBiquadFilter();windF.type='bandpass';windF.Q.value=1.1;
  windG=AC.createGain();windG.gain.value=0;src.connect(windF);windF.connect(windG);windG.connect(master);src.start();
  sqO=AC.createOscillator();sqO.type='sawtooth';sqO.frequency.value=90;sqG=AC.createGain();sqG.gain.value=0;
  const lp=AC.createBiquadFilter();lp.type='lowpass';lp.frequency.value=800;
  sqO.connect(lp);lp.connect(sqG);sqG.connect(master);sqO.start();
}
function setMute(m){save.mute=m;store();if(master)master.gain.value=m?0:.85;}

function tone(f,dur,type,vol,to,when){
  if(!AC)return;const t=AC.currentTime+(when||0),o=AC.createOscillator(),g=AC.createGain();
  o.type=type||'sine';o.frequency.setValueAtTime(f,t);if(to)o.frequency.exponentialRampToValueAtTime(to,t+dur);
  g.gain.setValueAtTime(vol||.2,t);g.gain.exponentialRampToValueAtTime(.0006,t+dur);
  o.connect(g);g.connect(master);o.start(t);o.stop(t+dur+.03);
}
function hiss(dur,vol,freq,when){
  if(!AC)return;const t=AC.currentTime+(when||0),s=AC.createBufferSource(),f=AC.createBiquadFilter(),g=AC.createGain();
  s.buffer=noiseBuf;f.type='bandpass';f.frequency.value=freq||1800;f.Q.value=.8;
  g.gain.setValueAtTime(vol||.2,t);g.gain.exponentialRampToValueAtTime(.0006,t+dur);
  s.connect(f);f.connect(g);g.connect(master);s.start(t,Math.random());s.stop(t+dur+.03);
}

const SCALE=[0,2,4,7,9];
const sfx={
  pop(chain,big){
    const i=Math.max(0,chain-1),k=i<15?i:10+i%5,f=262*Math.pow(2,(SCALE[k%5]+12*(k/5|0))/12);
    tone(f,.17,'triangle',.24);tone(f*2,.08,'sine',.07);hiss(.05,.1,2600);if(big)tone(96,.22,'sine',.3,48);
  },
  bonk(){tone(140,.12,'square',.1,72);hiss(.05,.07,420);},
  wall(v){tone(165,.07,'sine',.04+.1*v);hiss(.03,.03+.07*v,900);},
  clang(){tone(830,.22,'square',.05);tone(1245,.3,'sine',.08);},
  peel(){tone(320,.22,'sawtooth',.13,110);hiss(.14,.2,1300);},
  spike(){tone(520,.14,'sawtooth',.13,180);},
  stone(){hiss(.12,.22,700);tone(210,.1,'triangle',.12,90);},
  dash(){tone(180,.3,'sawtooth',.08,620);},
  puff(){tone(240,.2,'sine',.08,420);},
  warn(){tone(196,.09,'sine',.035);},
  lock(){tone(150,.06,'sine',.03);},
  dust(n){if(!AC||AC.currentTime-chimeT<.035)return;chimeT=AC.currentTime;tone(820+n*15,.05,'sine',.045);},
  ready(){[523,659,784,1047].forEach((f,i)=>tone(f,.14,'triangle',.14,0,i*.06));},
  boom(){tone(180,.55,'sawtooth',.18,1500);hiss(.5,.3,700);tone(70,.4,'sine',.4,40);},
  hurt(){tone(330,.32,'square',.15,104);hiss(.25,.22,380);},
  heal(){tone(660,.1,'sine',.12);tone(990,.18,'sine',.12,0,.09);},
  clear(){[392,494,587].forEach((f,i)=>tone(f,.3,'triangle',.12,0,i*.07));},
  glowOn(){tone(660,.12,'triangle',.1,990);},
  glowOff(){tone(520,.14,'triangle',.08,300);},
  dud(){tone(118,.2,'sine',.22,84);hiss(.05,.1,280);},
  star(i){tone(784*Math.pow(1.26,i),.22,'triangle',.14);},
  ui(){tone(540,.05,'triangle',.07);},
  dead(){[330,262,196,131].forEach((f,i)=>tone(f,.28,'square',.1,0,i*.11));},
  gong(room){                                    // inharmonic partials; each room rings a little higher
    if(!AC)return;const t=AC.currentTime,b=84*Math.pow(2,(room||0)/14);
    [[1,1,3.6],[1.48,.62,3],[2.02,.5,2.5],[2.76,.34,2],[3.41,.24,1.6],[4.63,.16,1.2],[5.9,.09,.9]].forEach(p=>{
      const o=AC.createOscillator(),g=AC.createGain();
      o.frequency.setValueAtTime(b*p[0]*1.035,t);o.frequency.exponentialRampToValueAtTime(b*p[0],t+.6);
      g.gain.setValueAtTime(.0006,t);g.gain.exponentialRampToValueAtTime(.3*p[1],t+.012);g.gain.exponentialRampToValueAtTime(.0005,t+p[2]);
      o.connect(g);g.connect(master);o.start(t);o.stop(t+p[2]+.05);
    });
    hiss(.4,.45,480);tone(62,.5,'sine',.5,36);
  },
};

function audioFrame(){
  if(!AC)return;const live=state==='play'&&P&&!P.dead,t=AC.currentTime;
  const f=live?clamp(hyp(P.vx,P.vy)/MOVE.cap,0,1.3):0,q=live?P.squish:0;
  windG.gain.setTargetAtTime(f*f*.12,t,.06);windF.frequency.setTargetAtTime(280+f*1500,t,.06);   // the "whooop"
  sqG.gain.setTargetAtTime(q>.05?q*.08:0,t,.03);sqO.frequency.setTargetAtTime(80+q*240,t,.03);   // the squeeze creaks
}
