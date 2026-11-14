/* enemies: every one of them walks at you — slower when you are fast, bolder behind your back.
   What you do not pop keeps growing. Rings are size; pale bands are armour and each band is one hit. */
const TY={
  b:{col:'#ff5b61',sp:.95,k:1,mx:10},      // blob: the only kind that grows without limit
  z:{col:'#ff5b61',sp:0,k:1,mx:1},          // a sleeping blob, room 1 only
  s:{col:'#ff8f4f',sp:.8,k:1.12,mx:5},      // splitter: pops into two
  d:{col:'#ff4fa0',sp:.6,k:.9,mx:3},        // dasher: winds up, then charges
  h:{col:'#e04a62',sp:.72,k:1.05,mx:4},     // shield: only pops from the side or behind
  p:{col:'#a57bff',sp:.5,k:1,mx:4},         // puffer: leave it alone while it is spiky
  B:{col:'#c9364d',sp:.42,k:1,mx:4},        // brute: armoured
  G:{col:'#c9364d',sp:.3,k:1,mx:8},         // the giant
};
const ringR=n=>19+9.5*(n-1)+.55*(n-1)*(n-1);
const ringsOf=(type,n)=>type==='G'?8:type==='B'?4:n;
const bodyR=e=>ringR(e.n)*TY[e.type].k*(e.type==='p'&&e.mode===2?1.6:1)*(e.type==='G'?.62+.38*e.armor/e.am:1);
let eid=1;

function mkEnemy(type,x,y,n){
  const big=type==='B'||type==='G';
  const e={id:eid++,type,x,y,vx:0,vy:0,n:ringsOf(type,n),armor:big?n:0,am:big?n:0,r:0,tr:0,st:0,tx:x,ty:y,grow:0,ang:0,
    mode:0,mt:type==='p'?rnd()*120|0:0,cd:rr(110,260),dx:1,dy:0,stun:0,iv:0,fear:0,pulse:0,bump:false,crown:-999,born:tick,ph:rnd()*400|0};
  e.r=e.tr=bodyR(e);e.grow=R.def.grow*60*rr(.7,1.3);return e;
}
/* A spot just outside a wall, and where to slide to — never right on top of the comet. */
function edgeSpot(r){
  let s;
  for(let k=0;k<10;k++){
    const side=rnd()*4|0,u=rnd(),ix=lerp(BL+r+8,BR-r-8,u),iy=lerp(BT+r+8,BB-r-8,u);
    s=side===0?{x:BL-r-8,y:iy,tx:BL+r+26,ty:iy}:side===1?{x:BR+r+8,y:iy,tx:BR-r-26,ty:iy}
     :side===2?{x:ix,y:BT-r-8,tx:ix,ty:BT+r+26}:{x:ix,y:BB+r+8,tx:ix,ty:BB-r-26};
    if(hyp(s.tx-P.x,s.ty-P.y)>210)break;
  }
  return s;
}

function enemiesTick(){
  const p=P,pv=hyp(p.vx,p.vy),f=Math.min(1,pv/MOVE.cap),hx=pv>.5?p.vx/pv:0,hy=pv>.5?p.vy/pv:0,spd=R.def.sp||1;
  let area=0;for(const e of E)area+=e.r*e.r;
  const full=area*Math.PI>(BR-BL)*(BB-BT)*.68;                          // a packed room stops growing
  for(const e of E){
    e.fear*=.88;e.pulse*=.9;if(e.iv>0)e.iv--;
    if(e.st===0){const dx=e.tx-e.x,dy=e.ty-e.y,d=hyp(dx,dy)||1;e.vx=dx/d*2.8;e.vy=dy/d*2.8;if(d<4)e.st=1;}   // sliding in from outside
    else if(e.stun>0||e.type==='z'||p.dead){if(e.stun>0)e.stun--;e.vx*=.9;e.vy*=.9;}
    else brain(e,p,pv,f,hx,hy,spd);
    e.x+=e.vx;e.y+=e.vy;
    if(e.st===1&&e.type!=='z'&&!e.am&&--e.grow<=0){e.grow=R.def.grow*60*rr(.8,1.25);if(e.n<Math.min(R.def.max,TY[e.type].mx)&&!full){e.n++;e.pulse=1;sfx.lock();}}
    e.tr=bodyR(e);e.r+=(e.tr-e.r)*.12;
  }
  for(let i=0;i<E.length;i++){const a=E[i];                            // the crowd packs; the lighter body gives way
    for(let j=i+1;j<E.length;j++){const b=E[j],dx=b.x-a.x,dy=b.y-a.y,m=a.r+b.r;
      if(dx>m||dx<-m||dy>m||dy<-m)continue;const d=hyp(dx,dy)||.01;if(d>=m)continue;
      const o=(m-d)*.6/d,aa=a.r*a.r,bb=b.r*b.r;let wa=bb/(aa+bb),wb=1-wa;
      if(a.type==='d'&&a.mode===2){wa=0;wb=1;}else if(b.type==='d'&&b.mode===2){wb=0;wa=1;}
      a.x-=dx*o*wa;a.y-=dy*o*wa;b.x+=dx*o*wb;b.y+=dy*o*wb;}
    for(const s of ST){const dx=a.x-s.x,dy=a.y-s.y,m=a.r+s.r,d=hyp(dx,dy)||.01;if(d<m){a.x+=dx/d*(m-d);a.y+=dy/d*(m-d);}}
    a.bump=false;
    if(a.st===1){const r=Math.min(a.r,(BR-BL)/2-1,(BB-BT)/2-1);
      if(a.x<BL+r){a.x=BL+r;a.bump=a.vx<0;}else if(a.x>BR-r){a.x=BR-r;a.bump=a.vx>0;}
      if(a.y<BT+r){a.y=BT+r;a.bump=a.bump||a.vy<0;}else if(a.y>BB-r){a.y=BB-r;a.bump=a.bump||a.vy>0;}}
  }
  if(!p.dead&&!R.fin)contact();
}

function brain(e,p,pv,f,hx,hy,spd){
  const T=TY[e.type],dx=p.x-e.x,dy=p.y-e.y,d=hyp(dx,dy)||1;
  let sp=T.sp*spd/(1+.1*(e.n-1))*(1.55-1.15*f);                         // creep in while the comet is slow
  const ahead=pv>.5?(-dx*hx-dy*hy)/d:0;                                 // 1 = right in the comet's path
  if(ahead<-.2&&f>.3)sp*=1.5;                                           // bolder behind its back
  let ax=dx/d*sp,ay=dy/d*sp;
  if(p.top&&ahead>.72&&d<210+e.r&&e.type!=='G'){const s=dx*hy-dy*hx>0?1:-1;ax=-hy*s*1.15;ay=hx*s*1.15;e.fear=1;}   // faced at full speed: step aside
  if(e.type==='d'){
    if(e.mode===0){if(--e.cd<=0&&d<540){e.mode=1;e.mt=46;}}
    else if(e.mode===1){ax=ay=0;
      if(e.mt===16){const lx=dx+p.vx*7,ly=dy+p.vy*7,l=hyp(lx,ly)||1;e.dx=lx/l;e.dy=ly/l;}       // the aim locks here; the line shows it
      if(--e.mt<=0){e.mode=2;e.mt=42;sfx.dash();}}
    else if(e.mode===2){e.vx=e.dx*9.5;e.vy=e.dy*9.5;
      if(--e.mt<=0||e.bump){e.mode=3;e.mt=e.bump?90:55;if(e.bump){shake=Math.max(shake,7);sfx.wall(.7);puff(e.x,e.y,T.col,6,3);dustAt(e.x,e.y,BAIT_DUST);}}
      return;}
    else{ax=ay=0;if(--e.mt<=0){e.mode=0;e.cd=rr(130,270);}}             // dizzy
  }else if(e.type==='h'){let da=Math.atan2(dy,dx)-e.ang;da=Math.atan2(Math.sin(da),Math.cos(da));e.ang+=clamp(da,-.03,.03);}
  else if(e.type==='p'){e.mt++;
    if(e.mode===0&&e.mt>170){e.mode=1;e.mt=0;}else if(e.mode===1&&e.mt>34){e.mode=2;e.mt=0;sfx.puff();}else if(e.mode===2&&e.mt>120){e.mode=0;e.mt=0;}}
  else if(e.type==='G'&&--e.cd<=0){e.cd=clamp(250-(e.am-e.armor)*22,120,250);                    // the giant makes more
    if(E.length<12){for(const s of[-1,1]){const a=Math.atan2(dy,dx)+s*.9,c=mkEnemy('b',e.x+Math.cos(a)*e.r,e.y+Math.sin(a)*e.r,1);
      c.st=1;c.vx=Math.cos(a)*6;c.vy=Math.sin(a)*6;c.stun=24;E.push(c);R.total++;}hud();}}
  e.vx+=(ax-e.vx)*.07;e.vy+=(ay-e.vy)*.07;
}

/* The comet against everything else. */
function contact(){
  const p=P;p.tE=0;p.tS=0;
  for(let i=ST.length-1;i>=0;i--){const s=ST[i],dx=p.x-s.x,dy=p.y-s.y,m=s.r+p.r,d=hyp(dx,dy)||.01;if(d>m+1.5)continue;
    if(d<m){if(p.top){breakStone(i);continue;}
      const nx=dx/d,ny=dy/d,vn=p.vx*nx+p.vy*ny;p.x+=nx*(m-d);p.y+=ny*(m-d);
      if(vn<0){p.vx-=(1+MOVE.rebound)*vn*nx;p.vy-=(1+MOVE.rebound)*vn*ny;if(vn<-2)sfx.wall(Math.min(1,-vn/MOVE.cap));}}
    p.tS++;}
  for(let i=E.length-1;i>=0;i--){const e=E[i],dx=p.x-e.x,dy=p.y-e.y,m=e.r+p.r;
    if(dx>m+2||dx<-m-2||dy>m+2||dy<-m-2)continue;const d=hyp(dx,dy)||.01;if(d>m+1.5)continue;
    const nx=dx/d,ny=dy/d;
    if(d<m){if(canStrike(e,nx,ny)){strike(e,nx,ny,false);if(E[i]!==e)continue;}else bumpInto(e,nx,ny,m-d);}
    if(e.type!=='z'){p.tE++;p.pnx=nx;p.pny=ny;}}            // a sleeper cannot pin you
  p.x=clamp(p.x,BL+p.wr,BR-p.wr);p.y=clamp(p.y,BT+p.wr,BB-p.wr);
}
function canStrike(e,nx,ny){
  const p=P;if(!p.top||e.iv>0)return false;
  if(e.type==='p'&&e.mode===2)return false;                                       // spikes out
  if(e.type==='h'&&nx*Math.cos(e.ang)+ny*Math.sin(e.ang)>.42)return false;        // into the shield
  return true;
}
function strike(e,nx,ny,blast){                                                   // (nx,ny) points from the enemy to the comet
  const p=P;
  if(e.armor>0){e.armor=Math.max(0,e.armor-(blast?2:1));e.pulse=1;e.stun=30;e.iv=34;e.vx-=nx*3;e.vy-=ny*3;chainUp();
    if(!blast){const vn=p.vx*nx+p.vy*ny;if(vn<0){p.vx-=1.8*vn*nx;p.vy-=1.8*vn*ny;}p.x=e.x+nx*(e.r+p.r+1);p.y=e.y+ny*(e.r+p.r+1);}
    freeze=Math.max(freeze,5);shake=Math.max(shake,15);buzz(20);sfx.peel();
    puff(e.x+nx*e.r,e.y+ny*e.r,COL.paper,16,6);ringFx(e.x,e.y,COL.paper,e.r*.8,e.r*1.5,20,5);return;}
  if(!blast&&e.type==='b'&&e.n>=TOUGH&&!e.cut){e.cut=1;e.n=Math.ceil(e.n/2);e.pulse=0;e.stun=30;e.iv=34;e.vx-=nx*3;e.vy-=ny*3;chainUp();
    const vn=p.vx*nx+p.vy*ny;if(vn<0){p.vx-=1.8*vn*nx;p.vy-=1.8*vn*ny;}p.x=e.x+nx*(e.r+p.r+1);p.y=e.y+ny*(e.r+p.r+1);
    freeze=Math.max(freeze,5);shake=Math.max(shake,13);buzz(20);sfx.peel();dustAt(e.x,e.y,4);
    puff(e.x+nx*e.r,e.y+ny*e.r,TY.b.col,18,6);ringFx(e.x,e.y,TY.b.col,e.r*.8,e.r*1.5,20,5);return;}
  pop(e);
}
const KIND_DUST=6;   // extra dust for popping a dasher, a puffer or a shield: the dangerous kinds pay more
const BAIT_DUST=4;   // dust a dasher drops when its charge ends on a wall
const TOUGH=4;   // a blob with this many rings or more takes two glowing touches
function pop(e){
  const p=P,i=E.indexOf(e);if(i<0)return;E.splice(i,1);
  const T=TY[e.type],big=e.n>2;R.popped++;chainUp();p.over=30;                    // a pop never slows you: it gives you a kick
  freeze=Math.max(freeze,big?4:2);shake=Math.max(shake,5+e.n*2.4);buzz(big?16:8);sfx.pop(p.chain,big);
  puff(e.x,e.y,T.col,10+e.n*5,4+e.n);ringFx(e.x,e.y,T.col,e.r*.6,e.r*1.8,18,5);dustAt(e.x,e.y,3+e.n*2+(e.type==='d'||e.type==='p'||e.type==='h'?KIND_DUST:0));
  if(e.type==='s'){const v=hyp(p.vx,p.vy)||1,sx=-p.vy/v,sy=p.vx/v;               // two smaller ones fly out sideways
    for(const s of[-1,1]){const c=mkEnemy('b',e.x+sx*s*e.r*.5,e.y+sy*s*e.r*.5,Math.max(1,e.n-1));
      c.st=1;c.vx=sx*s*7;c.vy=sy*s*7;c.stun=26;c.iv=10;E.push(c);}}
  if(e.type==='G'){slow=.3;slowT=60;shake=30;dustAt(e.x,e.y,40);puff(e.x,e.y,COL.paper,40,10);}
  if(p.hearts<p.maxH&&++p.heal>=HEAL_POPS){p.heal=0;p.hearts++;word(p.x,p.y-p.r-30,'+1',COL.coral,24,50);sfx.heal();}
  hud();
}
/* A touch that is not a pop: the body throws you back and the chain ends. It costs no heart.
   One throw, then a short gap (SHOVE.gap ticks) where a touch only stops you, so being pinned still works as before. */
const SHOVE={base:8,perRing:.8,rings:4,gap:40};
const SPIKE={push:1.5,dark:60};   // every spike touch costs a heart, blinking or not. push = the little speed you keep, dark = ticks with no glow
function bumpInto(e,nx,ny,o){
  const p=P,vn=p.vx*nx+p.vy*ny,en=e.vx*nx+e.vy*ny;p.x+=nx*o;p.y+=ny*o;
  if(e.type==='p'&&e.mode===2&&p.spikeT<=tick){p.spikeT=tick+SHOVE.gap;p.vx=nx*SPIKE.push;p.vy=ny*SPIKE.push;p.shoved=SPIKE.dark;p.shoveT=SHOVE.gap;p.squish=Math.min(.9,p.squish+.2);endChain();   // spikes: stopped dead, and no glow for a second
    sfx.spike();shake=Math.max(shake,14);buzz(20);puff(p.x,p.y,TY.p.col,14,6);hurt('spike');return;}   // and a heart, every time. The gap (SHOVE.gap ticks) only stops one bump from counting twice
  if(e.type==='d'&&e.mode===2){p.vx+=e.dx*11;p.vy+=e.dy*11;p.shoved=18;p.squish=Math.min(.9,p.squish+.3);e.mode=3;e.mt=60;endChain();
    sfx.bonk();shake=Math.max(shake,14);return;}
  if(e.iv>0){if(vn<0){p.vx-=1.7*vn*nx;p.vy-=1.7*vn*ny;}return;}                   // just struck: solid for a moment, no penalty
  if(e.type!=='z'&&p.shoveT<=0){                                                  // thrown back; bigger bodies throw harder; sleepers never do
    const k=SHOVE.base+Math.min(e.n,SHOVE.rings)*SHOVE.perRing;p.vx=nx*k+e.vx;p.vy=ny*k+e.vy;p.shoved=18;p.shoveT=SHOVE.gap;p.bonkT=14;e.pulse=1;endChain();
    shake=Math.max(shake,9);buzz(12);if(e.type==='h'&&p.top)sfx.clang();else sfx.bonk();puff(p.x-nx*p.r,p.y-ny*p.r,TY[e.type].col,8,5);return;}
  if(vn<0){p.vx-=1.55*vn*nx;p.vy-=1.55*vn*ny;p.vx*=.3;p.vy*=.3;}
  const v2=p.vx*nx+p.vy*ny;if(v2<en){p.vx+=(en-v2)*nx;p.vy+=(en-v2)*ny;}          // a body that keeps coming carries the comet with it
  if(vn<-3&&p.bonkT<=0){p.bonkT=14;shake=Math.max(shake,4);if(e.type==='h'&&p.top)sfx.clang();else sfx.bonk();
    if(e.type==='z'&&!save.hints.pop)say('Faster. Glow to pop.',200);}
  endChain();e.vx-=nx*.5;e.vy-=ny*.5;
}
function breakStone(i){
  const s=ST[i];ST.splice(i,1);freeze=Math.max(freeze,2);shake=Math.max(shake,6);sfx.stone();
  puff(s.x,s.y,COL.stone,12,5);ringFx(s.x,s.y,COL.stone,s.r*.5,s.r*1.6,16,4);dustAt(s.x,s.y,4);
}
