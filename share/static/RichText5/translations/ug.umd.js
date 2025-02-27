/**
 * @license Copyright (c) 2003-2025, CKSource Holding sp. z o.o. All rights reserved.
 * For licensing, see LICENSE.md or https://ckeditor.com/legal/ckeditor-licensing-options
 */

( e => {
const { [ 'ug' ]: { dictionary, getPluralForm } } = {"ug":{"dictionary":{"Words: %0":"سۆز: %0","Characters: %0":"ھەرپ: %0","Widget toolbar":"","Insert paragraph before block":"","Insert paragraph after block":"","Press Enter to type after or press Shift + Enter to type before the widget":"","Keystrokes that can be used when a widget is selected (for example: image, table, etc.)":"","Insert a new paragraph directly after a widget":"","Insert a new paragraph directly before a widget":"","Move the caret to allow typing directly before a widget":"","Move the caret to allow typing directly after a widget":"","Move focus from an editable area back to the parent widget":"","Upload in progress":"يۈكلىنىۋاتىدۇ","Undo":"يېنىۋېلىش","Redo":"تەكرارلاش","Rich Text Editor":"تېكىست تەھرىرلىگۈچ","Edit block":"بۆلەك تەھرىر","Click to edit block":"چېكىلسە بۆلەك تەھرىرلىنىدۇ","Drag to move":"يۆتكەشتە سۆرىلىدۇ","Next":"كېيىنكى","Previous":"ئالدىنقى","Editor toolbar":"تەھرىرلىگۈچ قورال بالداق","Dropdown toolbar":"سىرىلما قورال بالداق","Dropdown menu":"سىرىلما تىزىملىك","Black":"قارا","Dim grey":"سۇس كۈلرەڭ","Grey":"كۈلرەڭ","Light grey":"ئوچۇق كۈلرەڭ","White":"ئاق","Red":"قىزىل","Orange":"قىزغۇچ سېرىق","Yellow":"سېرىق","Light green":"ئوچۇق يېشىل","Green":"يېشىل","Aquamarine":"دېڭىز كۆكى","Turquoise":"","Light blue":"ئوچۇق كۆك","Blue":"كۆك","Purple":"بىنەپشە","Editor block content toolbar":"تەھرىرلىگۈچ بۆلىكى مەزمۇن قورال بالداق","Editor contextual toolbar":"تەھرىرلىگۈچ مەزمۇن قورال بالداق","HEX":"ئون ئالتىلىك","No results found":"ھېچقانداق نەتىجە تېپىلمىدى","No searchable items":"ئىزدىگۈدەك تۈر يوق","Editor dialog":"تەھرىر سۆزلەشكۈ","Close":"تاقا","Help Contents. To close this dialog press ESC.":"ياردەم مەزمۇنى. بۇ سۆزلەشكۈنى تاقاشتا ESC بېسىلىدۇ.","Below, you can find a list of keyboard shortcuts that can be used in the editor.":"تۆۋەندە تەھرىرلىگۈچتە ئىشلىتىلىدىغان ھەرپتاختا تېزلەتمە تىزىمىنى تاپالايسىز.","(may require <kbd>Fn</kbd>)":"(<kbd>Fn</kbd> ئىشلىتىش كېرەك بولۇشى مۇمكىن)","Accessibility":"زىيارەتچانلىق","Accessibility help":"زىيارەتچانلىق يارەم","Press %0 for help.":"ياردەم ئۈچۈن %0 بېسىلىدۇ","Move focus in and out of an active dialog window":"فوكۇس نۇقتىسىنى سۆزلەشكۈ كۆزنىكىگە يۆتكەيدۇ ياكى چىقىرىۋېتىدۇ","MENU_BAR_MENU_FILE":"ھۆججەت","MENU_BAR_MENU_EDIT":"تەھرىرلەش","MENU_BAR_MENU_VIEW":"كۆرۈنۈش","MENU_BAR_MENU_INSERT":"قىستۇر","MENU_BAR_MENU_FORMAT":"پىچىم","MENU_BAR_MENU_TOOLS":"قورال","MENU_BAR_MENU_HELP":"ياردەم","MENU_BAR_MENU_TEXT":"تېكىست","MENU_BAR_MENU_FONT":"خەت نۇسخا","Editor menu bar":"تەھرىرلىگۈچ قورال بالداق","Please enter a valid color (e.g. \"ff0000\").":"ئىناۋەتلىك رەڭ كودىنى كىرگۈزۈڭ (مەسىلەن، «ff0000»)","Insert table":"جەدۋەل قىستۇر","Header column":"ماۋزۇ رەت","Insert column left":"سولغا رەت قىستۇر","Insert column right":"ئوڭغا رەت قىستۇر","Delete column":"رەت ئۆچۈر","Select column":"رەت تاللا","Column":"رەت","Header row":"ماۋزۇ قۇر","Insert row below":"ئاستىغا قۇر قىستۇر","Insert row above":"ئۈستىگە قۇر قىستۇر","Delete row":"قۇر ئۆچۈر","Select row":"قۇر تاللا","Row":"قۇر","Merge cell up":"كاتەكچىنى ئۈستىگە بىرلەشتۈر","Merge cell right":"كاتەكچىنى ئوڭغا بىرلەشتۈر","Merge cell down":"كاتەكچىنى ئاستىغا بىرلەشتۈر","Merge cell left":"كاتەكچىنى سولغا بىرلەشتۈر","Split cell vertically":"كاتەكچىنى بويىغا پارچىلا","Split cell horizontally":"كاتەكچىنى توغرىسىغا پارچىلا","Merge cells":"كاتەكچە بىرلەشتۈر","Table toolbar":"جەدۋەل قورال بالداق","Table properties":"جەدۋەل خاسلىقى","Cell properties":"كاتەكچە خاسلىقى","Border":"گىرۋەك","Style":"ئۇسلۇب","Width":"كەڭلىك","Height":"ئېگىزلىك","Color":"رەڭ","Background":"تەگلىك","Padding":"ئىچكى ئارىلىقى","Dimensions":"ئۆلچىمى","Table cell text alignment":"جەدۋەل كاتەكچىسىدىكى تېكىست توغرىلىنىشى","Alignment":"توغرىلاش","Horizontal text alignment toolbar":"توغرىسىغا تېكىست توغرىلاش قورال بالدىقى","Vertical text alignment toolbar":"بويىغا تېكىست توغرىلاش قورال بالدىقى","Table alignment toolbar":"جەدۋەل توغرىلاش قورال بالدىقى","None":"يوق","Solid":"ئۇيۇل","Dotted":"چېكىتلىك","Dashed":"سىزىقچە","Double":"قوش","Groove":"ئويمان","Ridge":"چوققا","Inset":"پېتىنقى","Outset":"كۆپۈنكى","Align cell text to the left":"كاتەكچە تېكىستىنى سولغا توغرىلا","Align cell text to the center":"كاتەكچە تېكىستىنى مەركەزگە توغرىلا","Align cell text to the right":"كاتەكچە تېكىستىنى ئوڭغا توغرىلا","Justify cell text":"كاتەكچە تېكىستىنى ئوڭ سولغا توغرىلا","Align cell text to the top":"كاتەكچە تېكىستىنى چوققىغا توغرىلا","Align cell text to the middle":"كاتەكچە تېكىستىنى ئوتتۇرىغا توغرىلا","Align cell text to the bottom":"كاتەكچە تېكىستىنى ئاستىغا توغرىلا","Align table to the left":"جەدۋەلنى سولغا توغرىلا","Center table":"جەدۋەلنى ئوتتۇرىغا توغرىلا","Align table to the right":"جەدۋەلنى ئوڭغا توغرىلا","The color is invalid. Try \"#FF0000\" or \"rgb(255,0,0)\" or \"red\".":"رەڭ ئىناۋەتسىز. «#FF0000» ياكى «rgb(255,0,0)» ياكى «red» نى سىناڭ.","The value is invalid. Try \"10px\" or \"2em\" or simply \"2\".":"قىممىتى ئىناۋەتسىز. «10px» ياكى «2em» ياكى «2» نى سىناڭ.","Enter table caption":"جەدۋەل چۈشەندۈرۈشى كىرگۈزۈلىدۇ","Keystrokes that can be used in a table cell":"","Move the selection to the next cell":"","Move the selection to the previous cell":"","Insert a new table row (when in the last cell of a table)":"","Navigate through the table":"","Table":"","Styles":"ئۇسلۇب","Multiple styles":"كۆپ ئۇسلۇب","Block styles":"بۆلەك ئۇسلۇبى","Text styles":"تېكىست ئۇسلۇبى","Special characters":"","Category":"","All":"","Arrows":"","Currency":"","Latin":"","Mathematical":"","Text":"تېكىست","leftwards simple arrow":"","rightwards simple arrow":"","upwards simple arrow":"","downwards simple arrow":"","leftwards double arrow":"","rightwards double arrow":"","upwards double arrow":"","downwards double arrow":"","leftwards dashed arrow":"","rightwards dashed arrow":"","upwards dashed arrow":"","downwards dashed arrow":"","leftwards arrow to bar":"","rightwards arrow to bar":"","upwards arrow to bar":"","downwards arrow to bar":"","up down arrow with base":"","back with leftwards arrow above":"","end with leftwards arrow above":"","on with exclamation mark with left right arrow above":"","soon with rightwards arrow above":"","top with upwards arrow above":"","Dollar sign":"","Euro sign":"","Yen sign":"","Pound sign":"","Cent sign":"","Euro-currency sign":"","Colon sign":"","Cruzeiro sign":"","French franc sign":"","Lira sign":"","Currency sign":"","Bitcoin sign":"","Mill sign":"","Naira sign":"","Peseta sign":"","Rupee sign":"","Won sign":"","New sheqel sign":"","Dong sign":"","Kip sign":"","Tugrik sign":"","Drachma sign":"","German penny sign":"","Peso sign":"","Guarani sign":"","Austral sign":"","Hryvnia sign":"","Cedi sign":"","Livre tournois sign":"","Spesmilo sign":"","Tenge sign":"","Indian rupee sign":"","Turkish lira sign":"","Nordic mark sign":"","Manat sign":"","Ruble sign":"","Latin capital letter a with macron":"","Latin small letter a with macron":"","Latin capital letter a with breve":"","Latin small letter a with breve":"","Latin capital letter a with ogonek":"","Latin small letter a with ogonek":"","Latin capital letter c with acute":"","Latin small letter c with acute":"","Latin capital letter c with circumflex":"","Latin small letter c with circumflex":"","Latin capital letter c with dot above":"","Latin small letter c with dot above":"","Latin capital letter c with caron":"","Latin small letter c with caron":"","Latin capital letter d with caron":"","Latin small letter d with caron":"","Latin capital letter d with stroke":"","Latin small letter d with stroke":"","Latin capital letter e with macron":"","Latin small letter e with macron":"","Latin capital letter e with breve":"","Latin small letter e with breve":"","Latin capital letter e with dot above":"","Latin small letter e with dot above":"","Latin capital letter e with ogonek":"","Latin small letter e with ogonek":"","Latin capital letter e with caron":"","Latin small letter e with caron":"","Latin capital letter g with circumflex":"","Latin small letter g with circumflex":"","Latin capital letter g with breve":"","Latin small letter g with breve":"","Latin capital letter g with dot above":"","Latin small letter g with dot above":"","Latin capital letter g with cedilla":"","Latin small letter g with cedilla":"","Latin capital letter h with circumflex":"","Latin small letter h with circumflex":"","Latin capital letter h with stroke":"","Latin small letter h with stroke":"","Latin capital letter i with tilde":"","Latin small letter i with tilde":"","Latin capital letter i with macron":"","Latin small letter i with macron":"","Latin capital letter i with breve":"","Latin small letter i with breve":"","Latin capital letter i with ogonek":"","Latin small letter i with ogonek":"","Latin capital letter i with dot above":"","Latin small letter dotless i":"","Latin capital ligature ij":"","Latin small ligature ij":"","Latin capital letter j with circumflex":"","Latin small letter j with circumflex":"","Latin capital letter k with cedilla":"","Latin small letter k with cedilla":"","Latin small letter kra":"","Latin capital letter l with acute":"","Latin small letter l with acute":"","Latin capital letter l with cedilla":"","Latin small letter l with cedilla":"","Latin capital letter l with caron":"","Latin small letter l with caron":"","Latin capital letter l with middle dot":"","Latin small letter l with middle dot":"","Latin capital letter l with stroke":"","Latin small letter l with stroke":"","Latin capital letter n with acute":"","Latin small letter n with acute":"","Latin capital letter n with cedilla":"","Latin small letter n with cedilla":"","Latin capital letter n with caron":"","Latin small letter n with caron":"","Latin small letter n preceded by apostrophe":"","Latin capital letter eng":"","Latin small letter eng":"","Latin capital letter o with macron":"","Latin small letter o with macron":"","Latin capital letter o with breve":"","Latin small letter o with breve":"","Latin capital letter o with double acute":"","Latin small letter o with double acute":"","Latin capital ligature oe":"","Latin small ligature oe":"","Latin capital letter r with acute":"","Latin small letter r with acute":"","Latin capital letter r with cedilla":"","Latin small letter r with cedilla":"","Latin capital letter r with caron":"","Latin small letter r with caron":"","Latin capital letter s with acute":"","Latin small letter s with acute":"","Latin capital letter s with circumflex":"","Latin small letter s with circumflex":"","Latin capital letter s with cedilla":"","Latin small letter s with cedilla":"","Latin capital letter s with caron":"","Latin small letter s with caron":"","Latin capital letter t with cedilla":"","Latin small letter t with cedilla":"","Latin capital letter t with caron":"","Latin small letter t with caron":"","Latin capital letter t with stroke":"","Latin small letter t with stroke":"","Latin capital letter u with tilde":"","Latin small letter u with tilde":"","Latin capital letter u with macron":"","Latin small letter u with macron":"","Latin capital letter u with breve":"","Latin small letter u with breve":"","Latin capital letter u with ring above":"","Latin small letter u with ring above":"","Latin capital letter u with double acute":"","Latin small letter u with double acute":"","Latin capital letter u with ogonek":"","Latin small letter u with ogonek":"","Latin capital letter w with circumflex":"","Latin small letter w with circumflex":"","Latin capital letter y with circumflex":"","Latin small letter y with circumflex":"","Latin capital letter y with diaeresis":"","Latin capital letter z with acute":"","Latin small letter z with acute":"","Latin capital letter z with dot above":"","Latin small letter z with dot above":"","Latin capital letter z with caron":"","Latin small letter z with caron":"","Latin small letter long s":"","Less-than sign":"","Greater-than sign":"","Less-than or equal to":"","Greater-than or equal to":"","En dash":"","Em dash":"","Macron":"","Overline":"","Degree sign":"","Minus sign":"","Plus-minus sign":"","Division sign":"","Fraction slash":"","Multiplication sign":"","Latin small letter f with hook":"","Integral":"","N-ary summation":"","Infinity":"","Square root":"","Tilde operator":"","Approximately equal to":"","Almost equal to":"","Not equal to":"","Identical to":"","Element of":"","Not an element of":"","Contains as member":"","N-ary product":"","Logical and":"","Logical or":"","Not sign":"","Intersection":"","Union":"","Partial differential":"","For all":"","There exists":"","Empty set":"","Nabla":"","Asterisk operator":"","Proportional to":"","Angle":"","Vulgar fraction one quarter":"","Vulgar fraction one half":"","Vulgar fraction three quarters":"","Single left-pointing angle quotation mark":"","Single right-pointing angle quotation mark":"","Left-pointing double angle quotation mark":"","Right-pointing double angle quotation mark":"","Left single quotation mark":"","Right single quotation mark":"","Left double quotation mark":"","Right double quotation mark":"","Single low-9 quotation mark":"","Double low-9 quotation mark":"","Inverted exclamation mark":"","Inverted question mark":"","Two dot leader":"","Horizontal ellipsis":"","Double dagger":"","Per mille sign":"","Per ten thousand sign":"","Double exclamation mark":"","Question exclamation mark":"","Exclamation question mark":"","Double question mark":"","Copyright sign":"","Registered sign":"","Trade mark sign":"","Section sign":"","Paragraph sign":"","Reversed paragraph sign":"","Show source":"","Show blocks":"بۆلەكلەرنى كۆرسەت","Select all":"ھەممىنى تاللا","Disable editing":"","Enable editing":"","Previous editable region":"","Next editable region":"","Navigate editable regions":"","Remove Format":"پىچىمنى چىقىرىۋەت","Page break":"بەت ئايرىش بەلگىسى","media widget":"","Media URL":"","Paste the media URL in the input.":"","Tip: Paste the URL into the content to embed faster.":"","The URL must not be empty.":"","This media URL is not supported.":"","Insert media":"","Media":"","Media toolbar":"","Open media in new tab":"","Numbered List":"نومۇرلۇق تىزىملىك","Bulleted List":"بەلگە تىزىملىك","To-do List":"ئىش تىزىمى","Bulleted list styles toolbar":"تۈر بەلگە تىزىمى ئۇسلۇبىدىكى قورال بالداق","Numbered list styles toolbar":"تۈر نومۇرى تىزىمى ئۇسلۇبىدىكى قورال بالداق","Toggle the disc list style":"ئۇيۇل چەمبەر تىزىم ئۇسلۇبىغا ئالماشتۇر","Toggle the circle list style":"بوش چەمبەر تىزىم ئۇسلۇبىغا ئالماشتۇر","Toggle the square list style":"ئۇيۇل كۋادرات تىزىم ئۇسلۇبىغا ئالماشتۇر","Toggle the decimal list style":"ئونلۇق سان تىزىم ئۇسلۇبىغا ئالماشتۇر","Toggle the decimal with leading zero list style":"نۆل بىلەن باشلانغان ئونلۇق سان تىزىم ئۇسلۇبىغا ئالماشتۇر","Toggle the lower–roman list style":"كىچىك رىم رەقىمى تىزىم ئۇسلۇبىغا ئالماشتۇر","Toggle the upper–roman list style":"چوڭ رىم رەقىمى تىزىم ئۇسلۇبىغا ئالماشتۇر","Toggle the lower–latin list style":"كىچىك لاتىن رەقىمى تىزىم ئۇسلۇبىغا ئالماشتۇر","Toggle the upper–latin list style":"چوڭ لاتىن رەقىمى تىزىم ئۇسلۇبىغا ئالماشتۇر","Disc":"ئۇيۇل چەمبەر","Circle":"چەمبەر","Square":"چاسا","Decimal":"ئونلۇق كەسىر","Decimal with leading zero":"نۆل بىلەن باشلانغان ئونلۇق كەسىر","Lower–roman":"كىچىك رىم رەقىمى","Upper-roman":"چوڭ رىم رەقىمى","Lower-latin":"كىچىك لاتىن رەقىمى","Upper-latin":"چوڭ لاتىن رەقىمى","List properties":"تىزىم خاسلىقى","Start at":"باشلىنىشى","Invalid start index value.":"ئىناۋەتسىز باشلىنىش ئىندېكىس قىممىتى","Start index must be greater than 0.":"باشلىنىدىغان ئىندېكىس قىممىتى چوقۇم 0 دىن چوڭ بولۇشى كېرەك.","Reversed order":"ئەكسىچە تەرتىپ","Keystrokes that can be used in a list":"تىزىمدا ئىشلەتكىلى بولىدىغان كۇنۇپكا بېسىلىشى","Increase list item indent":"تىزىم تۈرىنى تارايتىشنى ئاشۇرىدۇ","Decrease list item indent":"تىزىم تۈرىنى تارايتىشنى كېمەيتىدۇ","Entering a to-do list":"ئىش تىزىمىنى كىرگۈزۈۋاتىدۇ","Leaving a to-do list":"ئىش تىزىمىدىن ئايرىلىۋاتىدۇ","Unlink":"ئۇلانمىنى ئۈزۈش","Link":"ئۇلانما","Link URL":"ئۇلاش ئادىرسى","Link URL must not be empty.":"ئۇلانما تور ئادرېسى بوش قالدۇرۇلمايدۇ.","Link image":"ئۇلانما سۈرەت","Edit link":"ئۇلانما تەھرىر","Open link in new tab":"ئۇلانمىنى يېڭى بەتكۈچتە ئاچ","This link has no URL":"بۇ ئۇلانمىنىڭ تور ئادرېسى يوق","Open in a new tab":"يېڭى بەتكۈچتە ئاچ","Downloadable":"چۈشۈرۈشچان","Create link":"ئۇلانما قۇر","Move out of a link":"ئۇلانمىنى چىقىرىۋەت","Scroll to target":"","Language":"تىل","Choose language":"تىل تاللاش","Remove language":"تىلنى چىقىرىۋەت","Increase indent":"تارايتىشنى ئاشۇر","Decrease indent":"تارايتىشنى كېمەيت","image widget":"رەسىمچىك","Wrap text":"تېكىست چۆرىدەت","Break text":"تېكىست ئۈز","In line":"قۇردا","Side image":"يان رەسىم","Full size image":"ئەسلى چوڭلۇقتىكى رەسىم","Left aligned image":"سولغا توغۇرلانغان رەسىم","Centered image":"ئوتتۇردىكى رەسىم","Right aligned image":"ئوڭغا توغۇرلانغان رەسىم","Change image text alternative":"رەسىملىك تېكىست تاللىغۇچنى ئۆزگەرتىش","Text alternative":"تېكىست ئاملاشتۇرۇش","Enter image caption":"رەسىمنىڭ تېمىسىنى كىرگۈزۈڭ","Insert image":"رەسىم قىستۇرۇش","Replace image":"سۈرەت ئالماشتۇر","Upload from computer":"كومپيۇتېردىن يۈكلە","Replace from computer":"كومپيۇتېردىن ئالماشتۇر","Upload image from computer":"سۈرەتنى كومپيۇتېردىن يۈكلە","Image from computer":"كومپيۇتېردىن سۈرەت تاللاڭ","From computer":"كومپيۇتېردىن","Replace image from computer":"سۈرەتنى كومپيۇتېردىن ئالماشتۇرىدۇ","Upload failed":"چىقىرىش مەغلۇپ بولدى","You have no image upload permissions.":"سۈرەت يۈكلەش ئىجازىتىڭىز يوق.","Image toolbar":"سۈرەت قورال بالداق","Resize image":"سۈرەت چوڭلۇقىنى تەڭشە","Resize image to %0":"سۈرەت چوڭلۇقىنى %0 كە تەڭشە","Resize image to the original size":"سۈرەت چوڭلۇقىنى ئەسلى چوڭلۇقىغا تەڭشەيدۇ","Resize image (in %0)":"سۈرەت چوڭلۇقىنى تەڭشە (بىرلىكى %0)","Original":"ئەسلى","Custom image size":"ئىختىيارى سۈرەت چوڭلۇقى","Custom":"ئىختىيارى","Image resize list":"سۈرەت چوڭلۇقىنى تەڭشەش تىزىمى","Insert image via URL":"سۈرەتنى تور ئادرېسىدىن قىستۇر","Insert via URL":"تور ئادرېسىدىن قىستۇر","Image via URL":"تور ئادرېسىدىن كەلگەن سۈرەت","Via URL":"تور ئادرېسى ئارقىلىق","Update image URL":"سۈرەت تور ئادرېسىنى يېڭىلا","Caption for the image":"سۈرەت چۈشەندۈرۈشى","Caption for image: %0":"سۈرەت چۈشەندۈرۈشى: %0","The value must not be empty.":"قىممىتى بوش قالدۇرۇلمايدۇ.","The value should be a plain number.":"مەزكۇر قىممەت سان بولۇشى كېرەك.","Uploading image":"سۈرەت يۈكلەۋاتىدۇ","Image upload complete":"سۈرەت يۈكلەش تامام","Error during image upload":"سۈرەت يۈكلەشتە خاتالىق كۆرۈلدى","Image":"سۈرەت","HTML object":"HTML جىسىم","Insert HTML":"","HTML snippet":"","Paste raw HTML here...":"","Edit source":"","Save changes":"","No preview available":"","Empty snippet content":"","Horizontal line":"توغرىسىغا سىزىق","Yellow marker":" سېرىق بەلگە","Green marker":"يېشىل بەلگە","Pink marker":"ھالرەڭ بەلگە","Blue marker":"كۆك بەلگە","Red pen":"قىزىل قەلەم","Green pen":"يېشىل قەلەم","Remove highlight":"يورۇتۇشنى چىقىرىۋەت","Highlight":"يورۇت","Text highlight toolbar":"تېكىست يورۇتۇش قورال بالدىقى","Heading":"ماۋزۇ","Choose heading":"ماۋزۇ تاللاش","Heading 1":"ماۋزۇ 1","Heading 2":"ماۋزۇ 2","Heading 3":"ماۋزۇ 3","Heading 4":"ماۋزۇ 4","Heading 5":"ماۋزۇ 5","Heading 6":"ماۋزۇ 6","Type your title":"ماۋزۇ كىرگۈزۈلىدۇ","Type or paste your content here.":"مەزمۇن بۇ جايغا كىرگۈزۈلىدۇ ياكى چاپلىنىدۇ.","Font Size":"خەت چوڭلۇقى","Tiny":"ئەڭ كىچىك","Small":"كىچىك","Big":"چوڭ","Huge":"زور","Font Family":"خەت نۇسخىسى","Default":"سۈكۈتتىكى","Font Color":"خەت رەڭگى","Font Background Color":"خەت تەگلىك رەڭگى","Document colors":"پۈتۈك رەڭگى","Find and replace":"ئىزدە ۋە ئالماشتۇر","Find in text…":"تېكىستتىن ئىزدە…","Find":"ئىزدە","Previous result":"ئالدىنقى نەتىجە","Next result":"كېيىنكى نەتىجە","Replace":"ئالماشتۇر","Replace all":"ھەممىنى ئالماشتۇر","Match case":"چوڭ كىچىك ھەرپنى پەرقلەندۈر","Whole words only":"سۆزلا","Replace with…":"ئالماشتۇرۇلۇدىغىنى…","Text to find must not be empty.":"ئىزدەيدىغان تېكىست بوش قالدۇرۇلمايدۇ.","Tip: Find some text first in order to replace it.":"ئەسكەرتىش: ئاۋال ئىزدەپ ئاندىن ئالماشتۇرىدۇ.","Advanced options":"","Find in the document":"","Insert a soft break (a <code>&lt;br&gt;</code> element)":"","Insert a hard break (a new paragraph)":"","Emoji":"","Show all emoji...":"","Find an emoji (min. 2 characters)":"","No emojis were found matching \"%0\".":"","Keep on typing to see the emoji.":"","The query must contain at least two characters.":"","Smileys & Expressions":"","Gestures & People":"","Animals & Nature":"","Food & Drinks":"","Travel & Places":"","Activities":"","Objects":"","Symbols":"","Flags":"","Select skin tone":"","Default skin tone":"","Light skin tone":"","Medium Light skin tone":"","Medium skin tone":"","Medium Dark skin tone":"","Dark skin tone":"","Cancel":"ۋاز كەچ","Clear":"تازىلا","Remove color":"رەڭنى چىقىرىۋەت","Restore default":"كۆڭۈلدىكىگە قايتۇر","Save":"ساقلا","Show more items":"تېخىمۇ كۆپ تۈرنى كۆرسەت","%0 of %1":"%0 / %1","Cannot upload file:":"يۈكلەشكە بولمايدىغان ھۆججەت:","Rich Text Editor. Editing area: %0":"مول تېكىست تەھرىرلىگۈچ. تەھرىرلەش رايونى: %0","Insert with file manager":"ھۆججەت باشقۇرغۇچ بىلەن قىستۇر","Replace with file manager":"ھۆججەت باشقۇرغۇچتا ئالماشتۇر","Insert image with file manager":"سۈرەتنى ھۆججەت باشقۇرغۇچ بىلەن قىستۇرىدۇ","Replace image with file manager":"سۈرەتنى ھۆججەت باشقۇرغۇچ بىلەن ئالماشتۇرىدۇ","File":"ھۆججەت","With file manager":"ھۆججەت باشقۇرغۇچ بىلەن","Toggle caption off":"جەدۋەل ماۋزۇسى تاقاق","Toggle caption on":"جەدۋەل ماۋزۇسى ئوچۇق","Content editing keystrokes":"مەزمۇن تەھرىرلەش كۇنۇپكا بېسىلىشى","These keyboard shortcuts allow for quick access to content editing features.":"","User interface and content navigation keystrokes":"","Use the following keystrokes for more efficient navigation in the CKEditor 5 user interface.":"","Close contextual balloons, dropdowns, and dialogs":"","Open the accessibility help dialog":"","Move focus between form fields (inputs, buttons, etc.)":"","Move focus to the menu bar, navigate between menu bars":"","Move focus to the toolbar, navigate between toolbars":"","Navigate through the toolbar or menu bar":"","Execute the currently focused button. Executing buttons that interact with the editor content moves the focus back to the content.":"","Accept":"قوشۇل","Paragraph":"ئابزاس","Color picker":"رەڭ تاللىغۇچ","Please try a different phrase or check the spelling.":"","Source":"","Insert code block":"كود بۆلىكى قىستۇر","Plain text":"ساپ تېكىست","Leaving %0 code snippet":"","Entering %0 code snippet":"","Entering code snippet":"","Leaving code snippet":"","Code block":"","Copy selected content":"","Paste content":"","Paste content as plain text":"","Insert image or file":"رەسىم ياكى ھۆججەت قىستۇر","Could not obtain resized image URL.":"چوڭلۇقى تەڭشەلگەن سۈرەتنىڭ تور ئادرېسىغا ئېرىشەلمىدى","Selecting resized image failed":"چوڭلۇقى تەڭشەلگن سۈرەتنى تاللىيالمىدى","Could not insert image at the current position.":"نۆۋەتتە ئورۇنغا سۈرەتنى قىستۇرالمايدۇ.","Inserting image failed":"سۈرەت قىستۇرالمىدى","Open file manager":"ھۆججەت باشقۇرغۇچنى ئاچ","Cannot determine a category for the uploaded file.":"يۈكلەيدىغان ھۆججەتنىڭ تۈرىنى جەزملىيەلمىدى.","Cannot access default workspace.":"كۆڭۈلدىكى خىزمەت بوشلۇقىنى زىيارەت قىلالمايدۇ","You have no image editing permissions.":"","Edit image":"","Processing the edited image.":"","Server failed to process the image.":"","Failed to determine category of edited image.":"","Bookmark":"","Insert":"","Update":"","Edit bookmark":"","Remove bookmark":"","Bookmark name":"","Enter the bookmark name without spaces.":"","Bookmark must not be empty.":"","Bookmark name cannot contain space characters.":"","Bookmark name already exists.":"","bookmark widget":"","Block quote":"نەقىل","Bold":"توم","Italic":"يانتۇ","Underline":"ئاستى سىزىق","Code":"كود","Strikethrough":"ئۆچۈرۈش سىزىقى","Subscript":"ئاستبەلگە","Superscript":"ئۈستبەلگە","Italic text":"يانتۇ تېكىست","Move out of an inline code style":"ئىچكى كود ئۇسلۇبىنى چىقىرىۋەت","Bold text":"توم تېكىست","Underline text":"ئاستى سىزىق تېكىست","Strikethrough text":"ئۆچۈرۈش سىزىقى تېكىست","Saving changes":"ئۆزگەرتىشلەرنى ساقلاش","Revert autoformatting action":"ئۆزلۈكىدىن پىچىم مەشغۇلاتىنى ئەسلىگە قايتۇرىدۇ","Align left":"سولغا توغرىلاش","Align right":"ئوڭغا توغرىلاش","Align center":"ئوتتۇرىغا توغرىلاش","Justify":"ئوڭ سولدىن توغرىلا","Text alignment":"تېكىست توغرىلاش","Text alignment toolbar":"تېكىست توغرىلاش قورالبالدىقى"},getPluralForm(n){return 0;}}};
e[ 'ug' ] ||= { dictionary: {}, getPluralForm: null };
e[ 'ug' ].dictionary = Object.assign( e[ 'ug' ].dictionary, dictionary );
e[ 'ug' ].getPluralForm = getPluralForm;
} )( window.CKEDITOR_TRANSLATIONS ||= {} );
