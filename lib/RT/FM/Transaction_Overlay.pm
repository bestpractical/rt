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

use strict;
no warnings qw/redefine/;

sub Create {
    my $self = shift;
    my %args = (
                Article => '0',
                ChangeLog => '',
                Type => '',
                Field => '',
                OldContent => '',
                NewContent => '',

          @_);

    foreach my $field qw(ChangeLog Type OldContent NewContent) {
        $args{$field} = '' unless ($args{$field});

    }

    $self->SUPER::Create(
                         Article => $args{'Article'},
                         ChangeLog => $args{'ChangeLog'},
                         Type => $args{'Type'},
                         Field => $args{'Field'},
                         OldContent => $args{'OldContent'},
                         NewContent => $args{'NewContent'},
);

}

sub Description {
    my $self = shift;
    if ($self->Type eq 'Core') { 
        return ($self->loc("[_1] changed from '[_2]' to '[_3]'",$self->Field , $self->OldContent, $self->NewContent));

    } elsif ($self->Type eq 'Link') {
    if ($self->NewContent) {
        return ($self->loc("This article now [_1] '[_2]'",$self->Field , $self->NewContent));
    } else {
        return ($self->loc("This article no longer [_1] '[_2]'",$self->Field , $self->OldContent));

    }


    } elsif ($self->Type eq 'Custom') {
        my $cf = RT::FM::CustomField->new($self->CurrentUser);
        $cf->Load($self->Field);
        
        if ($self->NewContent && $self->OldContent) {
            return $self->loc("[_1] value '[_2]' changed to '[_3]'",$cf->Name, $self->OldContent, $self->NewContent);


        } elsif ($self->NewContent) {
            return $self->loc("[_1] value '[_2]' added",$cf->Name, $self->NewContent);
        
        } elsif ($self->OldContent) {
            return $self->loc("[_1] value '[_2]' delete",$cf->Name, $self->OldContent);

        }
    } elsif ($self->Type eq 'Create') { 
            return $self->loc("Article created");
    }
     
}

1;
