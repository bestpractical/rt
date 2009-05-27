/*
% $r->content_type('application/x-javascript');
*/
// Fetched from http://www.opendarwin.org/~drernie/src/ahah.js - No Copyright - Public Domain
function ahah(url, target, delay) {
  // document.getElementById(target).innerHTML = 'Loading <a href="'+url+'">'+url +'</a>...';
  if (window.XMLHttpRequest) {
    req = new XMLHttpRequest();
  } else if (window.ActiveXObject) {
    req = new ActiveXObject("Microsoft.XMLHTTP");
  }

  var use_get;
  if ( /webkit|firefox\/2/i.test( navigator.userAgent ) ) {
      // seems safari has weird problem with post: 
      // it does remove the old content of target
      // while doesn't replace that with new content
      // so is firefox 2
      use_get = 1;
  }

  if (req != undefined) {
    req.onreadystatechange = function() {ahahDone(url, target, delay);};
    if ( use_get == 1 ) {
        req.open("GET", url, true);
    }
    else{
        req.open("POST", url, true);
    }
    req.send("");
  }
}  

function ahahDone(url, target, delay) {
  if (req.readyState == 4) { // only if req is "loaded"
    if (req.status == 200) { // only if "OK"
      document.getElementById(target).innerHTML = req.responseText;
    } else {
      document.getElementById(target).innerHTML="Error loading '"+url+"':\n"+req.statusText;
    }
    if (delay != undefined) {
       setTimeout("ahah(url,target,delay)", delay); // resubmit after delay
	    //server should ALSO delay before responding
    }
  }
}

% $m->abort();
