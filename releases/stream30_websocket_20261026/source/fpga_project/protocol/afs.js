(function(root){'use strict';
function crc(a){let c=0xffffffff;for(const b of a){c^=b;for(let j=0;j<8;j++)c=(c>>>1)^((c&1)?0xedb88320:0);}return(c^0xffffffff)>>>0;}
function decode(buffer){const a=new Uint8Array(buffer),d=new DataView(a.buffer,a.byteOffset,a.byteLength);if(a.length!==28832||String.fromCharCode(...a.slice(0,4))!=='AFS1'||a[4]!==1||a[5]!==3||a[6]||a[7]||d.getUint32(16,true)!==28800||d.getUint16(20,true)||d.getUint16(22,true)!==160||d.getUint16(24,true)!==90||d.getUint16(26,true)||!d.getUint32(8,true)||crc(a.subarray(0,-4))!==d.getUint32(a.length-4,true))throw Error('Invalid complete frame');const rgba=new Uint8ClampedArray(160*90*4);for(let i=0;i<14400;i++){const v=d.getUint16(28+2*i,true),r=v>>11,g=(v>>5)&63,b=v&31;rgba.set([(r<<3)|(r>>2),(g<<2)|(g>>4),(b<<3)|(b>>2),255],i*4);}return{session:d.getUint32(8,true),seq:d.getUint32(12,true),rgba};}
const api={crc,decode};if(typeof module!=='undefined')module.exports=api;else root.AFS=api;
})(globalThis);
