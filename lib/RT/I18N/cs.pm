# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
package RT::I18N::cs;

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
  #return( $handle->numf($num) . ' ' . $handle->numerate($num, @forms) );
  return( $handle->numerate($num, @forms) );
   # Most human languages put the number phrase before the qualified phrase.
}


sub numerate {
 # return this lexical item in a form appropriate to this number
  my($handle, $num, @forms) = @_;
  my $s = ($num == 1);

  return '' unless @forms;
  return
   $s ? $forms[0] :
   ( $num > 1 && $num < 5 ) ? $forms[1] :
   $forms[2];
}

#--------------------------------------------------------------------------

sub numf {
  my($handle, $num) = @_[0,1];
  if($num < 10_000_000_000 and $num > -10_000_000_000 and $num == int($num)) {
    $num += 0;  # Just use normal integer stringification.
         # Specifically, don't let %G turn ten million into 1E+007
  } else {
    $num = CORE::sprintf("%G", $num);
     # "CORE::" is there to avoid confusion with the above sub sprintf.
  }
  while( $num =~ s/^([-+]?\d+)(\d{3})/$1,$2/s ) {1}  # right from perlfaq5
   # The initial \d+ gobbles as many digits as it can, and then we
   #  backtrack so it un-eats the rightmost three, and then we
   #  insert the comma there.

  $num =~ tr<.,><,.> if ref($handle) and $handle->{'numf_comma'};
   # This is just a lame hack instead of using Number::Format
  return $num;
}

1;
