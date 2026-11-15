/* ui: screens, HUD, input and the loop. */
const doneCount=()=>save.rooms.filter(r=>r&&r.s).length;
let last=0,acc=0,sacc=0,mapOn=false;

function show(id){
  for(const s of document.querySelectorAll('.scr'))s.hidden=s.id!==id;
  $('ov').hidden=!id;mapOn=id==='title';$('ov').classList.toggle('clear',mapOn);$('ov').classList.toggle('soft',id==='end');$('hud').hidden=state==='title'||state==='end';
  if(id==='title'){const d=doneCount(),b=save.endless.best;$('play').textContent=!d?'Play':d>=ROOMS.length?'Play again':'Play room '+(d+1);
    $('endlessBtn').hidden=!endlessOpen();$('endlessBtn').textContent=b?'Endless  ·  best '+b:'Endless';
    const st=stars();$('roomsBtn').textContent=st?'Rooms  ·  '+st+' of 30 stars':'Rooms';$('mute0').textContent=muteWord();}                    // the stars still to win, on the first screen
  if(id==='dead'){const e=mode==='endless',n=$('deadStats'),sp=P&&P.by==='spike',b=Math.max(R.best,P.chain),old=e?0:bestChain(R.i,b);n.hidden=false;
    $('deadTitle').textContent=sp?'Spiked':'Squished';$('deadTag').textContent=sp?'Leave it alone while it is spiky.':'If you stop, you die.';
    n.textContent=e?'You rang '+EW+(EW===1?' wall. ':' walls. ')+(EW>EB0?'New best.':'Best '+save.endless.best+'.')
      :Math.max(0,R.total-R.popped)+' left to pop. Best chain '+b+'.'+(old&&b>old?' Your best in this room.':'');}   // the rooms: how close it was, the best chain, and whether it beat the one saved for this room
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
  $('mute').textContent=muteWord();ask='';askWords();
  const ps=$('pauseStars');ps.hidden=mode==='endless';                                  // where this room's stars stand: the heart star and the chain star
  ps.textContent=(R.hurt?'A heart was lost in this room. ':'No heart lost in this room. ')+'Best chain '+Math.max(R.best,P.chain)+'. The star needs '+Math.ceil(R.total*.75)+'.';
  show('pause');
}
const muteWord=()=>save.mute?'Sound off':'Sound on';
/* Endless, paused: Restart run and Rooms end the run, so the first tap only asks. The second tap on the same button does it.
   Keep going, the Sound button or pausing again puts the buttons back. In the rooms one tap is enough: a room is under a minute. */
let ask='';
function askWords(){
  $('restart').textContent=ask==='restart'?'End this run? Tap again':mode==='endless'?'Restart run':'Restart room';
  $('quit').textContent=ask==='quit'?'End this run? Tap again':'Rooms';
}
function sure(id){if(mode!=='endless'||state!=='pause'||ask===id){ask='';return true;}ask=id;askWords();return false;}
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
  $('perkNote').textContent=st+' of 30 stars. '+perksOn()+(nx?(nx[0]-st)+' more: '+nx[1]+'.':'')+(endlessOpen()?'':' Endless opens after room 10.');   // the perks pay in Endless: say when it opens, while it is shut
  state='title';show('rooms');
}
function showEnd(){
  $('endStats').textContent=stars()+' of 30 stars. '+perksOn();state='end';show('end');
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
      sacc+=slow*SLOWMO;while(sacc>=1&&(state==='play'||state==='end')){sacc--;update();}}
    if(n===4)acc=0;
  }
  audioFrame();draw();
}

/* Input: one thumb. Drag to fly, let go to coast, double-tap for Super. */
cv.addEventListener('pointerdown',e=>{
  if(state!=='play')return;e.preventDefault();audioOn();
  if(inp.down&&e.pointerId!==inp.pid){inp.pid2=e.pointerId;inp.sx2=e.clientX;inp.sy2=e.clientY;return;}   // a second finger waits: it fires Super if it lifts first, and steers if the first thumb lifts first
  const now=performance.now();
  if(now-inp.tapT<300&&hyp(e.clientX-inp.tapX,e.clientY-inp.tapY)<60)inp.sup=true;       // double-tap
  inp.tapT=now;inp.tapX=e.clientX;inp.tapY=e.clientY;
  inp.down=true;inp.pid2=-1;inp.touch=e.pointerType==='touch';inp.pid=e.pointerId;inp.sx=e.clientX;inp.sy=e.clientY;
  try{cv.setPointerCapture(e.pointerId);}catch(_){}
});
addEventListener('pointermove',e=>{if(!inp.down)return;if(e.pointerId===inp.pid){inp.sx=e.clientX;inp.sy=e.clientY;}else if(e.pointerId===inp.pid2){inp.sx2=e.clientX;inp.sy2=e.clientY;}});
const lift=e=>{
  if(e.pointerId===inp.pid2){inp.pid2=-1;if(e.type==='pointerup')inp.sup=true;return;}   // a tap with a second finger: Super. A thumb swap never gets here
  if(e.pointerId!==inp.pid)return;
  if(inp.pid2>=0){inp.pid=inp.pid2;inp.sx=inp.sx2;inp.sy=inp.sy2;inp.pid2=-1;}   // changing thumbs: the one still on the glass steers
  else inp.down=false;};
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
$('roomsBtn').onclick=$('deadRooms').onclick=$('endRooms').onclick=openRooms;
$('quit').onclick=()=>{if(sure('quit'))openRooms();};
$('back').onclick=()=>{state='title';show('title');};
$('pauseBtn').onclick=pause;$('resume').onclick=resume;
$('retry').onclick=replay;
$('restart').onclick=()=>{if(sure('restart'))replay();};
$('endlessBtn').onclick=$('endEndless').onclick=beginEndless;
$('again').onclick=()=>begin(0);
$('mute').onclick=$('mute0').onclick=()=>{setMute(!save.mute);$('mute').textContent=$('mute0').textContent=muteWord();ask='';askWords();};

layout();makeVignette();addEventListener('resize',onResize);show('title');requestAnimationFrame(frame);
