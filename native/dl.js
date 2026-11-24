async function(u,n,m){
  try{
    var r=await fetch(u);
    var b=await r.blob();
    n=n||window.__apkDlName||'';
    window.__apkDlName='';
    var t=m||b.type||'application/octet-stream';
    if(!AndroidDL.begin(n,t)){return}
    var C=1572864;
    for(var o=0;o<b.size;o+=C){
      var s=await new Promise(function(ok,no){
        var f=new FileReader();
        f.onload=function(){var x=String(f.result);ok(x.substring(x.indexOf(',')+1))};
        f.onerror=no;
        f.readAsDataURL(b.slice(o,o+C));
      });
      AndroidDL.write(s);
    }
    AndroidDL.end();
  }catch(e){try{AndroidDL.fail(String(e))}catch(_){}}
}
