/* ui: screens, HUD, input and the loop. */
const doneCount=()=>save.rooms.filter(r=>r&&r.s).length;
let last=0,acc=0,sacc=0,mapOn=false;

function show(id){
  for(const s of document.querySelectorAll('.scr'))s.hidden=s.id!==id;
  $('ov').hidden=!id;mapOn=id==='title';$('ov').classList.toggle('clear',mapOn);$('ov').classList.toggle('soft',id==='end');$('hud').hidden=state==='title'||state==='end';
  if(id==='title'){const d=doneCount();$('play').textContent=!d?'Play':d>=ROOMS.length?'Play again':'Play room '+(d+1);}
}
function hud(){
  if(!R||!P)return;const hs=$('hearts').children;for(let i=0;i<3;i++)hs[i].classList.toggle('lost',i>=P.hearts);
  $('count').textContent=Math.max(0,R.total-R.popped);$('left').classList.toggle('done',R.cleared);
  $('roomno').textContent=(R.i+1)+'/'+ROOMS.length;
}
function begin(i){
  audioOn();seed=(Date.now()^i*7919)|0;state='play';slow=1;slowT=freeze=shake=flash=acc=sacc=0;inp.down=inp.sup=false;inp.keys.clear();
  startRoom(i,false);show('');
}
function pause(){
  if(state!=='play'||R.fin)return;state='pause';inp.down=false;inp.keys.clear();
  $('mute').textContent=save.mute?'Sound off':'Sound on';show('pause');
}
function resume(){if(state!=='pause')return;state='play';show('');}
function openRooms(){
  const g=$('grid'),open=/[?&]all\b/.test(location.search)?ROOMS.length:Math.min(ROOMS.length,doneCount()+1);g.textContent='';
  ROOMS.forEach((d,i)=>{
    const b=document.createElement('button'),s=save.rooms[i]?save.rooms[i].s:0;
    b.className='tile';b.disabled=i>=open;b.setAttribute('aria-label','Room '+(i+1)+': '+d.name);
    b.innerHTML='<b>'+(i+1)+'</b><span>'+[1,2,4].map(m=>'<i'+(s&m?' class="on"':'')+'></i>').join('')+'</span>';
    b.onclick=()=>begin(i);g.appendChild(b);
  });
  state='title';show('rooms');
}
function showEnd(){
  let st=0,t=0;for(const r of save.rooms)if(r){st+=(r.s&1)+(r.s>>1&1)+(r.s>>2&1);t+=r.t;}
  $('endStats').textContent=st+' of 30 stars. Your best times add up to '+clock(t)+'.';state='end';show('end');
}

/* One tick of the game, 60 of them a second. */
function update(){
  if(freeze>0){freeze--;return;}
  tick++;
  if(inp.sup){inp.sup=false;if(!P.dead&&!R.fin&&R.intro<=0)fireSuper();}
  roomTick();
  if(!P.dead)playerTick();
  enemiesTick();
  if(!P.dead&&!R.fin)squeezeTick();
  fxTick();hintTick();
  if(P.dead&&--R.deadT<=0){state='dead';show('dead');}
}
function frame(t){
  requestAnimationFrame(frame);
  const dt=Math.min(100,t-last);last=t;
  if(state==='play'||state==='end'){                         // the end screen keeps the comet flying behind it
    acc+=dt;let n=0;
    while(acc>=TICK&&n<4){acc-=TICK;n++;
      if(slowT>0&&--slowT===0)slow=1;
      sacc+=slow;while(sacc>=1&&(state==='play'||state==='end')){sacc--;update();}}
    if(n===4)acc=0;
  }
  audioFrame();draw();
}

/* Input: one thumb. Drag to fly, let go to brake, double-tap for Super. */
cv.addEventListener('pointerdown',e=>{
  if(state!=='play')return;e.preventDefault();audioOn();
  if(inp.down&&e.pointerId!==inp.pid){inp.sup=true;return;}                              // a second finger fires Super too
  const now=performance.now();
  if(now-inp.tapT<300&&hyp(e.clientX-inp.tapX,e.clientY-inp.tapY)<60)inp.sup=true;       // double-tap
  inp.tapT=now;inp.tapX=e.clientX;inp.tapY=e.clientY;
  inp.down=true;inp.touch=e.pointerType==='touch';inp.pid=e.pointerId;inp.sx=e.clientX;inp.sy=e.clientY;
  try{cv.setPointerCapture(e.pointerId);}catch(_){}
});
addEventListener('pointermove',e=>{if(inp.down&&e.pointerId===inp.pid){inp.sx=e.clientX;inp.sy=e.clientY;}});
const lift=e=>{if(e.pointerId===inp.pid)inp.down=false;};
addEventListener('pointerup',lift);addEventListener('pointercancel',lift);
addEventListener('keydown',e=>{
  if(e.code==='Space'){if(state==='play'){inp.sup=true;e.preventDefault();}return;}
  if(e.code==='Escape'||e.code==='KeyP'){if(state==='play')pause();else resume();return;}
  if(R&&(e.code==='KeyR'&&(state==='play'||state==='dead')||e.code==='Enter'&&state==='dead')){begin(R.i);return;}
  if(state==='play')inp.keys.add(e.code);
});
addEventListener('keyup',e=>inp.keys.delete(e.code));
addEventListener('blur',()=>{inp.keys.clear();inp.down=false;});
document.addEventListener('visibilitychange',()=>{if(document.hidden)pause();});
addEventListener('contextmenu',e=>e.preventDefault());

function onResize(){
  layout();makeVignette();if(!R)return;
  const s=roomSize(R.def.zoom),fx=s.w/W,fy=s.h/H;
  for(const q of[P].concat(E,ST,IN,DU,PT,FL)){q.x*=fx;q.y*=fy;if(q.tx!==undefined){q.tx*=fx;q.ty*=fy;}}
  P.tr=P.tr.map((v,k)=>v*(k&1?fy:fx));
  if(R.ghost){R.ghost.x*=fx;R.ghost.y*=fy;R.ghost.w*=fx;R.ghost.h*=fy;}
  W=s.w;H=s.h;R.c0=R.c1=cam=s.c;if(!R.fin){BL=BT=0;BR=W;BB=H;}
}

$('play').onclick=()=>{const d=doneCount();begin(d>=ROOMS.length?0:d);};
$('roomsBtn').onclick=$('quit').onclick=$('deadRooms').onclick=$('endRooms').onclick=openRooms;
$('back').onclick=()=>{state='title';show('title');};
$('pauseBtn').onclick=pause;$('resume').onclick=resume;
$('restart').onclick=$('retry').onclick=()=>begin(R.i);
$('again').onclick=()=>begin(0);
$('mute').onclick=()=>{setMute(!save.mute);$('mute').textContent=save.mute?'Sound off':'Sound on';};

layout();makeVignette();addEventListener('resize',onResize);show('title');requestAnimationFrame(frame);
