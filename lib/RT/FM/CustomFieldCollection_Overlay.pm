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

=head2 LimitToClass ID

limit the set of custom fields found to ones that apply to the class which has the id "ID"

=cut


sub LimitToClass {
    my $self = shift;
    my $class = shift;

    unless ($class =~ /^\d+$/) {
        my $class_obj = RT::FM::Class->new($RT::SystemUser);
        $class_obj->Load($class);
        unless ($class_obj->Id) {
            $RT::Logger->debug($self->CurrentUser->Name ." asked to limit ".ref($self)." to unknown class ".$class);
            return;
        }
        $class = $class_obj->Id;
    }

    my $class_cfs = $self->NewAlias('FM_ClassCustomFields');
    $self->Join( ALIAS1 => 'main',
                FIELD1 => 'id',
                ALIAS2 => $class_cfs,
                FIELD2 => 'CustomField' );
    $self->Limit( ALIAS           => $class_cfs,
                 FIELD           => 'Class',
                 OPERATOR        => '=',
                 VALUE           => $class,
                 ENTRYAGGREGATOR => 'OR' );
    
    $self->OrderBy( ALIAS => $class_cfs , FIELD => "SortOrder", ORDER => 'ASC');
}

1;
