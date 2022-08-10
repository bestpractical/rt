/**
 * @license Copyright (c) 2003-2019, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see https://ckeditor.com/legal/ckeditor-oss-license
 */

CKEDITOR.editorConfig = function( config ) {
	// Define changes to default configuration here.
	// For complete reference see:
	// https://ckeditor.com/docs/ckeditor4/latest/api/CKEDITOR_config.html

    	config.toolbarGroups = [
    		{ name: 'styles', groups: [ 'styles' ] },
    		{ name: 'colors', groups: [ 'colors' ] },
    		{ name: 'clipboard', groups: [ 'clipboard', 'undo' ] },
    		{ name: 'editing', groups: [ 'find', 'selection', 'spellchecker', 'editing' ] },
    		{ name: 'links', groups: [ 'links' ] },
    		{ name: 'insert', groups: [ 'insert' ] },
    		{ name: 'forms', groups: [ 'forms' ] },
    		{ name: 'tools', groups: [ 'tools' ] },
    		{ name: 'document', groups: [ 'mode', 'document', 'doctools' ] },
    		{ name: 'others', groups: [ 'others' ] },
    		{ name: 'basicstyles', groups: [ 'basicstyles', 'cleanup' ] },
    		{ name: 'paragraph', groups: [ 'list', 'indent', 'blocks', 'align', 'bidi', 'paragraph' ] },
    		{ name: 'about', groups: [ 'about' ] }
    	];

    	config.removeButtons = 'Underline,Subscript,Superscript,About,Link,Image,HorizontalRule,SpecialChar,Source,DocProps,Unlink,Anchor,Strike,Cut,Copy,Outdent,Indent';

	// Simplify the dialog windows.
	config.removeDialogTabs = 'image:advanced;link:advanced';
    if ( RT.Config.WebDefaultStylesheet.match(/dark/) ) {
        config.contentsCss = [ RT.Config.WebPath + '/static/RichText/contents.css', RT.Config.WebPath + '/static/RichText/contents-dark.css' ];
    }

    config.disableNativeSpellChecker = false;
};
