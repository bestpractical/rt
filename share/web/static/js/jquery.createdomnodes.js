/*
 * jQuery CreateNode Plugin
 * By Sylvain MATHIEU (www.sylvain-mathieu.com) for Zenexity (zenexity.fr)
 * MIT License (http://www.opensource.org/licenses/mit-license.php)
 */

jQuery.createDomNodes = {
    virtualBracket: 0,
    currentBracket: 0,
    starter: false
};

jQuery.fn.applyAttrs = function(attrs) {
    return this.each(function() {
        var attrName;
        for(attrName in attrs) {
            jQuery(this).attr(attrName,attrs[attrName]);
        }
    });
};

jQuery.fn._tag_ = function(tagName, attrs, appendTag) {
    if(jQuery.createDomNodes.virtualBracket>jQuery.createDomNodes.currentBracket||jQuery.createDomNodes.starter) {
        jQuery.createDomNodes.starter = false;
        jQuery.createDomNodes.currentBracket = jQuery.createDomNodes.virtualBracket;
        return jQuery(document.createElement(tagName)).applyAttrs(attrs).appendTo(this);
    }
    else {
        jQuery.createDomNodes.currentBracket = jQuery.createDomNodes.virtualBracket;
        return jQuery(document.createElement(tagName)).applyAttrs(attrs).appendTo(this.parent());
    }
};

jQuery.fn._tag = function(tagName, attrs) {
    var tmp = this._tag_(tagName, attrs);
    jQuery.createDomNodes.virtualBracket++;
    return tmp;
};

jQuery.fn.tag_ = function() {
    jQuery.createDomNodes.virtualBracket--;
    return this.parent();
};

jQuery.fn._append_ = function(text) {
    this.parent().append(text);
    return this;
};

jQuery.addSupportedTag = function() {
    var tagName = this;
    jQuery.fn["_"+tagName+"_"] = function(attrs) {
        return this._tag_(tagName, attrs);
    };
    jQuery.fn["_"+tagName] = function(attrs) {
        return this._tag(tagName, attrs);
    };
    jQuery.fn[tagName+"_"] = function() {
        return this.tag_();
    };
    jQuery["_"+tagName+"_"] = function(attrs) {
        jQuery.createDomNodes.starter = true;
        return jQuery(document.createElement(tagName)).applyAttrs(attrs);
    };
    jQuery["_"+tagName] = function(attrs) { 
        jQuery.createDomNodes.starter = true;
        return jQuery(document.createElement(tagName)).applyAttrs(attrs);
    };
};

jQuery(document).ready(function(){
    var supportedTags = [
        "head","title","base","meta","link","style","script","noscript","body","div",
        "span","p","h1","h2","h3","h4","h5","h6","ul","ol",
        "li","dl","dt","dd","address","hr","pre","blockquote","ins","del",
        "a","span","bdo","br","em","strong","dfn","code","samp","kbd",
        "var","cite","abbr","acronym","q","sub","sup","tt","i","b",
        "big","small","object","param","img","map","area",
        "form","label","input","select","optgroup","option","textarea","fieldset","legend","fieldset",
        "button","fieldset","table","caption","thead","tfoot","tbody","colgroup","col","tr",
        "th","td"
    ];
    jQuery(supportedTags).each(jQuery.addSupportedTag);
});


