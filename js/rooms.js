/* rooms: ten of them, each a box with a fixed crowd. Pop them all, then hit the wall glowing:
   it rings, it breaks, and the next room is bigger.
   A wave is [seconds after the last one, 'type+rings ...']. A wave also comes early once the room is nearly empty,
   so a fast player never waits. b blob · z sleeper · s splitter · d dasher · h shield · p puffer ·
   B brute (digit = armour bands) · G the giant. '@x,y' drops one straight into the room. */
const ROOMS=[
  {name:'First pop',zoom:1,grow:16,max:2,sp:.6,waves:[[0,'z1@.5,.3'],[999,'z1@.24,.52 z1@.76,.52'],[999,'b1 b1'],[6,'b1 b1 b1']]},
  {name:'They grow',zoom:.96,grow:6.5,max:6,sp:.8,waves:[[0,'b1 b1 b2'],[6,'b1 b2 b1'],[7,'b2 b1 b1'],[7,'b3 b1 b1']]},
  {name:'Split',zoom:.93,grow:7,max:10,sp:.75,waves:[[0,'s2 b1 b1'],[7,'s2 s2 b1'],[8,'s3 b1 b2']]},
  {name:'Rush',zoom:.9,grow:6,max:10,waves:[[0,'d1 b1 b1'],[6,'d1 b2 b1 b1'],[7,'d1 d1 b2 b1'],[7,'s2 b2 d1']]},
  {name:'Stones',zoom:.87,grow:6,max:10,stones:[[.25,.24],[.5,.2],[.75,.24],[.2,.5],[.5,.5],[.8,.5],[.25,.76],[.5,.8],[.75,.76]],
    waves:[[0,'b2 b1 b1 b2'],[6,'s2 b2 d1'],[7,'B2 b1'],[5,'b2 b1 b2 d1']]},
  {name:'Puffers',zoom:.84,grow:5.5,max:10,waves:[[0,'p1 b2 b1 b1'],[6,'p2 s2 b2'],[7,'p2 d1 b1 b2'],[7,'p1 b3 s2 d1']]},
  {name:'Shields',zoom:.81,grow:5.5,max:10,waves:[[0,'h1 b1 b1'],[6,'h1 b2 b1 p1'],[7,'h2 s2 b1'],[7,'h1 b2 d1']]},
  {name:'Crowd',zoom:.78,grow:4.5,max:10,sp:1.25,stones:[[.3,.3],[.7,.3],[.5,.5],[.3,.7],[.7,.7]],
    waves:[[0,'b2 b1 b2 s2 d1'],[5,'h1 b2 b2 p1 b1'],[6,'s3 d1 b3 b1 h2'],[6,'B2 b2 b1 s2 p2'],[6,'d1 d1 b3 b2 h1']]},
  {name:'The walls',zoom:.75,grow:5,max:10,sp:1.2,shrink:[.25,58],
    waves:[[0,'b2 b1 b1 s2'],[5,'d1 b2 b2 h1'],[5,'s2 b1 p1 b2'],[5,'b3 d1 s2 b1'],[5,'h2 b2 d1']]},
  {name:'The giant',zoom:.72,grow:5,max:10,sp:1.3,waves:[[0,'G7@.5,.28'],[8,'d1 h1 b2'],[10,'p1 d1 b2'],[10,'h2 d1 s2'],[10,'d1 d1 b3']]},
];
const tokens=s=>s.split(' ').map(t=>{const m=/^(\w)(\d)(?:@([\d.]+),([\d.]+))?$/.exec(t);return{type:m[1],n:+m[2],fx:m[3]?+m[3]:-1,fy:m[4]?+m[4]:0};});
const bodies=def=>def.waves.reduce((a,w)=>a+tokens(w[1]).reduce((b,t)=>b+(t.type==='s'?3:1),0),0);

/* carry = arriving through a broken wall: the comet keeps its speed and the old room stays behind as a ghost. */
function startRoom(i,carry){
  const def=ROOMS[i],s=roomSize(def.zoom),ox=carry?(s.w-W)/2:0,oy=carry?(s.h-H)/2:0,prev=P;
  const ghost=carry?{x:ox,y:oy,w:W,h:H}:null,c0=carry?cam:s.c,res=carry?R.res:null;
  W=s.w;H=s.h;BL=BT=0;BR=W;BB=H;E.length=IN.length=ST.length=0;
  if(carry)for(const q of PT.concat(DU,FL)){q.x+=ox;q.y+=oy;}else PT.length=DU.length=FL.length=0;
  P=newPlayer(W/2,H*.72);
  if(carry){P.x=prev.x+ox;P.y=prev.y+oy;P.vx=prev.vx;P.vy=prev.vy;P.over=30;P.tr=prev.tr.map((v,k)=>v+(k&1?oy:ox));}
  const hue=232+i*7;                                                    // each room drifts a little further from navy
  R={i,def,t:0,wi:0,wt:0,total:bodies(def),popped:0,best:0,hurt:false,cleared:false,duds:0,deadT:0,fin:0,intro:carry?120:36,c0,c1:s.c,ghost,res,
    ink:'hsl('+hue+',33%,13.5%)',grid:'hsl('+hue+',38%,21%)',wall:'hsl('+hue+',32%,41%)'};
  for(const q of def.stones||[])ST.push({x:q[0]*W,y:q[1]*H,r:25});
  cam=c0;hint.t=0;if(i===0&&!save.hints.drag)say('Drag',1e6);
  hud();
}

function roomTick(){
  const r=R,d=r.def;
  if(r.fin){                                                            // out: the camera lets go; the ten rooms shrink to a dot behind the comet
    r.fin++;cam+=(Math.min(r.c1,Math.min(fr.w,fr.h)/(hyp(P.x-W/2,P.y-H/2)*2.3+Math.max(W,H)*.9))-cam)*.07;   // keep the rooms and the comet both in the shot
    const v=hyp(P.vx,P.vy)||1,dx=P.vx/v,dy=P.vy/v;for(const q of r.sky)if((q.x-P.x)*dx+(q.y-P.y)*dy<-2500){q.x+=dx*9000;q.y+=dy*9000;}
    if(r.fin===250)showEnd();return;}
  if(r.intro>0){                                                        // the camera settles; stars for the room just rung
    r.intro--;cam=lerp(r.c0,r.c1,ease(1-r.intro/(r.ghost?120:36)));
    if(r.res){const n=120-r.intro,b=(n-24)/16;if(b===0||b===1||b===2){if(r.res.s>>b&1)sfx.star(b);}}
    return;}
  cam=r.c1;r.t++;r.wt++;
  if(r.wi<d.waves.length){const w=d.waves[r.wi],alive=E.length+IN.length;
    if(r.wt>=w[0]*60||(alive<=(r.i<2?0:r.i<5?1:2)&&r.wt>24)){launch(w[1]);r.wi++;r.wt=0;}}
  for(let i=IN.length-1;i>=0;i--){const n=IN[i];
    if(--n.t<=0){IN.splice(i,1);const e=mkEnemy(n.type,n.x,n.y,n.n);e.tx=n.tx;e.ty=n.ty;E.push(e);}
    else if(n.t===50)sfx.warn();}
  if(d.shrink){const k=r.cleared?0:Math.min(1,r.t/(d.shrink[1]*60))*d.shrink[0];    // room 9: the walls themselves close in
    BL+=(W*k-BL)*.1;BT+=(H*k-BT)*.1;BR=W-BL;BB=H-BT;}
  if(r.cleared&&++r.wt===260)say('Gong the wall',220);                  // a reminder if you linger
  if(!r.cleared&&r.wi>=d.waves.length&&!IN.length&&!E.length){
    r.cleared=true;r.wt=0;slow=.5;slowT=20;shake=Math.max(shake,8);sfx.clear();
    if(save.hints.gong)hint.t=0;else say('Gong the wall',1e6);hud();}
}
function launch(str){
  tokens(str).forEach((t,i)=>{
    if(t.fx>=0){const e=mkEnemy(t.type,BL+t.fx*(BR-BL),BT+t.fy*(BB-BT),t.n);e.st=1;E.push(e);
      ringFx(e.x,e.y,TY[t.type].col,e.r*1.9,e.r,20,3);if(t.type==='G')shake=20;}
    else{const r=ringR(ringsOf(t.type,t.n))*TY[t.type].k;IN.push(Object.assign({type:t.type,n:t.n,t:56+i*16,r},edgeSpot(r)));}
  });
  hud();
}

/* The wall is the gong. */
function gongNow(nx,ny){
  const r=R,p=P,s=1|(r.hurt?0:2)|(r.best>=Math.ceil(r.popped*.75)?4:0),sv=save.rooms[r.i]||{s:0,t:0};
  sv.s|=s;sv.t=sv.t?Math.min(sv.t,r.t):r.t;save.rooms[r.i]=sv;save.hints.gong=1;store();
  r.res={i:r.i,s,t:r.t,best:r.best,total:r.popped};
  freeze=12;shake=32;flash=.9;slow=.3;slowT=46;buzz(70);sfx.gong(r.i);hint.t=0;
  ringFx(p.x,p.y,COL.amber,12,Math.max(W,H)*1.1,70,12);ringFx(p.x,p.y,COL.paper,12,Math.max(W,H)*.6,40,6);
  const hit=nx>0?0:nx<0?1:ny>0?2:3;
  for(let k=0;k<46;k++){const u=rnd(),side=k<22?hit:rnd()*4|0;                  // the struck wall goes first
    const x=side===0?0:side===1?W:u*W,y=side===2?0:side===3?H:u*H,ax=side===0?-1:side===1?1:0,ay=side===2?-1:side===3?1:0;
    shard(x,y,ax*rr(2,9)+rr(-2,2),ay*rr(2,9)+rr(-2,2),COL.amber);}
  if(r.i+1<ROOMS.length)startRoom(r.i+1,true);
  else{                                                                         // the last wall: nothing left to hold it
    r.fin=1;r.cleared=false;BL=BT=-1e7;BR=BB=1e7;IN.length=0;p.over=0;$('hud').hidden=true;
    const v=hyp(p.vx,p.vy)||1,dx=p.vx/v,dy=p.vy/v;p.vx=dx*MOVE.cap;p.vy=dy*MOVE.cap;r.sky=[];
    for(let k=0;k<150;k++){const a=rr(-2500,6500),b=rr(-4500,4500);r.sky.push({x:p.x+dx*a-dy*b,y:p.y+dy*a+dx*b});}}
}

function hintTick(){
  const p=P,r=R;if(hint.t>0)hint.t--;
  if(r.i===0){
    if(hint.s==='Drag'&&hint.t>0&&p.moved>260){save.hints.drag=1;hint.t=0;}
    if(!save.hints.glow&&p.top){save.hints.glow=1;word(p.x,p.y-p.r-22,'Glow!',COL.amber,22,50);}
    if(!save.hints.pop&&r.popped>0){save.hints.pop=1;store();say('Pop them all',170);}
  }
}
