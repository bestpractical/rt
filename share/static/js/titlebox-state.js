function createCookie(name,value,days) {
    var path = RT.Config.WebPath ? RT.Config.WebPath : "/";

    if (days) {
        var date = new Date();
        date.setTime(date.getTime()+(days*24*60*60*1000));
        var expires = "; expires="+date.toGMTString();
    }
    else
        expires = "";
    
    document.cookie = name+"="+value+expires+"; path="+path;
}

function loadTitleBoxStates() {
    var cookies = document.cookie.split(/;\s*/);
    var len     = cookies.length;

    for (var i = 0; i < len; i++) {
        var c = cookies[i].split('=');
        
        if (c[0].match(/^TitleBox--/)) {
            var e   = document.getElementById(c[0]);
            if (e) {
                var e2  = e.parentNode;
    
                if (c[1] != 0) {
                    set_rollup_state(e,e2,'shown');
                }
                else {
                    set_rollup_state(e,e2,'hidden');
                }
            }
        }
    }
}
