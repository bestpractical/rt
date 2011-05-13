/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.editorConfig = function( config )
{
	// Define changes to default configuration here. For example:
	// config.language = 'fr';
	// config.uiColor = '#AADC6E';
  config.toolbar = 'Full';

config.toolbar_Full =
[
    ['Cut','Copy','Paste','PasteText','PasteFromWord'],
    ['Undo','Redo','-','-','SelectAll','RemoveFormat'],
    ['Table','HorizontalRule','SpecialChar'],
    '/',
    ['Bold','Italic','Underline','Strike'],
    ['NumberedList','BulletedList','-','Outdent','Indent'],
    ['JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock'],
    '/',
    ['Format','Font','FontSize'],
    ['TextColor'],
    ['Link']
];

config.enterMode = CKEDITOR.ENTER_BR;
config.shiftEnterMode = CKEDITOR.ENTER_P;
config.enableTabKeyTools = true;
config.htmlEncodeOutput = false;

config.disableNativeSpellChecker = false;
config.browserContextMenuOnCtrl = true;


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
