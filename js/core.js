'use strict';
/* GONG — pop them all, gong the wall.
   core: palette, movement numbers, screen, save, shared state. */
const COL={ink:'#171a2e',deep:'#0c0e1c',line:'#0a0c17',paper:'#f5f2e9',muted:'#8d93ad',grid:'#21254b',teal:'#35d2bb',coral:'#ff5b61',amber:'#f2c84b',green:'#4dff88',stone:'#a9adc6',wall:'#454c85'};

/* Movement is the v07-1l / Onboarding F model, number for number:
   pull = min(distance/70, 1) x drive, 0.985 of the speed kept per tick while held,
   a softer 0.9704 once released (half the coast), and a hard cap. */
const MOVE={drive:.81,cap:15.3,held:.985,released:.985/(2-.985),reach:70,rebound:.74,r:18};
const TOP=MOVE.cap*.95;                      // "glowing": only this fast pops anything
const SUPER_COST=50,HEAL_POPS=12,AREA0=290000,TICK=1000/60,TAU=Math.PI*2;
const FONT='ui-rounded,"SF Pro Rounded","Hiragino Maru Gothic ProN",Nunito,"Segoe UI",system-ui,sans-serif';

const hyp=Math.hypot,clamp=(v,a,b)=>v<a?a:v>b?b:v,lerp=(a,b,t)=>a+(b-a)*t,ease=t=>t*t*(3-2*t);
let seed=1;
function rnd(){seed=seed+0x6D2B79F5|0;let t=Math.imul(seed^seed>>>15,1|seed);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;}
const rr=(a,b)=>a+rnd()*(b-a);
const clock=t=>{const s=t/60|0;return(s/60|0)+':'+('0'+s%60).slice(-2);};
const $=id=>document.getElementById(id);
const cv=$('cv'),ctx=cv.getContext('2d');
const calm=matchMedia('(prefers-reduced-motion: reduce)').matches;

let VW=0,VH=0,DPR=1,S0=1,cam=1,OX=0,OY=0;    // viewport, base scale, camera (px per unit), draw origin
let W=390,H=740,BL=0,BT=0,BR=390,BB=740;     // room size and live wall positions, world units
const fr={x:0,y:0,w:0,h:0};                  // the room's frame on screen, css px
let state='title';                           // title | play | pause | dead | end
let P=null,R=null;                           // the comet, the current room
const E=[],ST=[],IN=[];                      // enemies, stones, arrivals on their way in
let tick=0,gt=0,freeze=0,slow=1,slowT=0,shake=0,flash=0;
const inp={down:false,sx:0,sy:0,touch:false,pid:-1,keys:new Set(),tapT:0,tapX:0,tapY:0,sup:false};
const hint={s:'',t:0};
function say(s,t){hint.s=s;hint.t=t||150;}

function layout(){
  VW=innerWidth;VH=innerHeight;DPR=Math.min(devicePixelRatio||1,2);
  cv.width=Math.round(VW*DPR);cv.height=Math.round(VH*DPR);
  const cs=getComputedStyle($('probe')),pad=k=>parseFloat(cs['padding'+k])||0;
  fr.x=10+pad('Left');fr.y=58+pad('Top');
  fr.w=Math.max(120,VW-fr.x-10-pad('Right'));fr.h=Math.max(120,VH-fr.y-10-pad('Bottom'));
  S0=clamp(Math.sqrt(fr.w*fr.h/AREA0),.6,3);  // every screen holds the same amount of room
}
const roomSize=zoom=>({c:S0*zoom,w:fr.w/(S0*zoom),h:fr.h/(S0*zoom)});

let save={rooms:[],hints:{},mute:false,endless:{best:0}};
try{const s=JSON.parse(localStorage.getItem('gong.v1'));if(s&&Array.isArray(s.rooms))save=Object.assign(save,s);}catch(e){}
function store(){try{localStorage.setItem('gong.v1',JSON.stringify(save));}catch(e){}}
if(!save.endless||typeof save.endless.best!=='number')save.endless={best:0};
/* Stars buy perks, and the perks only work in Endless: 10 = Super ready at the start, 20 = a fourth heart, 30 = dust from twice as far. */
const PERKS=[[10,'start Endless with Super ready'],[20,'a fourth heart in Endless'],[30,'dust comes from twice as far in Endless']];
function stars(){let n=0;for(let i=0;i<10;i++){const r=save.rooms[i];if(r)n+=(r.s&1)+(r.s>>1&1)+(r.s>>2&1);}return n;}
const perks=()=>{const n=stars();return{sup:n>=PERKS[0][0],heart:n>=PERKS[1][0],dust:n>=PERKS[2][0]};};
const buzz=ms=>{try{if(navigator.vibrate)navigator.vibrate(ms);}catch(e){}};
