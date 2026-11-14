/* fx: sparks, rings, shards, dust and the little floating words. Every list is capped, nothing grows without bound. */
const PT=[],DU=[],FL=[];

function puff(x,y,col,n,pw){
  for(let i=0;i<n&&PT.length<300;i++){const a=rnd()*TAU,s=pw*(.3+rnd());
    PT.push({k:0,x,y,vx:Math.cos(a)*s,vy:Math.sin(a)*s,t:0,m:20+rnd()*24,z:2+rnd()*3.6,col});}
}
function ringFx(x,y,col,r0,r1,m,w){if(PT.length<330)PT.push({k:2,x,y,vx:0,vy:0,t:0,m:m||26,z:r0,z1:r1,w:w||4,col});}
function shard(x,y,vx,vy,col){if(PT.length<330)PT.push({k:1,x,y,vx,vy,t:0,m:50+rnd()*40,z:5+rnd()*9,a:rnd()*TAU,col});}
function word(x,y,s,col,size,m){FL.push({x,y,s,col:col||COL.paper,size:size||20,t:0,m:m||60});if(FL.length>8)FL.shift();}
function dustAt(x,y,n){
  for(let i=0;i<n&&DU.length<170;i++){const a=rnd()*TAU,s=2+rnd()*4.5;DU.push({x,y,vx:Math.cos(a)*s,vy:Math.sin(a)*s,t:0});}
}

function fxTick(){
  for(let i=PT.length-1;i>=0;i--){const p=PT[i];
    if(++p.t>=p.m){PT[i]=PT[PT.length-1];PT.pop();continue;}
    const d=p.k===1?.975:.93;p.x+=p.vx;p.y+=p.vy;p.vx*=d;p.vy*=d;if(p.k===1)p.a+=.18;}
  for(let i=FL.length-1;i>=0;i--){const f=FL[i];f.y-=.55;if(++f.t>=f.m)FL.splice(i,1);}
  const p=P,all=R.cleared,reach=p.dead?0:all?1e5:p.superT>0?Math.max(280,p.reach):p.reach;       // dust leans toward the comet; a cleared room hands it all over
  for(let i=DU.length-1;i>=0;i--){const d=DU[i],dx=p.x-d.x,dy=p.y-d.y,q=hyp(dx,dy)||1;d.t++;
    if(d.t>8&&q<reach){const pull=all?2.2:.7+(1-q/reach)*1.6;d.vx+=dx/q*pull;d.vy+=dy/q*pull;}
    d.vx*=.9;d.vy*=.9;d.x+=d.vx;d.y+=d.vy;
    if(!all){d.x=clamp(d.x,BL+4,BR-4);d.y=clamp(d.y,BT+4,BB-4);}
    const got=q<p.r+12&&d.t>6&&!p.dead;
    if(got||d.t>1500){DU[i]=DU[DU.length-1];DU.pop();if(got)gainDust();}}
  shake*=.86;if(shake<.4)shake=0;flash*=.82;
}
