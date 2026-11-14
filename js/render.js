/* render: flat shapes, thick ink outlines, soft glows.
   Colour follows energy: the room is quiet, the action is bright. */
let vig=null;
function makeVignette(){
  const g=ctx.createRadialGradient(VW/2,VH/2,Math.min(VW,VH)*.35,VW/2,VH/2,Math.max(VW,VH)*.75);
  g.addColorStop(0,'rgba(255,91,97,0)');g.addColorStop(1,'rgba(255,91,97,.9)');vig=g;
}
function box(rad,x,y,w,h){const c=ctx;c.beginPath();if(c.roundRect)c.roundRect(x,y,w,h,rad);else c.rect(x,y,w,h);}
function label(s,x,y,size,col,a,wt){
  const c=ctx;c.globalAlpha=a;c.font=(wt||800)+' '+size+'px '+FONT;c.textAlign='center';c.textBaseline='middle';
  c.lineJoin='round';c.lineWidth=size*.22;c.strokeStyle=COL.line;c.strokeText(s,x,y);c.fillStyle=col;c.fillText(s,x,y);c.globalAlpha=1;
}
/* The map: ten rooms, each inside the next. */
function nest(cx,cy,size,done,cur,a){
  const c=ctx;
  for(let k=9;k>=0;k--){const s=size*(k+1.7)/10.7,lit=k<done;
    c.globalAlpha=a*(lit?1:k===cur?.9:.4);c.strokeStyle=lit?COL.amber:k===cur?COL.paper:COL.wall;
    c.lineWidth=Math.max(1.5,size/90)*(lit||k===cur?1.5:1);box(s*.09,cx-s/2,cy-s/2,s,s);c.stroke();}
  c.globalAlpha=1;
}
function star(x,y,r,on){
  const c=ctx;c.beginPath();
  for(let i=0;i<10;i++){const a=-Math.PI/2+i*Math.PI/5,q=i&1?r*.45:r;c.lineTo(x+Math.cos(a)*q,y+Math.sin(a)*q);}
  c.closePath();c.fillStyle=on?COL.amber:'rgba(141,147,173,.3)';c.fill();if(on){c.lineWidth=2;c.strokeStyle=COL.line;c.stroke();}
}

function draw(){
  const c=ctx;gt++;c.setTransform(DPR,0,0,DPR,0,0);c.fillStyle=COL.deep;c.fillRect(0,0,VW,VH);
  if(state==='title'||!R){                                             // the title: the ten rooms, and where you are in them
    if(mapOn){const b=$('slot').getBoundingClientRect(),s=Math.min(b.width,b.height)*.96,d=doneCount(),cur=Math.min(d,9);
      if(s>70){const x=b.left+b.width/2,y=b.top+b.height/2,o=s*(cur+1.7)/10.7*.27,a=gt*.035;nest(x,y,s,d,cur,1);
        c.fillStyle=COL.teal;c.strokeStyle=COL.line;c.lineWidth=2;c.beginPath();c.arc(x+Math.cos(a)*o,y+Math.sin(a)*o,Math.max(3.5,s/60),0,TAU);c.fill();c.stroke();}}
    return;}
  const k=calm?.25:1,sx=(Math.random()-.5)*shake*k,sy=(Math.random()-.5)*shake*k;
  let mx=W/2,my=H/2,fy=.5;
  if(R.fin){const q=ease(Math.min(1,R.fin/50));mx=lerp(mx,(mx+P.x)/2,q);my=lerp(my,(my+P.y)/2,q);fy=lerp(.5,.36,q);}   // the last shot: halfway between the rooms and the comet
  OX=fr.x+fr.w/2-mx*cam;OY=fr.y+fr.h*fy-my*cam;
  c.setTransform(DPR*cam,0,0,DPR*cam,DPR*(OX+sx),DPR*(OY+sy));
  drawRoom();
  c.save();box(0,BL,BT,BR-BL,BB-BT);c.clip();
  for(const n of IN)drawWarn(n);
  for(const s of ST)drawStone(s);
  c.fillStyle=COL.amber;for(const d of DU){const z=3.2+Math.sin((d.t+d.x)*.3);c.fillRect(d.x-z/2,d.y-z/2,z,z);}
  for(const e of E)if(e.type==='d'&&(e.mode===2||e.mode===1&&e.mt<=16))drawAim(e);
  for(const e of E)drawEnemy(e);
  c.restore();
  const big=P.squish>.02;                                                // a squeezed comet swells toward you: it is drawn over the frame
  if(!P.dead&&!big)drawComet();
  drawParts();drawWalls();
  if(!P.dead&&big)drawComet();
  for(const f of FL)label(f.s,f.x,f.y,f.size,f.col,Math.min(1,(f.m-f.t)/14));
  c.setTransform(DPR,0,0,DPR,0,0);
  drawOver();
}

function drawRoom(){
  const c=ctx,r=R;
  if(r.fin){                                                            // out: the ten rooms, one inside the other, fall away
    c.fillStyle=COL.paper;c.globalAlpha=.7;const z=2.6/cam;for(const q of r.sky)c.fillRect(q.x,q.y,z,z);
    for(let k=0;k<10;k++){const s=Math.pow(.8,k);c.globalAlpha=.95-k*.07;c.strokeStyle=COL.amber;c.lineWidth=3/cam;
      box(10,W/2-W*s/2,H/2-H*s/2,W*s,H*s);c.stroke();}
    c.globalAlpha=1;return;}
  c.fillStyle=r.ink;box(10,0,0,W,H);c.fill();
  c.strokeStyle=r.grid;c.lineWidth=1.2;c.beginPath();
  for(let x=W/2%56;x<W;x+=56){c.moveTo(x,0);c.lineTo(x,H);}for(let y=H/2%56;y<H;y+=56){c.moveTo(0,y);c.lineTo(W,y);}c.stroke();
  if(BL>.5){c.fillStyle=COL.deep;c.fillRect(-2,-2,W+4,BT+2);c.fillRect(-2,BB,W+4,H-BB+2);c.fillRect(-2,BT,BL+2,BB-BT);c.fillRect(BR,BT,W-BR+2,BB-BT);}
  if(r.ghost&&r.t<360){c.globalAlpha=r.intro>0?.6:.6*(1-r.t/360);c.strokeStyle=COL.amber;c.lineWidth=2.5;c.setLineDash([10,9]);   // the room you just left
    box(8,r.ghost.x,r.ghost.y,r.ghost.w,r.ghost.h);c.stroke();c.setLineDash([]);c.globalAlpha=1;}
}
function drawWalls(){
  const c=ctx,r=R;if(r.fin)return;const lw=7/cam,x=BL,y=BT,w=BR-BL,h=BB-BT;box(10,x,y,w,h);
  if(r.cleared){const pu=.5+.5*Math.sin(gt*.16);c.strokeStyle=COL.amber;                // gold: ring it
    c.globalAlpha=.13+.1*pu;c.lineWidth=lw*5;c.stroke();c.globalAlpha=.3+.2*pu;c.lineWidth=lw*2.4;c.stroke();c.globalAlpha=1;c.lineWidth=lw*1.2;c.stroke();}
  else{c.strokeStyle=r.wall;c.lineWidth=lw;c.stroke();
    if(r.ghost&&r.intro>0){c.globalAlpha=r.intro/120;c.strokeStyle=COL.paper;c.lineWidth=lw*1.6;c.stroke();c.globalAlpha=1;}}
}
function drawWarn(n){                                                   // something is about to come through here
  if(n.t>56)return;const c=ctx,k=1-n.t/56,wx=clamp(n.x,BL,BR),wy=clamp(n.y,BT,BB),col=TY[n.type].col,r=n.r*(.3+.7*k);
  c.globalAlpha=.25+.35*k;c.fillStyle=col;c.beginPath();c.arc(wx,wy,r,0,TAU);c.fill();
  c.globalAlpha=.45+.45*Math.sin(gt*.5);c.strokeStyle=col;c.lineWidth=3;c.beginPath();c.arc(wx,wy,r+6,0,TAU);c.stroke();c.globalAlpha=1;
}
function drawStone(s){
  const c=ctx;c.fillStyle=COL.stone;c.strokeStyle=COL.line;c.lineWidth=3;c.beginPath();c.arc(s.x,s.y,s.r,0,TAU);c.fill();c.stroke();
  c.strokeStyle='rgba(255,255,255,.4)';c.beginPath();c.arc(s.x,s.y,s.r*.66,3.5,4.9);c.stroke();
}
function drawAim(e){
  const c=ctx;c.strokeStyle=TY.d.col;c.globalAlpha=e.mode===2?.25:.65;c.lineWidth=3;c.setLineDash([9,9]);
  c.beginPath();c.moveTo(e.x,e.y);c.lineTo(e.x+e.dx*540,e.y+e.dy*540);c.stroke();c.setLineDash([]);c.globalAlpha=1;
}

function drawEnemy(e){
  const c=ctx,T=TY[e.type],p=P,age=tick-e.born,sc=age<14?ease(age/14):1,r=e.r*(1+e.pulse*.14),wob=1+Math.sin((tick+e.ph)*.12)*.035;
  let dx=p.x-e.x,dy=p.y-e.y;const d=hyp(dx,dy)||1;dx/=d;dy/=d;
  c.save();c.translate(e.x+(e.type==='d'&&e.mode===1?(Math.random()-.5)*4:0),e.y);c.scale(sc*wob,sc/wob);
  c.globalAlpha=.15;c.fillStyle=T.col;c.beginPath();c.arc(0,0,r*1.3,0,TAU);c.fill();c.globalAlpha=1;
  c.strokeStyle=COL.line;c.lineWidth=3;let br=r;
  if(e.type==='p'){const big=e.mode===2,tip=big?r:r*1.12;br=big?r*.7:r*.94;                        // puffer: nubs, or real spikes
    c.fillStyle=e.mode===1&&gt&4?COL.paper:T.col;c.beginPath();
    for(let i=0;i<24;i++){const a=i*TAU/24+e.ph,q=i&1?br*.96:tip;c.lineTo(Math.cos(a)*q,Math.sin(a)*q);}
    c.closePath();c.fill();c.stroke();}
  c.fillStyle=T.col;c.beginPath();
  if(e.type==='d'){const a=e.mode===0||(e.mode===1&&e.mt>16)?Math.atan2(dy,dx):Math.atan2(e.dy,e.dx);     // dasher: a nose that points where it will go
    c.arc(0,0,r,a+1,a-1+TAU);c.lineTo(Math.cos(a)*r*1.5,Math.sin(a)*r*1.5);c.closePath();}
  else c.arc(0,0,br,0,TAU);
  c.fill();c.stroke();
  if(!e.am){c.strokeStyle='rgba(10,12,23,.3)';c.lineWidth=2.5;for(let k=1;k<e.n;k++){c.beginPath();c.arc(0,0,br*ringR(k)/ringR(e.n),0,TAU);c.stroke();}}
  if(e.type==='s'){c.strokeStyle=COL.line;c.lineWidth=2.5;c.setLineDash([5,5]);c.beginPath();c.moveTo(0,-br);c.lineTo(0,br);c.stroke();c.setLineDash([]);}
  for(let k=0;k<e.armor;k++){c.beginPath();c.arc(0,0,br-5-k*8,0,TAU);c.strokeStyle=COL.line;c.lineWidth=7;c.stroke();c.strokeStyle='#e9e4d6';c.lineWidth=4;c.stroke();}
  if(e.type==='h'){c.lineCap='round';c.beginPath();c.arc(0,0,br+5,e.ang-1.13,e.ang+1.13);
    c.strokeStyle=COL.line;c.lineWidth=11;c.stroke();c.strokeStyle=COL.paper;c.lineWidth=6;c.stroke();c.lineCap='butt';}
  face(e,dx,dy,clamp(br*.5,10,30));
  if(p.dead&&tick-e.crown<600)crown(br);
  c.restore();
}
function face(e,dx,dy,f){
  const c=ctx,ex=f*.44,ey=-f*.1,scared=e.fear>.3,er=f*(scared?.4:.32),smug=!P.top&&!P.dead&&hyp(P.vx,P.vy)<MOVE.cap*.4;
  const out=e.stun>0||(e.type==='d'&&e.mode===3),sleep=e.type==='z';
  c.lineWidth=2.5;c.strokeStyle=COL.line;c.lineCap='round';
  for(const s of[-1,1]){const x=s*ex;
    if(sleep){c.beginPath();c.arc(x,ey,er*.8,.15*Math.PI,.85*Math.PI);c.stroke();continue;}
    if(out){c.beginPath();c.moveTo(x-er*.7,ey-er*.7);c.lineTo(x+er*.7,ey+er*.7);c.moveTo(x+er*.7,ey-er*.7);c.lineTo(x-er*.7,ey+er*.7);c.stroke();continue;}
    c.fillStyle=COL.paper;c.beginPath();c.arc(x,ey,er,0,TAU);c.fill();c.stroke();
    c.fillStyle=COL.line;c.beginPath();c.arc(x+dx*er*.42,ey+dy*er*.42,er*(scared?.3:.48),0,TAU);c.fill();}
  const my=f*.5;c.beginPath();
  if(sleep||out)c.arc(0,my,f*.12,0,TAU);
  else if(scared){c.fillStyle=COL.line;c.arc(0,my,f*.17,0,TAU);c.fill();c.beginPath();}
  else if(smug||P.dead)c.arc(0,my-f*.14,f*.26,.15*Math.PI,.85*Math.PI);                             // you are slow: it smiles
  else{c.moveTo(-f*.16,my);c.lineTo(f*.16,my);}
  c.stroke();
  if(e.type==='d'&&!out){c.lineWidth=3;c.beginPath();c.moveTo(-ex-er,ey-er*1.5);c.lineTo(-ex+er*.8,ey-er*.9);c.moveTo(ex+er,ey-er*1.5);c.lineTo(ex-er*.8,ey-er*.9);c.stroke();}
  c.lineCap='butt';
  if(sleep)label('z',f*1.3,-f*1.5-Math.sin(gt*.05)*3,f*.9,COL.paper,.85);
}
function crown(r){                                                      // whoever squished you gets to wear it
  const c=ctx,w=clamp(r,14,26),y=-r-4;c.fillStyle=COL.amber;c.strokeStyle=COL.line;c.lineWidth=2.5;c.beginPath();
  c.moveTo(-w*.6,y);c.lineTo(-w*.6,y-w*.55);c.lineTo(-w*.3,y-w*.3);c.lineTo(0,y-w*.7);c.lineTo(w*.3,y-w*.3);c.lineTo(w*.6,y-w*.55);c.lineTo(w*.6,y);
  c.closePath();c.fill();c.stroke();
}

/* The squeeze picture. Edit to taste: grow = how much bigger at a full meter, throb = the pulse, drop = how far the shadow falls. */
const BULGE={grow:.5,throb:.05,drop:9};
function drawComet(){
  const c=ctx,p=P,v=hyp(p.vx,p.vy),sup=p.superT>0,n=p.tr.length>>1,al=p.inv>0&&tick&4?.45:1,r=p.r,fk=R.fin?R.c1/cam:1;   // fk: the comet keeps its size on screen while the camera pulls away
  c.lineCap='round';
  for(let i=1;i<n;i++){const k=i/n;c.globalAlpha=k*.75;c.lineWidth=r*1.5*k*fk;                        // the tail goes rainbow at full speed
    c.strokeStyle=sup?COL.green:p.top?'hsl('+((i*13+gt*9)%360)+',95%,62%)':COL.teal;
    c.beginPath();c.moveTo(p.tr[i*2-2],p.tr[i*2-1]);c.lineTo(p.tr[i*2],p.tr[i*2+1]);c.stroke();}
  c.lineCap='butt';
  if(inp.down&&inp.touch&&!R.fin){const a=aimPoint();c.globalAlpha=.3;c.strokeStyle=COL.paper;c.lineWidth=2;c.beginPath();c.arc(a.x,a.y,9,0,TAU);c.stroke();}
  const q=p.squish>.02?p.squish:0;                                       // squeezed: no bending. It swells, throbs and lifts off the floor.
  c.save();c.translate(p.x,p.y);c.scale(fk,fk);
  if(q){const b=1+BULGE.grow*q+(calm?0:BULGE.throb*q*Math.sin(gt*(.25+.55*q)));
    c.globalAlpha=.4*q;c.fillStyle='#000';c.beginPath();c.arc(0,BULGE.drop*q,(r+7)*b,0,TAU);c.fill();c.globalAlpha=1;   // its shadow falls further below as it rises
    c.scale(b,b);}
  else if(v>1){const a=Math.atan2(p.vy,p.vx),s=1+Math.min(v/MOVE.cap,1.2)*.1;c.rotate(a);c.scale(s,1/s);c.rotate(-a);}
  const hot=sup?COL.green:p.top?'hsl('+(gt*9%360)+',95%,66%)':COL.paper;
  if(p.top){c.globalAlpha=al*.25;c.fillStyle=hot;c.beginPath();c.arc(0,0,r+11+Math.sin(gt*.4)*2,0,TAU);c.fill();}
  c.globalAlpha=al;c.strokeStyle=hot;c.lineWidth=3.5;c.beginPath();c.arc(0,0,r+5,0,TAU);c.stroke();
  if(R.i>0&&p.dust>0&&!sup){c.strokeStyle=p.ready?COL.green:COL.amber;c.lineWidth=p.ready?5+Math.sin(gt*.3)*1.5:4;      // dust fills a ring around you
    c.beginPath();c.arc(0,0,r+11,-Math.PI/2,-Math.PI/2+TAU*p.dust/SUPER_COST);c.stroke();}
  c.fillStyle=p.ready||sup?COL.green:COL.teal;c.strokeStyle=COL.line;c.lineWidth=3;c.beginPath();c.arc(0,0,r,0,TAU);c.fill();c.stroke();
  if(q){let g=c.createRadialGradient(0,0,r*.45,0,0,r);g.addColorStop(0,'rgba(0,0,0,0)');g.addColorStop(1,'rgba(0,0,0,'+(.5*q)+')');   // the rim falls away
    c.fillStyle=g;c.beginPath();c.arc(0,0,r-1.5,0,TAU);c.fill();
    g=c.createRadialGradient(-r*.3,-r*.38,0,-r*.3,-r*.38,r*(.35+.5*q));g.addColorStop(0,'rgba(255,255,255,'+(.75*q)+')');g.addColorStop(1,'rgba(255,255,255,0)');   // the shine of a dome
    c.fillStyle=g;c.beginPath();c.arc(0,0,r-1.5,0,TAU);c.fill();c.strokeStyle=COL.line;}
  const lx=v>1?p.vx/v:0,ly=v>1?p.vy/v:0,er=r*.3;c.lineWidth=2;
  for(const s of[-1,1]){const x=s*r*.38,y=-r*.12;
    if(p.squish>.3){const w=er*(1+.45*p.squish);c.fillStyle=COL.paper;c.beginPath();c.arc(x,y,w,0,TAU);c.fill();c.stroke();   // eyes wide
      c.fillStyle=COL.line;c.beginPath();c.arc(x,y,er*.3,0,TAU);c.fill();continue;}
    c.fillStyle=COL.paper;c.beginPath();c.arc(x,y,er,0,TAU);c.fill();c.stroke();
    c.fillStyle=COL.line;c.beginPath();c.arc(x+lx*er*.4,y+ly*er*.4,er*.5,0,TAU);c.fill();}
  c.beginPath();
  if(p.top){c.fillStyle=COL.line;c.arc(0,r*.3,r*.3,0,Math.PI);c.closePath();c.fill();}
  else{c.arc(0,r*.22,r*.3,.15*Math.PI,.85*Math.PI);c.stroke();}
  c.restore();c.globalAlpha=1;
}

function drawParts(){
  const c=ctx;
  for(const p of PT){const k=1-p.t/p.m;
    if(p.k===2){c.globalAlpha=k;c.strokeStyle=p.col;c.lineWidth=p.w*k+1;c.beginPath();c.arc(p.x,p.y,lerp(p.z,p.z1,ease(p.t/p.m)),0,TAU);c.stroke();}
    else if(p.k===1){c.globalAlpha=Math.min(1,k*2);c.fillStyle=p.col;c.save();c.translate(p.x,p.y);c.rotate(p.a);c.fillRect(-p.z,-p.z*.35,p.z*2,p.z*.7);c.restore();}
    else{c.globalAlpha=k;c.fillStyle=p.col;const z=p.z*(.4+.6*k);c.fillRect(p.x-z,p.y-z,z*2,z*2);}}
  c.globalAlpha=1;
}

/* Screen-space layer: the squeeze closing in, hints, the room card, the stars. */
function drawOver(){
  const c=ctx,p=P,r=R,cx=fr.x+fr.w/2;
  if(p.squish>.02&&!p.dead){c.globalAlpha=p.squish*.6;c.fillStyle=vig;c.fillRect(0,0,VW,VH);c.globalAlpha=1;}
  if(flash>.03){c.globalAlpha=flash*.5;c.fillStyle=COL.paper;c.fillRect(0,0,VW,VH);c.globalAlpha=1;}
  if(r.fin)return;
  if(hint.t>0&&hint.s==='Drag'){const k=gt%120/120,a=k<.1?k*10:k>.8?(1-k)*5:1,q=ease(Math.min(1,k*1.4)),                // a ghost thumb shows the drag
      x=lerp(OX+p.x*cam,cx,q),y=lerp(OY+p.y*cam+70,OY+H*.3*cam+120,q);
    c.globalAlpha=.16*a;c.fillStyle=COL.paper;c.beginPath();c.arc(x,y,26,0,TAU);c.fill();c.globalAlpha=.6*a;c.strokeStyle=COL.paper;c.lineWidth=3;c.stroke();c.globalAlpha=1;}
  if(hint.t>0&&hint.s)label(hint.s,cx,fr.y+fr.h*.86,24,COL.paper,Math.min(1,hint.t/20));
  if(r.res&&r.res.e&&r.intro>0){const n=120-r.intro,a=Math.min(1,n/10,r.intro/14),y=fr.y+fr.h*.26;                     // Endless: how many walls so far
    label(''+r.res.n,cx,y,84,COL.amber,a,900);label(r.res.n===1?'wall rung':'walls rung',cx,y+62,18,COL.paper,a);
    if(r.res.n>EB0&&EB0>0)label('New best',cx,y+90,15,COL.muted,a,700);}
  else if(r.res&&r.intro>0){const n=120-r.intro,a=Math.min(1,n/10,r.intro/14),y=fr.y+fr.h*.28,q=r.res;                  // the room you just rang
    nest(cx,y,96,q.i+1,q.i+1,a);c.globalAlpha=a;
    const cap=['out','no hit','chain '+Math.ceil(q.total*.75)+'+'];
    for(let b=0;b<3;b++){const on=q.s>>b&1,tt=n-(24+b*16),x=cx+(b-1)*62;if(tt<0)continue;
      c.globalAlpha=a;star(x,y+94,(on?20:15)*(tt<8?1.5-tt/16:1),on);label(cap[b],x,y+124,12,on?COL.paper:COL.muted,a,700);}
    label('Room '+(q.i+1)+' done',cx,y+158,18,COL.paper,a);label(clock(q.t)+'   best chain '+q.best,cx,y+183,14,COL.muted,a,700);}
  else if(r.intro>0||r.t<90){const a=r.intro>0?1:1-r.t/90;
    label(mode==='endless'?'Wall '+(EW+1):'Room '+(r.i+1),cx,fr.y+fr.h*.09,15,COL.muted,a,700);label(r.def.name,cx,fr.y+fr.h*.09+30,34,COL.paper,a,900);}
}
