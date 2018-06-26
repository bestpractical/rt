# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

use strict;
use warnings;

package RT::I18N::i_default;
use base 'RT::I18N';

RT::Base->_ImportOverlays();

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
"fichier '[_1]' non trouve\n" could make for an
%Whatever::i_default::Lexicon entry of
"file '[_1]' not found\nfichier '[_1]' non trouve.\n".

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


