/* by TKirby, released under GPL */

 function _ClassSetup(Object) {
  this.prototype	= Object;
  return this;
 }
 
 function Class(name) {
  var _newclass_;
  eval("window."+name+"	= new Function('this."+name+".apply(this,arguments);');");
  eval("window."+name+".define = _ClassSetup;");
  eval("_newclass_ = window."+name+";");
  return _newclass_;
 }

