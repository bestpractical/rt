# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002-2003 Jesse Vincent <jesse@bestpractical.com>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License 
#  as published by the Free Software Foundation.
# 
#  A copy of that license should have arrived with this
#  software, but in any event can be snarfed from www.gnu.org.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
# END LICENSE BLOCK

no warnings qw/redefine/;
use strict;

# {{{ sub HasEntryForClass
          
=item HasEntryForClass CLASS_ID

If this Collection has an entry for the class with the id CLASS_ID returns that entry. Otherwise returns
undef

=cut

sub HasEntryForClass {
    my $self = shift;
    my $id = shift;

    my @items = grep {$_->Class == $id } @{$self->ItemsArrayRef};

    if ($#items > 1) {
    die "$self HasEntry had a list with more than one of $id in it. this can never happen";
    }

    if ($#items == -1 ) {
    return undef;
    }
    else {
    return ($items[0]);
    }  

}
# }}}

# {{{ sub HasEntryForCustomField
          
=item HasEntryForCustomField CustomField_ID

If this Collection has an entry for the CustomField with the id CustomField_ID returns that entry. Otherwise returns
undef

=cut

sub HasEntryForCustomField {
    my $self = shift;
    my $id = shift;

    my @items = grep {$_->CustomField == $id } @{$self->ItemsArrayRef};

    if ($#items > 1) {
    die "$self HasEntry had a list with more than one of $id in it. this can never happen";
    }

    if ($#items == -1 ) {
    return undef;
    }
    else {
    return ($items[0]);
    }  

}

1;

