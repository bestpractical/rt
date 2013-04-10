/* by TKirby, released under GPL */
/* Define the "list" Class */
Class("list").define({
 name : null,
 xml  : null,
 sels : null,
 list : function (src, esrc, name) { this.init(src, esrc, name); },
 read : function () {
     var i		= 0;
     if(this.xml.readyState!=4) { setTimeout(this.name+".read()", 100); }
     else if(this.xml.status!=200) alert("Document not available.");
     else {
	 var doc	= this.xml.responseXML;
	 var nNode	= null;
	 if(doc.childNodes[0].nodeName=="parseerror") alert("Parse Error.");
	 doc		= doc.getElementsByTagName("list")[0];
	 for(i=0;i<doc.childNodes.length;i++) {
	     if(doc.childNodes[i].childNodes.length>0) {
		 nNode	= document.createElement("option");
		 nNode.appendChild(document.createTextNode(doc.childNodes[i].childNodes[0].nodeValue));
		 this.sels[0].appendChild(nNode);
	     }
	 }
     }
 },
     
 init : function (src,esrc,name) {
     if(!src) return;
     this.name		= name;
     this.sels		= new Array();
     var i			= 0;
     for(i=0;i<src.childNodes.length;i++) {
	 if(src.childNodes[i].nodeName=="select" || src.childNodes[i].nodeName=="SELECT") {
	     this.sels.push(src.childNodes[i]);
	 } 

	 if((src.childNodes[i].nodeName=="input" || src.childNodes[i].nodeName=="INPUT")
	    && (src.childNodes[i].name=="fromjs")) {
	     src.childNodes[i].value = 1;
	 }

	 if((src.childNodes[i].nodeName=="input" || src.childNodes[i].nodeName=="INPUT")
	    && (src.childNodes[i].type=="submit" || src.childNodes[i].type=="SUBMIT")) {

	     if (src.childNodes[i].name.indexOf("Save") < 0) {
		 var tmp	= document.createElement("input");
		 tmp.type	= "button";
		 tmp.name	= src.childNodes[i].name;
		 tmp.value	= src.childNodes[i].value;
		 src.replaceChild(tmp,src.childNodes[i]);
	     }

	     if(src.childNodes[i].name=="add")
		 src.childNodes[i].onclick = new Function(this.name+".add();");
	     if(src.childNodes[i].name=="remove") 
		 src.childNodes[i].onclick = new Function(this.name+".remove();");
	     if(src.childNodes[i].name=="moveup") 
		 src.childNodes[i].onclick = new Function(this.name+".moveup();");
	     if(src.childNodes[i].name=="movedown") 
		 src.childNodes[i].onclick = new Function(this.name+".movedown();");
	 } 
     }
     if (esrc) {
	 this.xml	= (window.navigator.appName!="Microsoft Internet Explorer"
			   ?new XMLHttpRequest():new ActiveXObject("Microsoft.XMLHTTP"));
	 this.xml.open("GET", esrc);
	 this.xml.send("");
	 setTimeout(this.name+".read()", 100);
     }
 },
     
 add : function() {
     var i, j 	= 0;
     var dNode	= null;
     for(i=0;i<this.sels[0].length;i++) if(this.sels[0][i].selected) {
	 for(j=0;j<this.sels[1].length;j++) if(this.sels[1][j].value==this.sels[0][i].value) break;
	 if(j==this.sels[1].length) dNode	= this.sels[0][i].cloneNode(true), 
					this.sels[1].appendChild(dNode);
     }
 },

 moveup : function() { this.move(-1); },
 movedown : function() { this.move(1); },
 move : function(v) {
  var i		= 0;
  if(v<0) for(i=0;i<this.sels[1].length;i++) this.moveOne(v, i);
  else if(v>0) for(i=this.sels[1].length-1;i>=0;i--)this.moveOne(v, i);
 },

 moveOne : function(v, i) {
  var ins	= v + i;
  if(ins<0 || ins>=this.sels[1].length) return;
  if(this.sels[1][ins].selected) return;
  if(this.sels[1][i].selected) {
   Node		= this.sels[1][i];
   this.sels[1].removeChild(Node);
   this.sels[1].insertBefore(Node, this.sels[1][ins]);
  }
 },

 remove : function() {
  var i		= 0;
  for(i=this.sels[1].length-1;i>=0;i--) if(this.sels[1][i].selected) 
   this.sels[1].removeChild(this.sels[1][i]);
 },

 selectAll: function() {
  var i		= 0;
  for(i=0;i<this.sels[0].length;i++) this.sels[0][i].selected = false;
  for(i=0;i<this.sels[1].length;i++) this.sels[1][i].selected = true;
 }
});
