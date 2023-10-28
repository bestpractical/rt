# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2023 Best Practical Solutions, LLC
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

package RT::Attribute;

use strict;
use warnings;

use base 'RT::Record';

sub Table {'Attributes'}

use Storable qw/nfreeze thaw/;
use MIME::Base64;
use RT::URI::attribute;


=head1 NAME

  RT::Attribute_Overlay 

=head1 Content

=cut

# the acl map is a map of "name of attribute" and "what right the user must have on the associated object to see/edit it

our $ACL_MAP = {
    SavedSearch => { create => 'EditSavedSearches',
                     update => 'EditSavedSearches',
                     delete => 'EditSavedSearches',
                     display => 'ShowSavedSearches' },

};

# There are a number of attributes that users should be able to modify for themselves, such as saved searches
#  we could do this with a different set of "update" rights, but that gets very hacky very fast. this is even faster and even
# hackier. we're hardcoding that a different set of rights are needed for attributes on oneself
our $PERSONAL_ACL_MAP = { 
    SavedSearch => { create => 'ModifySelf',
                     update => 'ModifySelf',
                     delete => 'ModifySelf',
                     display => 'allow' },

};

=head2 LookupObjectRight { ObjectType => undef, ObjectId => undef, Name => undef, Right => { create, update, delete, display } }

Returns the right that the user needs to have on this attribute's object to perform the related attribute operation. Returns "allow" if the right is otherwise unspecified.

=cut

sub LookupObjectRight { 
    my $self = shift;
    my %args = ( ObjectType => undef,
                 ObjectId => undef,
                 Right => undef,
                 Name => undef,
                 @_);

    # if it's an attribute on oneself, check the personal acl map
    if (($args{'ObjectType'} eq 'RT::User') && ($args{'ObjectId'} eq $self->CurrentUser->Id)) {
    return('allow') unless ($PERSONAL_ACL_MAP->{$args{'Name'}});
    return('allow') unless ($PERSONAL_ACL_MAP->{$args{'Name'}}->{$args{'Right'}});
    return($PERSONAL_ACL_MAP->{$args{'Name'}}->{$args{'Right'}}); 

    }
   # otherwise check the main ACL map
    else {
    return('allow') unless ($ACL_MAP->{$args{'Name'}});
    return('allow') unless ($ACL_MAP->{$args{'Name'}}->{$args{'Right'}});
    return($ACL_MAP->{$args{'Name'}}->{$args{'Right'}}); 
    }
}




=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'Name'.
  varchar(255) 'Content'.
  varchar(16) 'ContentType',
  varchar(64) 'ObjectType'.
  int(11) 'ObjectId'.

You may pass a C<Object> instead of C<ObjectType> and C<ObjectId>.

=cut




sub Create {
    my $self = shift;
    my %args = ( 
                Name => '',
                Description => '',
                Content => '',
                ContentType => '',
                Object => undef,
                RecordTransaction => undef,
                @_);

    if ($args{Object} and UNIVERSAL::can($args{Object}, 'Id')) {
        $args{ObjectType} = $args{Object}->isa("RT::CurrentUser") ? "RT::User" : ref($args{Object});
        $args{ObjectId} = $args{Object}->Id;
    } else {
        return(0, $self->loc("Required parameter '[_1]' not specified", 'Object'));

    }
   
    # object_right is the right that the user has to have on the object for them to have $right on this attribute
    my $object_right = $self->LookupObjectRight(
        Right      => 'create',
        ObjectId   => $args{'ObjectId'},
        ObjectType => $args{'ObjectType'},
        Name       => $args{'Name'}
    );
    if ($object_right eq 'deny') { 
        return (0, $self->loc('Permission Denied'));
    } 
    elsif ($object_right eq 'allow') {
        # do nothing, we're ok
    }
    elsif (!$self->CurrentUser->HasRight( Object => $args{Object}, Right => $object_right)) {
        return (0, $self->loc('Permission Denied'));
    }

   
    if (ref ($args{'Content'}) ) { 
        eval  {$args{'Content'} = $self->_SerializeContent($args{'Content'}); };
        if ($@) {
         return(0, $@);
        }
        $args{'ContentType'} = 'storable';
    }

    $args{'RecordTransaction'} //= 1 if $args{'Name'} =~ /^(?:SavedSearch|Dashboard|Subscription)$/;

    $RT::Handle->BeginTransaction if $args{'RecordTransaction'};
    my @return = $self->SUPER::Create(
        Name        => $args{'Name'},
        Content     => $args{'Content'},
        ContentType => $args{'ContentType'},
        Description => $args{'Description'},
        ObjectType  => $args{'ObjectType'},
        ObjectId    => $args{'ObjectId'},
    );


    if ( $args{'RecordTransaction'} ) {
        if ( $return[0] ) {
            my ( $ret, $msg ) = $self->_NewTransaction( Type => 'Create' );
            if ($ret) {
                ( $ret, $msg ) = $self->AddAttribute(
                    Name    => 'ContentHistory',
                    Content => $self->_DeserializeContent( $args{'Content'} ) || {},
                );
            }

            @return = ( $ret, $msg ) unless $ret;
        }

        if ( $return[0] ) {
            $RT::Handle->Commit;
        }
        else {
            $RT::Handle->Rollback;
        }
    }

    $self->_SyncLinks if $return[0];
    return wantarray ? @return : $return[0];
}



=head2  LoadByNameAndObject (Object => OBJECT, Name => NAME)

Loads the Attribute named NAME for Object OBJECT.

=cut

sub LoadByNameAndObject {
    my $self = shift;
    my %args = (
        Object => undef,
        Name  => undef,
        @_,
    );

    return (
        $self->LoadByCols(
            Name => $args{'Name'},
            ObjectType => ref($args{'Object'}),
            ObjectId => $args{'Object'}->Id,
        )
    );

}



=head2 _DeserializeContent

DeserializeContent returns this Attribute's "Content" as a hashref.


=cut

sub _DeserializeContent {
    my $self = shift;
    my $content = shift;

    my $hashref;
    eval {$hashref  = thaw(decode_base64($content))} ; 
    if ($@) {
        $RT::Logger->error("Deserialization of attribute ".$self->Id. " failed");
    }

    return($hashref);

}


=head2 Content

Returns this attribute's content. If it's a scalar, returns a scalar
If it's data structure returns a ref to that data structure.

=cut

sub Content {
    my $self = shift;
    # Here we call _Value to get the ACL check.
    my $content = $self->_Value('Content');
    if ( ($self->__Value('ContentType') || '') eq 'storable') {
        eval {$content = $self->_DeserializeContent($content); };
        if ($@) {
            $RT::Logger->error("Deserialization of content for attribute ".$self->Id. " failed. Attribute was: ".$content);
        }
    } 

    return($content);

}

sub _SerializeContent {
    my $self = shift;
    my $content = shift;
    local $Storable::canonical = 1;
    return( encode_base64(nfreeze($content)));
}


sub SetContent {
    my $self = shift;
    my %args = ( Content => undef, SyncLinks => 1, @_ % 2 ? ( Content => @_ ) : @_ );
    my $content = $args{Content};

    # Call __Value to avoid ACL check.
    if ( ($self->__Value('ContentType')||'') eq 'storable' ) {
        # We eval the serialization because it will lose on a coderef.
        $content = eval { $self->_SerializeContent($content) };
        if ($@) {
            $RT::Logger->error("Content couldn't be frozen: $@");
            return(0, "Content couldn't be frozen");
        }
    }
    my ( $ok, $msg )
        = $self->_Set( Field => 'Content', Value => $content, RecordTransaction => $args{RecordTransaction} );
    if ($ok) {
        $self->_SyncLinks if $args{SyncLinks};
        return ( $ok, $self->loc("Attribute updated") );
    }
    return ($ok, $msg);
}

=head2 SubValue KEY

Returns the subvalue for $key.


=cut

sub SubValue {
    my $self = shift;
    my $key = shift;
    my $values = $self->Content();
    return undef unless ref($values);
    return($values->{$key});
}

=head2 DeleteSubValue NAME

Deletes the subvalue with the key NAME

=cut

sub DeleteSubValue {
    my $self = shift;
    my $key = shift;
    my $values = $self->Content();
    delete $values->{$key};
    $self->SetContent($values);
}


=head2 DeleteAllSubValues 

Deletes all subvalues for this attribute

=cut


sub DeleteAllSubValues {
    my $self = shift; 
    $self->SetContent({});
}

=head2 SetSubValues  {  }

Takes a hash of keys and values and stores them in the content of this attribute.

Each key B<replaces> the existing key with the same name

Returns a tuple of (status, message)

=cut


sub SetSubValues {
   my $self = shift;
   my %args = (@_); 
   my $values = ($self->Content() || {} );
   foreach my $key (keys %args) {
    $values->{$key} = $args{$key};
   }

   $self->SetContent($values);

}

=head2 Object

Returns the object current attribute belongs to.

CAVEAT: the returned object is cached, reload it to get the latest data.

=cut

sub Object {
    my $self = shift;
    unless ( $self->{_cached}{Object} ) {
        my $object_type = $self->__Value('ObjectType');
        my $object;
        eval { $object = $object_type->new( $self->CurrentUser ) };
        unless ( UNIVERSAL::isa( $object, $object_type ) ) {
            $RT::Logger->error( "Attribute " . $self->Id . " has a bogus object type - $object_type (" . $@ . ")" );
            return (undef);
        }
        $object->Load( $self->__Value('ObjectId') );
        $self->{_cached}{Object} = $object;
    }
    return $self->{_cached}{Object};
}


sub Delete {
    my $self = shift;
    my %args = (
        RecordTransaction => undef,
        @_,
    );

    unless ( $self->CurrentUserHasRight('delete') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    # Get values even if current user doesn't have right to see
    my $name = $self->__Value('Name');
    my @links;
    if ( $name eq 'Dashboard' || $name =~ /DefaultDashboard$/ ) {
        push @links, @{ $self->DependsOn->ItemsArrayRef };
    }

    if ( $name =~ /^(?:Dashboard|SavedSearch)$/ ) {
        push @links, @{ $self->DependedOnBy->ItemsArrayRef };
    }

    $args{'RecordTransaction'} //= 1 if $name =~ /^(?:SavedSearch|Dashboard|Subscription)$/;
    $RT::Handle->BeginTransaction if $args{'RecordTransaction'};

    my @return = $self->SUPER::Delete(@_);

    if ( $args{'RecordTransaction'} ) {
        if ( $return[0] ) {
            my $txn = RT::Transaction->new( $self->CurrentUser );
            my ( $ret, $msg ) = $txn->Create(
                ObjectId   => $self->Id,
                ObjectType => ref($self),
                Type       => 'Delete',
            );
            @return = ( $ret, $msg ) unless $ret;
        }

        if ( $return[0] ) {
            $RT::Handle->Commit;
        }
        else {
            $RT::Handle->Rollback;
        }
    }

    if ( $return[0] ) {
        for my $link (@links) {
            my ( $ret, $msg ) = $link->Delete;
            if ( !$ret ) {
                RT->Logger->error( "Couldn't delete link #" . $link->id . ": $msg" );
            }
        }

        if ( $name eq 'SavedSearch' ) {
            my $shortener = RT::Shortener->new( $self->CurrentUser );
            $shortener->LoadByContent( 'SavedSearchId=' . $self->Id );
            if ( $shortener->Id ) {
                my ( $ret, $msg ) = $shortener->Delete;
                if ( !$ret ) {
                    RT->Logger->error( "Couldn't delete shortener #" . $shortener->Id . ": $msg" );
                }
            }
        }
    }

    return @return;
}


sub _Value {
    my $self = shift;
    unless ($self->CurrentUserHasRight('display')) {
        return (0,$self->loc('Permission Denied'));
    }

    return($self->SUPER::_Value(@_));


}


sub _Set {
    my $self = shift;
    my %args = (
        Field             => undef,
        Value             => undef,
        RecordTransaction => undef,
        TransactionType   => 'Set',
        @_
    );

    unless ( $self->CurrentUserHasRight('update') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    # Get values even if current user doesn't have right to see
    $args{'RecordTransaction'} //= 1 if $self->__Value('Name') =~ /^(?:SavedSearch|Dashboard|Subscription)$/;
    my $old_value = $self->__Value( $args{'Field'} ) if $args{'RecordTransaction'};

    $RT::Handle->BeginTransaction if $args{'RecordTransaction'};

    # Set the new value
    my @return = $self->SUPER::_Set(
        Field => $args{'Field'},
        Value => $args{'Value'},
    );

    if ( $args{'RecordTransaction'} ) {
        if ( $return[0] ) {
            my ( $new_ref, $old_ref );

            my %opt = (
                Type  => $args{'TransactionType'},
                Field => $args{'Field'},
            );
            if ( $args{'Field'} eq 'Content' ) {

                $opt{ReferenceType} = 'RT::Attribute';

                my $attrs = $self->Attributes;
                $attrs->Limit( FIELD => 'Name', VALUE => 'ContentHistory' );
                $attrs->OrderByCols( { FIELD => 'id', ORDER => 'DESC' } );
                if ( my $old_content = $attrs->First ) {
                    $opt{OldReference} = $old_content->id;
                }
                else {
                    RT->Logger->debug("Couldn't find ContentHistory, creating one from old value");
                    my ( $ret, $msg ) = $self->AddAttribute(
                        Name    => 'ContentHistory',
                        Content => $self->__Value('ContentType') eq 'storable'
                        ? $self->_DeserializeContent($old_value)
                        : $old_value,
                    );
                    if ($ret) {
                        $opt{OldReference} = $ret;
                    }
                    else {
                        @return = ( $ret, $msg );
                    }
                }

                if ( $return[0] ) {
                    my ( $ret, $msg ) = $self->AddAttribute(
                        Name    => 'ContentHistory',
                        Content => $self->_DeserializeContent( $args{'Value'} ),
                        Content => $self->__Value('ContentType') eq 'storable'
                        ? $self->_DeserializeContent( $args{'Value'} )
                        : $args{'Value'},
                    );

                    if ($ret) {
                        $opt{NewReference} = $ret;
                    }
                    else {
                        @return = ( $ret, $msg );
                    }
                }
            }
            else {
                $opt{'OldValue'} = $old_value;
                $opt{'NewValue'} = $args{'Value'};
            }

            if ( $return[0] ) {
                my ( $ret, $msg ) = $self->_NewTransaction(%opt);
                @return = ( $ret, $msg ) unless $ret;
            }
        }

        if ( $return[0] ) {
            $RT::Handle->Commit;
        }
        else {
            $RT::Handle->Rollback;
        }
    }

    return wantarray ? @return : $return[0];
}


=head2 CurrentUserHasRight

One of "display" "update" "delete" or "create" and returns 1 if the user has that right for attributes of this name for this object.Returns undef otherwise.

=cut

sub CurrentUserHasRight {
    my $self = shift;
    my $right = shift;

    # object_right is the right that the user has to have on the object for them to have $right on this attribute
    my $object_right = $self->LookupObjectRight(
        Right      => $right,
        ObjectId   => $self->__Value('ObjectId'),
        ObjectType => $self->__Value('ObjectType'),
        Name       => $self->__Value('Name')
    );
   
    return (1) if ($object_right eq 'allow');
    return (0) if ($object_right eq 'deny');
    return(1) if ($self->CurrentUser->HasRight( Object => $self->Object, Right => $object_right));
    return(0);

}


=head1 TODO

We should be deserializing the content on load and then never again, rather than at every access

=cut








=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 Name

Returns the current value of Name.
(In the database, Name is stored as varchar(255).)



=head2 SetName VALUE


Set Name to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(255).)


=cut


=head2 Description

Returns the current value of Description.
(In the database, Description is stored as varchar(255).)



=head2 SetDescription VALUE


Set Description to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)


=cut


=head2 Content

Returns the current value of Content.
(In the database, Content is stored as blob.)



=head2 SetContent VALUE


Set Content to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Content will be stored as a blob.)


=cut


=head2 ContentType

Returns the current value of ContentType.
(In the database, ContentType is stored as varchar(16).)



=head2 SetContentType VALUE


Set ContentType to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ContentType will be stored as a varchar(16).)


=cut


=head2 ObjectType

Returns the current value of ObjectType.
(In the database, ObjectType is stored as varchar(64).)



=head2 SetObjectType VALUE


Set ObjectType to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectType will be stored as a varchar(64).)


=cut


=head2 ObjectId

Returns the current value of ObjectId.
(In the database, ObjectId is stored as int(11).)



=head2 SetObjectId VALUE


Set ObjectId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectId will be stored as a int(11).)


=cut


=head2 Creator

Returns the current value of Creator.
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created.
(In the database, Created is stored as datetime.)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy.
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated.
(In the database, LastUpdated is stored as datetime.)


=cut



sub _CoreAccessible {
    {

        id =>
                {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Name =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        Description =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        Content =>
                {read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'blob', default => ''},
        ContentType =>
                {read => 1, write => 1, sql_type => 12, length => 16,  is_blob => 0,  is_numeric => 0,  type => 'varchar(16)', default => ''},
        ObjectType =>
                {read => 1, write => 1, sql_type => 12, length => 64,  is_blob => 0,  is_numeric => 0,  type => 'varchar(64)', default => ''},
        ObjectId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Creator =>
                {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created =>
                {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy =>
                {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated =>
                {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},

 }
};

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);
    $deps->Add( out => $self->Object );

    # dashboards in menu attribute has dependencies on each of its dashboards
    if ($self->Name =~ /^(?:Pref-)?DashboardsInMenu$/) {
        my $content = $self->Content;
        for my $pane (values %{ $content || {} }) {
            for my $dash_id (@$pane) {
                my $attr = RT::Attribute->new($self->CurrentUser);
                $attr->LoadById($dash_id);
                $deps->Add( out => $attr );
            }
        }
    }
    # DefaultDashboard has id of dashboard it uses
    elsif ($self->Name =~ /DefaultDashboard$/) {
        my $attr = RT::Attribute->new( $self->CurrentUser );
        $attr->LoadById($self->Content);
        $deps->Add( out => $attr ) if $attr->Id;
    }
    # dashboards have dependencies on all the searches and dashboards they use
    elsif ($self->Name eq 'Dashboard' || $self->Name eq 'SelfServiceDashboard') {
        my $content = $self->Content;
        for my $pane (values %{ $content->{Panes} || {} }) {
            for my $component (@$pane) {
                if ($component->{portlet_type} eq 'search' || $component->{portlet_type} eq 'dashboard') {
                    my $attr = RT::Attribute->new($self->CurrentUser);
                    $attr->LoadById($component->{id});
                    $deps->Add( out => $attr );
                }
            }
        }
    }
    # each subscription depends on its dashboard
    elsif ($self->Name eq 'Subscription') {
        my $content = $self->Content;
        my $attr = RT::Attribute->new($self->CurrentUser);
        $attr->LoadById($content->{DashboardId});
        $deps->Add( out => $attr );
    }

    # Links
    my $links = RT::Links->new( $self->CurrentUser );
    $links->Limit(
        SUBCLAUSE       => "either",
        FIELD           => $_,
        VALUE           => $self->URI,
        ENTRYAGGREGATOR => 'OR',
        )
        for qw/Base Target/;
    $deps->Add( in => $links );
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    if ($data->{Object} and ref $data->{Object}) {
        my $on_uid = ${ $data->{Object} };

        my $force;

        # skip attributes of objects we're not inflating
        if ( $on_uid eq RT->System->UID ) {

            # We always want RT->System's searches and dashboards
            $force = 1 if $data->{Name} =~ /^Search|^(?:SavedSearch|Dashboard|ContentHistory)$/;

            # Do not import DefaultDashboard if it already exists
            if ( $data->{Name} eq 'DefaultDashboard' ) {
                if ( my $exists = RT->System->FirstAttribute('DefaultDashboard') ) {
                    $importer->Resolve( $uid => ref($exists) => $exists->Id );
                    return;
                }
                else {
                    $force = 1;
                }
            }
        }
        elsif ( $on_uid =~ /^RT::(?:User|Group)-/ ) {
            if ( $importer->ShouldSkipTransaction($on_uid) ) {
                if ( $data->{Name} eq 'Bookmarks' || $data->{Name} =~ /^Pref-/ ) {
                    my $obj = $importer->LookupObj($on_uid);
                    if ( $obj && $obj->Id ) {
                        if ( my $exists = $obj->FirstAttribute( $data->{Name} ) ) {
                            if ( $data->{Name} eq 'Bookmarks' ) {

                                # Merge bookmarks if possible
                                my $new_content = $exists->_DeserializeContent( $data->{Content} );
                                if ( ref $new_content eq 'ARRAY' ) {
                                    my $content = $exists->Content;
                                    my $changed;
                                    for my $uid (@$new_content) {
                                        if ( my $ticket = $importer->LookupObj($$uid) ) {
                                            $content->{ $ticket->Id } = 1;
                                            $changed = 1;
                                        }
                                    }
                                    if ($changed) {
                                        my ( $ret, $msg ) = $exists->SetContent($content);
                                        unless ($ret) {
                                            RT->Logger->error("Couldn't update Bookmarks for user $on_uid: $msg");
                                        }
                                    }
                                }
                            }
                            $importer->Resolve( $uid => ref($exists) => $exists->Id );
                        }
                        else {
                            $force = 1;
                        }
                    }
                }
                elsif ( $data->{Name} =~ /SavedSearch|Dashboard|Subscription|ContentHistory/ ) {

                    # We always want saved searches and dashboards
                    $force = 1;
                }
            }
            elsif ( $data->{Name} eq 'RecentlyViewedTickets' ) {
                # Don't bother importing frequently updated recently viewed tickets
                return;
            }
        }

        return if !$force && $importer->ShouldSkipTransaction($on_uid);
    }

    return $class->SUPER::PreInflate( $importer, $uid, $data );
}

# this method will be called repeatedly to fix up this attribute's contents
# (a list of searches, dashboards) during the import process, as the
# ordinary dependency resolution system can't quite handle the subtlety
# involved (e.g. a user simply declares out-dependencies on all of her
# attributes, but those attributes (e.g. dashboards, saved searches,
# dashboards in menu preferences) have dependencies amongst themselves).
# if this attribute (e.g. a user's dashboard) fails to load an attribute
# (e.g. a user's saved search) then it postpones and repeats the postinflate
# process again when that user's saved search has been imported
# this method updates Content each time through, each time getting closer and
# closer to the fully inflated attribute
sub PostInflateFixup {
    my $self     = shift;
    my $importer = shift;
    my $spec     = shift;
    return if $importer->{Clone};

    # decode UIDs to be raw dashboard IDs
    if ( $self->Name =~ /^(?:Pref-)?DashboardsInMenu$/ ) {
        my $content = $self->Content;

        for my $pane (values %{ $content || {} }) {
            for (@$pane) {
                if (ref($_) eq 'SCALAR') {
                    my $attr = $importer->LookupObj($$_);
                    if ($attr) {
                        $_ = $attr->Id;
                    }
                    else {
                        $importer->Postpone(
                            for    => $$_,
                            uid    => $spec->{uid},
                            method => 'PostInflateFixup',
                        );
                    }
                }
            }
        }
        $self->SetContent( $content, SyncLinks => 0, RecordTransaction => 0 );
    }
    elsif ( $self->Name =~ /DefaultDashboard$/ ) {
        my $content = $self->Content;
        if ( ref($content) eq 'SCALAR' ) {
            my $attr = $importer->LookupObj($$content);
            if ($attr) {
                $content = $attr->Id;
            }
            else {
                $importer->Postpone(
                    for    => $$content,
                    uid    => $spec->{uid},
                    method => 'PostInflateFixup',
                );
            }
        }
    }
    # decode UIDs to be saved searches
    elsif ($self->Name eq 'Dashboard') {
        my $content = $self->Content;

        for my $pane (values %{ $content->{Panes} || {} }) {
            for (@$pane) {
                if (ref($_->{uid}) eq 'SCALAR') {
                    my $uid = $_->{uid};
                    my $attr = $importer->LookupObj($$uid);

                    if ($attr) {
                        # update with the new id numbers assigned to us
                        $_->{id} = $attr->Id;
                        $_->{privacy} = join '-', $attr->ObjectType, $attr->ObjectId;
                        delete $_->{uid};
                    }
                    else {
                        $importer->Postpone(
                            for    => $$uid,
                            uid    => $spec->{uid},
                            method => 'PostInflateFixup',
                        );
                    }
                }
            }
        }
        $self->SetContent( $content, SyncLinks => 0, RecordTransaction => 0 );
    }
    elsif ($self->Name eq 'Subscription') {
        my $content = $self->Content;
        for my $type ( qw/Users Groups/ ) {
            if ( my $list = $content->{Recipients}{$type} ) {
                my @ids;
                for my $item ( @$list ) {
                    if ( ref $item eq 'SCALAR' ) {
                        my $obj = $importer->LookupObj($$item);
                        push @ids, $obj->Id if $obj && $obj->Id;
                    }
                    else {
                        push @ids, $item;
                    }
                }
                @$list = @ids;
            }
        }

        if (ref($content->{DashboardId}) eq 'SCALAR') {
            my $attr = $importer->LookupObj(${ $content->{DashboardId} });
            if ($attr) {
                $content->{DashboardId} = $attr->Id;
            }
            else {
                $importer->Postpone(
                    for    => ${ $content->{DashboardId} },
                    uid    => $spec->{uid},
                    method => 'PostInflateFixup',
                );
            }
        }
        $self->SetContent( $content, SyncLinks => 0, RecordTransaction => 0 );
    }
    elsif ( $self->Name eq 'Bookmarks' ) {
        my $content = $self->Content;
        my @ids;
        for my $uid (@$content) {
            if ( my $ticket = $importer->LookupObj($$uid) ) {
                push @ids, $ticket->Id;
            }
        }
        $content = { map { $_ => 1 } @ids };
        $self->SetContent($content);
    }
}

sub PostInflate {
    my $self = shift;
    my ($importer, $uid) = @_;

    $self->SUPER::PostInflate( $importer, $uid );

    # this method is separate because it needs to be callable multple times,
    # and we can't guarantee that SUPER::PostInflate can deal with that
    $self->PostInflateFixup($importer, { uid => $uid });
}

sub Serialize {
    my $self = shift;
    my %args = (@_);
    my %store = $self->SUPER::Serialize(@_);

    # encode raw dashboard IDs to be UIDs
    if ( $store{Name} =~ /^(?:Pref-)?DashboardsInMenu$/ ) {
        my $content = $self->_DeserializeContent($store{Content});
        for my $pane (values %{ $content || {} }) {
            for (@$pane) {
                $_ = \( join '-', 'RT::Attribute', $RT::Organization, $_ );
            }
        }
        $store{Content} = $self->_SerializeContent($content);
    }
    elsif ( $store{Name} =~ /DefaultDashboard$/ ) {
        $store{Content} = \( join '-', 'RT::Attribute', $RT::Organization, $store{Content} );
    }
    # encode saved searches and dashboards to be UIDs
    elsif ($store{Name} eq 'Dashboard') {
        my $content = $self->_DeserializeContent($store{Content}) || {};
        for my $pane (values %{ $content->{Panes} || {} }) {
            for (@$pane) {
                if ($_->{portlet_type} eq 'search' || $_->{portlet_type} eq 'dashboard') {
                    $_->{uid} = \( join '-', 'RT::Attribute', $RT::Organization, $_->{id} );
                }
                # pass through everything else (e.g. component)
            }
        }
        $store{Content} = $self->_SerializeContent($content);
    }
    # encode subscriptions to have dashboard UID
    elsif ($store{Name} eq 'Subscription') {
        my $content = $self->_DeserializeContent($store{Content});
        $content->{DashboardId} = \( join '-', 'RT::Attribute', $RT::Organization, $content->{DashboardId} );

        # encode user/groups to be UIDs
        for my $type (qw/Users Groups/) {
            if ( $content->{Recipients}{$type} ) {
                my $class = $type eq 'Users' ? 'RT::User' : 'RT::Group';
                my @uids;
                for my $id ( @{ $content->{Recipients}{$type} } ) {
                    my $obj = $class->new( RT->SystemUser );
                    $obj->Load($id);
                    if ( $obj->Id ) {
                        push @uids,
                            \( join '-', $class, $class eq 'RT::User' ? $obj->Name : ( $RT::Organization, $obj->Id ) );
                    }
                }
                $content->{Recipients}{$type} = \@uids;
            }
        }

        $store{Content} = $self->_SerializeContent($content);
    }
    elsif ( $self->Name eq 'Bookmarks' ) {
        my $content = $self->Content;
        $content = [ map { \( join '-', 'RT::Ticket', $RT::Organization, $_ ) } keys %$content ];
        $store{Content} = $self->_SerializeContent($content);
    }

    return %store;
}

=head2 URI

Returns this attribute's URI

=cut

sub URI {
    my $self = shift;
    my $uri  = RT::URI::attribute->new( $self->CurrentUser );
    return $uri->URIForObject($self);
}


=head2 _SyncLinks

For dashboard and homepage attributes, keep links to saved searches they
include up to date. It does nothing for other attributes.

Returns 1 on success and 0 on failure.

=cut

sub _SyncLinks {
    my $self = shift;
    my $name = $self->__Value('Name');

    my $success;

    if ( $name eq 'Dashboard' ) {
        my $content = $self->_DeserializeContent( $self->__Value('Content') );

        my %searches = map { $_->{id} => 1 } grep { $_->{portlet_type} eq 'search' } @{ $content->{Panes}{body} },
            @{ $content->{Panes}{sidebar} };

        my $links = $self->DependsOn;
        while ( my $link = $links->Next ) {
            next if delete $searches{ $link->TargetObj->id };
            my ( $ret, $msg ) = $link->Delete;
            if ( !$ret ) {
                RT->Logger->error( "Couldn't delete link #" . $link->id . ": $msg" );
                $success //= 0;
            }
        }

        for my $id ( keys %searches ) {
            my $link = RT::Link->new( $self->CurrentUser );
            my $attribute = RT::Attribute->new( $self->CurrentUser );
            $attribute->Load($id);
            if ( $attribute->id ) {
                my ( $ret, $msg )
                    = $link->Create( Type => 'DependsOn', Base => 'attribute:' . $self->id, Target => "attribute:$id" );
                if ( !$ret ) {
                    RT->Logger->error( "Couldn't create link for attribute #:" . $self->id . ": $msg" );
                    $success //= 0;
                }
            }
        }
    }
    elsif ( $name =~ /DefaultDashboard$/ ) {
        my $id    = $self->__Value('Content');
        my $links = $self->DependsOn;
        my $found;
        while ( my $link = $links->Next ) {
            if ( $link->TargetObj->id == $id ) {
                $found = 1;
            }
            else {

                my ( $ret, $msg ) = $link->Delete;
                if ( !$ret ) {
                    RT->Logger->error( "Couldn't delete link #" . $link->id . ": $msg" );
                    $success //= 0;
                }
            }
        }

        if ( !$found ) {
            my $link      = RT::Link->new( $self->CurrentUser );
            my $attribute = RT::Attribute->new( $self->CurrentUser );
            $attribute->Load($id);
            if ( $attribute->id ) {
                my ( $ret, $msg )
                    = $link->Create( Type => 'DependsOn', Base => 'attribute:' . $self->id, Target => "attribute:$id" );
                if ( !$ret ) {
                    RT->Logger->error( "Couldn't create link for attribute #:" . $self->id . ": $msg" );
                    $success //= 0;
                }
            }
        }
    }

    return $success // 1;
}

=head2 CurrentUserCanSee

Shortcut of CurrentUserHasRight('display').

=cut

sub CurrentUserCanSee {
    my $self = shift;
    return $self->CurrentUserHasRight('display');
}

RT::Base->_ImportOverlays();

1;
