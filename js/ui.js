/* ui: screens, HUD, input and the loop. */
const doneCount=()=>save.rooms.filter(r=>r&&r.s).length;
let last=0,acc=0,sacc=0,mapOn=false;

function show(id){
  for(const s of document.querySelectorAll('.scr'))s.hidden=s.id!==id;
  $('ov').hidden=!id;mapOn=id==='title';$('ov').classList.toggle('clear',mapOn);$('ov').classList.toggle('soft',id==='end');$('hud').hidden=state==='title'||state==='end';
  if(id==='title'){const d=doneCount(),b=save.endless.best;$('play').textContent=!d?'Play':d>=ROOMS.length?'Play again':'Play room '+(d+1);
    $('endlessBtn').hidden=!endlessOpen();$('endlessBtn').textContent=b?'Endless  ·  best '+b:'Endless';}
  if(id==='dead'){const e=mode==='endless',n=$('deadStats');n.hidden=!e;
    if(e)n.textContent='You rang '+EW+(EW===1?' wall. ':' walls. ')+(EW>EB0?'New best.':'Best '+save.endless.best+'.');}
}
function hud(){
  if(!R||!P)return;const hb=$('hearts'),hs=hb.children;while(hs.length<P.maxH)hb.appendChild(hs[0].cloneNode(true));   // a fourth heart, if the stars bought one
  for(let i=0;i<hs.length;i++){hs[i].style.display=i<P.maxH?'':'none';hs[i].classList.toggle('lost',i>=P.hearts);}
  $('count').textContent=Math.max(0,R.total-R.popped);$('left').classList.toggle('done',R.cleared);
  $('roomno').textContent=mode==='endless'?'Walls '+EW:(R.i+1)+'/'+ROOMS.length;
}
const endlessOpen=()=>doneCount()>=ROOMS.length||/[?&]all\b/.test(location.search);
function beginEndless(){mode='endless';EW=0;EB0=save.endless.best;start(ROOMS.length);}
function begin(i){mode='rooms';start(i);}
const replay=()=>mode==='endless'?beginEndless():begin(R.i);
function start(i){
  audioOn();seed=(Date.now()^i*7919)|0;state='play';slow=1;slowT=freeze=shake=flash=acc=sacc=0;inp.down=inp.sup=false;inp.keys.clear();
  startRoom(i,false);show('');
}
function pause(){
  if(state!=='play'||R.fin)return;state='pause';inp.down=false;inp.keys.clear();
  $('mute').textContent=save.mute?'Sound off':'Sound on';$('restart').textContent=mode==='endless'?'Restart run':'Restart room';show('pause');
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
  const st=stars(),nx=PERKS.find(p=>st<p[0]);                              // what the next stars buy
  $('perkNote').textContent=st+' of 30 stars. '+(nx?(nx[0]-st)+' more: '+nx[1]+'.':'All three Endless perks are on.');
  state='title';show('rooms');
}
function showEnd(){
  $('endStats').textContent=stars()+' of 30 stars.';state='end';show('end');
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

/* Input: one thumb. Drag to fly, let go to coast, double-tap for Super. */
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
  if(R&&(e.code==='KeyR'&&(state==='play'||state==='dead')||e.code==='Enter'&&state==='dead')){replay();return;}
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
$('restart').onclick=$('retry').onclick=replay;
$('endlessBtn').onclick=$('endEndless').onclick=beginEndless;
$('again').onclick=()=>begin(0);
$('mute').onclick=()=>{setMute(!save.mute);$('mute').textContent=save.mute?'Sound off':'Sound on';};

layout();makeVignette();addEventListener('resize',onResize);show('title');requestAnimationFrame(frame);
