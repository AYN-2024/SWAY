/* player: the comet. Drag pulls it, letting go brakes it, glowing pops things,
   and being pinned is the only thing that ever hurts. */
function newPlayer(x,y){
  return{x,y,vx:0,vy:0,r:MOVE.r,tr:[],top:false,over:0,hearts:3,squish:0,pnx:0,pny:-1,inv:0,superT:0,dust:0,ready:false,
    chain:0,rest:0,shoved:0,heal:0,bonkT:0,tE:0,tS:0,sqMax:0,dead:false,moved:0,maxH:3,reach:120,shoveT:0};
}
/* On touch the aim sits above the thumb, never under it. */
function aimPoint(){const lift=inp.touch?Math.min(92,VH*.13):0;return{x:(inp.sx-OX)/cam,y:(inp.sy-lift-OY)/cam};}

function playerTick(){
  const p=P;
  if(R.fin){p.x+=p.vx;p.y+=p.vy;p.tr.push(p.x,p.y);if(p.tr.length>52)p.tr.splice(0,2);return;}   // out: nothing holds it any more
  const sup=p.superT>0,cap=MOVE.cap*(sup?1.25:p.over>0?1.1:1),drive=MOVE.drive*(sup?1.3:p.over>0?1.2:1),k=inp.keys;
  let ix=0,iy=0;
  if(k.has('ArrowLeft')||k.has('KeyA'))ix--;if(k.has('ArrowRight')||k.has('KeyD'))ix++;
  if(k.has('ArrowUp')||k.has('KeyW'))iy--;if(k.has('ArrowDown')||k.has('KeyS'))iy++;
  if(ix||iy){const d=hyp(ix,iy);p.vx+=ix/d*drive;p.vy+=iy/d*drive;}
  if(inp.down){const a=aimPoint(),dx=a.x-p.x,dy=a.y-p.y,d=hyp(dx,dy);
    if(d>2){const f=Math.min(d/MOVE.reach,1)*drive;p.vx+=dx/d*f;p.vy+=dy/d*f;}}
  const q=inp.down||ix||iy?MOVE.held:MOVE.released;p.vx*=q;p.vy*=q;
  let v=hyp(p.vx,p.vy);if(v>cap){p.vx*=cap/v;p.vy*=cap/v;v=cap;}
  p.x+=p.vx;p.y+=p.vy;p.moved+=v;
  if(p.over>0)p.over--;if(p.inv>0)p.inv--;if(p.shoved>0)p.shoved--;if(p.bonkT>0)p.bonkT--;if(p.shoveT>0)p.shoveT--;
  if(sup&&--p.superT===0)p.inv=Math.max(p.inv,30);
  p.top=sup||(v>=TOP-1e-6&&p.shoved<=0);                 // speed you were handed by a shove does not count
  if(v<.6){if(++p.rest>24)endChain();}else p.rest=0;     // a chain lives while the comet moves and dies when it rests
  if(playerWalls())return;                               // true when the wall just rang: a new room has taken over
  p.tr.push(p.x,p.y);if(p.tr.length>52)p.tr.splice(0,2);
}

function playerWalls(){
  const p=P;
  if(p.x<BL+p.r){if(wallHit(1,0,-p.vx))return true;p.x=BL+p.r;}
  else if(p.x>BR-p.r){if(wallHit(-1,0,p.vx))return true;p.x=BR-p.r;}
  if(p.y<BT+p.r){if(wallHit(0,1,-p.vy))return true;p.y=BT+p.r;}
  else if(p.y>BB-p.r){if(wallHit(0,-1,p.vy))return true;p.y=BB-p.r;}
  return false;
}
function wallHit(nx,ny,vn){                              // (nx,ny) points back into the room, vn is the speed into the wall
  const p=P;if(vn<=0)return false;
  if(R.cleared){
    if(p.top&&vn>=6){gongNow(nx,ny);return true;}
    if(vn>3&&p.bonkT<=0){p.bonkT=20;sfx.dud();ringFx(p.x,p.y,COL.amber,6,46,16,3);if(++R.duds>1)say('Faster',120);}
  }
  if(nx)p.vx=-p.vx*MOVE.rebound;else p.vy=-p.vy*MOVE.rebound;
  if(vn>2){sfx.wall(Math.min(1,vn/MOVE.cap));if(vn>9){shake=Math.max(shake,vn*.3);puff(p.x-nx*p.r,p.y-ny*p.r,COL.wall,5,3);}}
  return false;
}

function endChain(){if(P.chain>R.best)R.best=P.chain;P.chain=0;}
function chainUp(){
  const p=P;p.chain++;if(p.chain>R.best)R.best=p.chain;
  if(p.chain>2)word(p.x,p.y-p.r-16,'x'+p.chain,COL.amber,15+Math.min(p.chain,14),36);
}
function gainDust(){
  const p=P;if(R.i<1||p.dust>=SUPER_COST)return;         // room 1 has no Super yet
  p.dust++;sfx.dust(p.dust);
  if(p.dust>=SUPER_COST){p.ready=true;sfx.ready();ringFx(p.x,p.y,COL.green,10,70,24,4);if(!save.hints.sup)say('Double-tap',600);}
}

/* The squeeze, as in the original: pinned = touching two bodies, or one body and something solid.
   The meter fills in 45 ticks while pinned and empties in 20 once free. Full = one heart. */
function squeezeTick(){
  const p=P;if(p.superT>0||p.inv>0){p.squish=Math.max(0,p.squish-.05);return;}
  const wall=p.x<=BL+p.r+1.5||p.x>=BR-p.r-1.5||p.y<=BT+p.r+1.5||p.y>=BB-p.r-1.5;
  const pinned=p.tE>=2||(p.tE>=1&&(wall||p.tS>0));
  p.squish=pinned?Math.min(1,p.squish+1/45):Math.max(0,p.squish-1/20);
  if(p.squish>p.sqMax)p.sqMax=p.squish;
  if(p.squish>=1)hurt();
  else if(p.squish===0&&p.sqMax>0){if(p.sqMax>.6){word(p.x,p.y-p.r-22,'Close!',COL.paper,20,46);sfx.heal();}p.sqMax=0;}   // slipped out of a squeeze
}
function hurt(){
  const p=P;p.hearts--;p.squish=p.sqMax=0;p.inv=110;p.heal=0;R.hurt=true;endChain();
  shake=24;freeze=8;flash=1;buzz(40);sfx.hurt();ringFx(p.x,p.y,COL.coral,10,240,30,7);puff(p.x,p.y,COL.teal,24,7);
  for(const e of E){const dx=e.x-p.x,dy=e.y-p.y,d=hyp(dx,dy)||1;
    if(d<e.r+p.r+8)e.crown=tick;                         // the ones that did it get a crown if this was the last heart
    if(d<280+e.r){const k=(1-Math.max(0,d-e.r)/280)*10;e.vx+=dx/d*k;e.vy+=dy/d*k;e.stun=70;}}
  if(p.hearts<=0){p.dead=true;R.deadT=70;slow=.25;slowT=70;sfx.dead();puff(p.x,p.y,COL.teal,40,9);ringFx(p.x,p.y,COL.paper,10,160,36,5);}
  hud();
}

/* Super: a blast that clears the space around you, then a couple of seconds where everything you touch pops. */
function fireSuper(){
  const p=P;if(!p.ready){if(R.i>0&&p.dust>0)sfx.ui();return;}
  p.ready=false;p.dust=0;p.superT=140;p.squish=p.sqMax=0;p.shoved=0;slow=.4;slowT=16;shake=18;buzz(30);sfx.boom();
  save.hints.sup=1;store();if(hint.s==='Double-tap')hint.t=0;
  ringFx(p.x,p.y,COL.green,20,230,30,9);
  for(const e of E.slice()){const dx=e.x-p.x,dy=e.y-p.y,d=hyp(dx,dy)||1;
    if(d<190+e.r)strike(e,-dx/d,-dy/d,true);
    else if(d<460){const k=(1-d/460)*8;e.vx+=dx/d*k;e.vy+=dy/d*k;e.stun=40;}}
  for(let i=ST.length-1;i>=0;i--)if(hyp(ST[i].x-p.x,ST[i].y-p.y)<200)breakStone(i);
}
