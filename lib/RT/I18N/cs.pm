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

package RT::I18N::cs;
use base 'RT::I18N';

use strict;
use warnings;

# # CZECH TRANSLATORS COMMENTS see Locale::Maketext::TPJ13
# Obecne parametry musi byt docela slozite (v pripade Slavistickych jazyku)
# typu pocet, slovo, pad a rod 
#
#pad 1., rod muzsky:
#0 krecku
#1 krecek
#2..4 krecci
#5.. krecku (nehodi se zde resit pravidlo mod 1,2,3,4 krom mod 11,12,13,14)
#
#0 kabatu
#1 kabat
#2..4 kabaty
#5 kabatu
#
# => Vyplati se udelat quant s parametry typu pocet, slovo1, slovo2..4, slovo5 a slovo0
#

sub quant {
  my($handle, $num, @forms) = @_;

  return $num if @forms == 0; # what should this mean?
  return $forms[3] if @forms > 3 and $num == 0; # special zeroth case

  # Normal case:
  # Note that the formatting of $num is preserved.
  return( $handle->numf($num) . ' ' . $handle->numerate($num, @forms) );
}


sub numerate {
    # return this lexical item in a form appropriate to this number
    my($handle, $num, @forms) = @_;

    return '' unless @forms;

    my $fallback = (grep defined, @forms)[0];
    return $forms[0] // $fallback if $num == 1;
    return $forms[1] // $fallback
        if $num > 1 and $num < 5;
    return $forms[2] // $fallback;
}

RT::Base->_ImportOverlays();

1;
