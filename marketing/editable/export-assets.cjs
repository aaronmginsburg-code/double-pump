// Rebuild upload exports and review boards from preserved masters and editable SVG type.
const sharp = require('C:/Users/aaron/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
const uri=p=>'data:image/'+(/\.jpe?g$/i.test(p)?'jpeg':'png')+';base64,'+fs.readFileSync(p).toString('base64');
const image=(p,x,y,w,h)=>`<image x="${x}" y="${y}" width="${w}" height="${h}" preserveAspectRatio="xMidYMid slice" href="${uri(p)}"/>`;
const text=(s,x,y,size,color='#ffffff',font='Impact')=>`<text x="${x}" y="${y}" font-family="${font},Arial,sans-serif" font-size="${size}" fill="${color}">${s}</text>`;
const wrap=(w,h,s)=>`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${s}</svg>`;
const configs=[
 {id:'01_DoublePump',master:'refined-A-master.png',tag:'FIRE. SWAP. FIRE.',x:92,y:80,title:158,pump:230},
 {id:'02_FirstPerson',master:'refined-D-master.png',tag:'FIRST-PERSON SHOTGUN PVP',x:92,y:120,title:142,pump:210},
 {id:'03_5v5Rooftops',master:'refined-C-master.png',tag:'5V5 SHOTGUN PVP',x:92,y:20,title:150,pump:224}
];
async function main(){
 const iconSvg=wrap(512,512,image(path.join(__dirname,'icon-final-master.png'),0,0,512,512));
 fs.writeFileSync(path.join(__dirname,'icon-final.svg'),iconSvg);
 await sharp(Buffer.from(iconSvg)).flatten({background:'#091424'}).removeAlpha().png({compressionLevel:9}).toFile(path.join(root,'finals/DoublePump_Icon_512.png'));
 for(const c of configs){
  const {x,y}=c;
  const type=`<g font-weight="900" letter-spacing="1" stroke="#07101b" stroke-width="7" paint-order="stroke fill" stroke-linejoin="round">${text('DOUBLE',x,y+c.title,c.title)}${text('PUMP',x,y+c.title+c.pump*.92,c.pump,'#ffad22')}</g>`;
  const tagY=y+c.title+c.pump*.92+72;
  const measured=await sharp({text:{text:c.tag,font:'Arial 43',rgba:true}}).png().toBuffer({resolveWithObject:true});
  const captionWidth=measured.info.width+44;
  const tagline=`<rect x="${x}" y="${tagY-46}" width="${captionWidth}" height="62" rx="4" fill="#07101b" fill-opacity=".90"/>`+text(c.tag,x+18,tagY,43,'#ffffff','Arial');
  const svg=wrap(1920,1080,`<defs><linearGradient id="shade" x1="0" y1="0" x2="1" y2=".35"><stop stop-color="#07101b" stop-opacity=".6"/><stop offset=".55" stop-color="#07101b" stop-opacity="0"/></linearGradient></defs>`+image(path.join(__dirname,c.master),0,0,1920,1080)+`<rect width="1920" height="580" fill="url(#shade)"/>`+type+tagline);
  fs.writeFileSync(path.join(__dirname,c.id+'.svg'),svg);
  await sharp(Buffer.from(svg)).flatten({background:'#07101b'}).removeAlpha().jpeg({quality:96,chromaSubsampling:'4:4:4',mozjpeg:true}).toFile(path.join(root,'finals',c.id+'_1920x1080.jpg'));
  await sharp(Buffer.from(svg)).flatten({background:'#07101b'}).removeAlpha().png({compressionLevel:9}).toFile(path.join(__dirname,c.id+'_lossless.png'));
 }
 // Small-size review is an inspection aid, not an upload file.
 let board=`<rect width="1600" height="1200" fill="#09111d"/>`+text('DOUBLE PUMP / FINAL SELECTION',54,62,36,'#ffffff','Arial');
 board+=image(path.join(root,'finals/DoublePump_Icon_512.png'),54,115,400,400)+text('FINAL ICON',54,555,24,'#ffad22','Arial');
 board+=image(path.join(root,'finals/DoublePump_Icon_512.png'),54,610,150,150)+text('150px CHECK',224,700,23,'#b5c4d5','Arial');
 board+=image(path.join(root,'finals/01_DoublePump_1920x1080.jpg'),520,115,1026,577)+text('01 / PRIMARY — FIRE. SWAP. FIRE.',520,736,25,'#ffad22','Arial');
 board+=image(path.join(root,'finals/02_FirstPerson_1920x1080.jpg'),54,814,716,403)+image(path.join(root,'finals/03_5v5Rooftops_1920x1080.jpg'),830,814,716,403);
 // Extend board for complete bottom images/labels.
 board=board.replace('height="1200"','height="1285"');
 board+=text('02 / FIRST-PERSON',54,1260,23,'#b5c4d5','Arial')+text('03 / 5V5 ROOFTOPS',830,1260,23,'#b5c4d5','Arial');
 await sharp(Buffer.from(wrap(1600,1285,board))).png().toFile(path.join(root,'FINAL_ASSETS_PREVIEW.png'));
 const icons=['icon-01-hero.png','icon-02-double.png','icon-03-combat.png'];
 const thumbs=['thumbnail-A-double-pump','thumbnail-B-close-combat','thumbnail-C-five-v-five','thumbnail-D-first-person','thumbnail-E-three-arenas','thumbnail-F-precision'];
 // Thumbnail cells maintain 16:9; two columns, three rows.
 let concepts=`<rect width="1600" height="2090" fill="#09111d"/>`+text('DOUBLE PUMP / CONCEPT EXPLORATION',40,52,30,'#ffffff','Arial');
 for(let i=0;i<3;i++)concepts+=image(path.join(root,'concepts',icons[i]),40+i*520,90,480,480)+text(['I / HERO SHOTGUN','II / DOUBLE-PUMP IDENTITY','III / COMBAT'][i],40+i*520,610,21,'#ffad22','Arial');
 for(let i=0;i<6;i++){const x=40+(i%2)*780,y=650+Math.floor(i/2)*480;concepts+=image(path.join(root,'concepts',thumbs[i]+'.png'),x,y,740,416.25)+text(thumbs[i].replace('thumbnail-','').replaceAll('-',' ').toUpperCase(),x,y+452,21,'#b5c4d5','Arial');}
 await sharp(Buffer.from(wrap(1600,2090,concepts))).png().toFile(path.join(root,'CONCEPTS_PREVIEW.png'));
 const finalFiles=fs.readdirSync(path.join(root,'finals')).filter(f=>/\.(png|jpg)$/i.test(f));const manifest=[];
 for(const f of finalFiles){const p=path.join(root,'finals',f),m=await sharp(p).metadata();const bytes=fs.statSync(p).size;manifest.push({file:f,width:m.width,height:m.height,format:m.format,space:m.space,bytes});if(bytes>=3000000)throw Error(f+' exceeds conservative 3MB limit');}
 fs.writeFileSync(path.join(root,'finals/EXPORT_MANIFEST.json'),JSON.stringify(manifest,null,2));console.log(JSON.stringify(manifest,null,2));
}
main().catch(e=>{console.error(e);process.exit(1)});
