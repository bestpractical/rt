
package RT::I18N::i_default;
use base qw(RT::I18N);
1;

__END__

This class just zero-derives from the project base class, which
is English for this project.  i-default is "English at least".  It
wouldn't be a bad idea to make our i-default messages be English
plus, say, French -- i-default is meant to /contain/ English, not
be /just/ English.  If you have all your English messages in
Whatever::en and all your French messages in Whatever::fr, it
would be straightforward to define Whatever::i_default's as a subclass
of Whatever::en, but for every case where a key gets you a string
(as opposed to a coderef) from %Whatever::en::Lexicon and
%Whatever::fr::Lexicon, you could make %Whatever::i_default::Lexicon 
be the concatenation of them both.  So: "file '[_1]' not found.\n" and
"fichier '[_1]' non trouvé\n" could make for an
%Whatever::i_default::Lexicon entry of
"file '[_1]' not found\nfichier '[_1]' non trouvé.\n".

There may be entries, however, where that is undesirable.
And in any case, it's not feasable once you have an _AUTO lexicon
in the mix, as wo do here.



RFC 2277 says: 

4.5.  Default Language

   When human-readable text must be presented in a context where the
   sender has no knowledge of the recipient's language preferences (such
   as login failures or E-mailed warnings, or prior to language
   negotiation), text SHOULD be presented in Default Language.

   Default Language is assigned the tag "i-default" according to the
   procedures of RFC 1766. It is not a specific language, but rather
   identifies the condition where the language preferences of the user
   cannot be established.

   Messages in Default Language MUST be understandable by an English-
   speaking person, since English is the language which, worldwide, the
   greatest number of people will be able to get adequate help in
   interpreting when working with computers.

   Note that negotiating English is NOT the same as Default Language;
   Default Language is an emergency measure in otherwise unmanageable
   situations.

   In many cases, using only English text is reasonable; in some cases,
   the English text may be augumented by text in other languages.


