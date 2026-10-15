(function(){
  var d=document.documentElement,btn=document.getElementById('lang');
  function set(l,save){
    d.lang=l;d.dir=l==='ar'?'rtl':'ltr';
    if(btn)btn.textContent=l==='ar'?'English':'العربية';
    var t=document.documentElement.getAttribute('data-title-'+l);if(t)document.title=t;
    if(save){try{localStorage.setItem('fplpro-lang',l)}catch(e){}}
  }
  var s;try{s=localStorage.getItem('fplpro-lang')}catch(e){}
  var q=(location.search.match(/lang=(ar|en)/)||[])[1];
  var l=q||s||((navigator.language||'').slice(0,2)==='ar'?'ar':'en');
  set(l,false);
  if(btn)btn.addEventListener('click',function(){set(d.lang==='ar'?'en':'ar',true)});
  var nav=document.querySelector('.nav');
  function sc(){if(nav)nav.classList.toggle('scrolled',scrollY>8)}
  addEventListener('scroll',sc,{passive:true});sc();
})();
