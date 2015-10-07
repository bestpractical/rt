/** @license Copyright (c) 2003-2015, CKSource - Frederico Knabben. 
 * All rights reserved.
 * For licensing, see LICENSE.html or http://ckeditor.com/license */

CKEDITOR.editorConfig = function( config ) {
        // %REMOVE_START%
        // The configuration options below are needed when running CKEditor from source files.
        config.plugins = 'dialogui,dialog,a11yhelp,dialogadvtab,basicstyles,blockquote,clipboard,button,panelbutton,panel,floatpanel,colorbutton,menu,contextmenu,resize,toolbar,enterkey,entities,find,floatingspace,listblock,richcombo,font,format,htmlwriter,wysiwygarea,indent,justify,fakeobjects,link,indentlist,list,liststyle,magicline,pastetext,pastefromword,removeformat,selectall,sourcearea,specialchar,menubutton,tab,table,tabletools,undo,popup,autolink,horizontalrule';
        config.skin = 'flat';
        // %REMOVE_END%


config.toolbar = 'Full';
config.toolbar_Full = [
    ['Cut','Copy','Paste','PasteText','PasteFromWord'],
    ['Undo','Redo','-','-','SelectAll','RemoveFormat'],
    ['Table','HorizontalRule','SpecialChar','Link'],
    '/',
    ['Bold','Italic','Underline','Strike'],
    ['NumberedList','BulletedList','-','Outdent','Indent','-','Blockquote'],
    ['JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock'],
    '/',
    ['Format','Font','FontSize'],
    ['TextColor'],
    ['Source']
];

config.enterMode = CKEDITOR.ENTER_BR;
config.shiftEnterMode = CKEDITOR.ENTER_P;
config.enableTabKeyTools = true;
config.htmlEncodeOutput = false;
config.disableNativeSpellChecker = false;
config.browserContextMenuOnCtrl = true;
config.toolbarCanCollapse = true;
config.toolbarStartupExpanded = false;
config.font_names =
   'Arial/Arial, Helvetica, sans-serif;' +
   'Courier New/Courier New, Courier, monospace;' +
   'Georgia/Georgia, serif;' +
   'Lucida Sans Unicode/Lucida Sans Unicode, Lucida Grande, sans-serif;' +
   'Tahoma/Tahoma, Geneva, sans-serif;' +
   'Times New Roman/Times New Roman, Times, serif;' +
   'Trebuchet MS/Trebuchet MS, Helvetica, sans-serif;' +
   'Verdana/Verdana, Geneva, sans-serif';
};
