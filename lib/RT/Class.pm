# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

package RT::Class;

use strict;
use warnings;
use base 'RT::Record';


use RT::System;
use RT::CustomFields;
use RT::ACL;
use RT::Articles;
use RT::ObjectClass;
use RT::ObjectClasses;

use Role::Basic 'with';
with "RT::Record::Role::Rights";

sub Table {'Classes'}

# this object can take custom fields

use RT::CustomField;
RT::CustomField->RegisterLookupType( CustomFieldLookupType() => 'Classes' );    #loc

=head1 METHODS

=head2 Load IDENTIFIER

Loads a class, either by name or by id

=cut

sub Load {
    my $self = shift;
    my $id   = shift ;

    return unless $id;
    if ( $id =~ /^\d+$/ ) {
        $self->SUPER::Load($id);
    }
    else {
        $self->LoadByCols( Name => $id );
    }
}

__PACKAGE__->AddRight( Staff   => SeeClass              => 'See that this class exists'); # loc
__PACKAGE__->AddRight( Staff   => CreateArticle         => 'Create articles in this class'); # loc
__PACKAGE__->AddRight( General => ShowArticle           => 'See articles in this class'); # loc
__PACKAGE__->AddRight( Staff   => ShowArticleHistory    => 'See changes to articles in this class'); # loc
__PACKAGE__->AddRight( General => SeeCustomField        => 'View custom field values' ); # loc
__PACKAGE__->AddRight( Staff   => ModifyArticle         => 'Modify articles in this class'); # loc
__PACKAGE__->AddRight( Staff   => ModifyArticleTopics   => 'Modify topics for articles in this class'); # loc
__PACKAGE__->AddRight( Staff   => ModifyCustomField     => 'Modify custom field values' ); # loc
__PACKAGE__->AddRight( Staff   => SetInitialCustomField => 'Add custom field values only at object creation time'); # loc
__PACKAGE__->AddRight( Admin   => AdminClass            => 'Modify metadata and custom fields for this class'); # loc
__PACKAGE__->AddRight( Admin   => AdminTopics           => 'Modify topic hierarchy associated with this class'); # loc
__PACKAGE__->AddRight( Admin   => ShowACL               => 'Display Access Control List'); # loc
__PACKAGE__->AddRight( Admin   => ModifyACL             => 'Create, modify and delete Access Control List entries'); # loc
__PACKAGE__->AddRight( Staff   => DisableArticle        => 'Disable articles in this class'); # loc
__PACKAGE__->AddRight( Admin   => ModifyScrips          => 'Modify Scrips' ); # loc
__PACKAGE__->AddRight( Admin   => ShowScrips            => 'View Scrips' ); # loc
__PACKAGE__->AddRight( Admin   => ModifyTemplate        => 'Modify Scrip templates' ); # loc
__PACKAGE__->AddRight( Admin   => ShowTemplate          => 'View Scrip templates' ); # loc

# {{{ Create

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(255) 'Name'.
  varchar(255) 'Description'.
  int(11) 'SortOrder'.

=cut

sub Create {
    my $self = shift;
    my %args = (
        Name        => '',
        Description => '',
        SortOrder   => '0',
        @_
    );

    unless (
        $self->CurrentUser->HasRight(
            Right  => 'AdminClass',
            Object => $RT::System
        )
      )
    {
        return ( 0, $self->loc('Permission Denied') );
    }

    $self->SUPER::Create(
        Name        => $args{'Name'},
        Description => $args{'Description'},
        SortOrder   => $args{'SortOrder'},
    );

}

sub ValidateName {
    my $self   = shift;
    my $newval = shift;

    return undef unless ($newval);
    my $obj = RT::Class->new($RT::SystemUser);
    $obj->Load($newval);
    return undef if $obj->id && ( !$self->id || $self->id != $obj->id );
    return $self->SUPER::ValidateName($newval);

}

# }}}

# }}}

# {{{ ACCESS CONTROL

# {{{ sub _Set
sub _Set {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('AdminClass') ) {
        return ( 0, $self->loc('Permission Denied') );
    }
    return ( $self->SUPER::_Set(@_) );
}

# }}}

# {{{ sub _Value

sub _Value {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('SeeClass') ) {
        return (undef);
    }

    return ( $self->__Value(@_) );
}

# }}}

sub ArticleCustomFields {
    my $self = shift;


    my $cfs = RT::CustomFields->new( $self->CurrentUser );
    if ( $self->CurrentUserHasRight('SeeClass') ) {
        $cfs->SetContextObject( $self );
        $cfs->LimitToGlobalOrObjectId( $self->Id );
        $cfs->LimitToLookupType( RT::Article->CustomFieldLookupType );
        $cfs->ApplySortOrder;
    }
    return ($cfs);
}


=head2 AppliedTo

Returns collection of Queues this Class is applied to.
Doesn't takes into account if object is applied globally.

=cut

sub AppliedTo {
    my $self = shift;

    my ($res, $ocfs_alias) = $self->_AppliedTo;
    return $res unless $res;

    $res->Limit(
        ALIAS     => $ocfs_alias,
        FIELD     => 'id',
        OPERATOR  => 'IS NOT',
        VALUE     => 'NULL',
    );

    return $res;
}

=head2 NotAppliedTo

Returns collection of Queues this Class is not applied to.

Doesn't takes into account if object is applied globally.

=cut

sub NotAppliedTo {
    my $self = shift;

    my ($res, $ocfs_alias) = $self->_AppliedTo;
    return $res unless $res;

    $res->Limit(
        ALIAS     => $ocfs_alias,
        FIELD     => 'id',
        OPERATOR  => 'IS',
        VALUE     => 'NULL',
    );

    return $res;
}

sub _AppliedTo {
    my $self = shift;

    my $res = RT::Queues->new( $self->CurrentUser );

    $res->OrderBy( FIELD => 'Name' );
    my $ocfs_alias = $res->Join(
        TYPE   => 'LEFT',
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => 'ObjectClasses',
        FIELD2 => 'ObjectId',
    );
    $res->Limit(
        LEFTJOIN => $ocfs_alias,
        ALIAS    => $ocfs_alias,
        FIELD    => 'Class',
        VALUE    => $self->id,
    );
    return ($res, $ocfs_alias);
}

=head2 IsApplied

Takes object id and returns corresponding L<RT::ObjectClass>
record if this Class is applied to the object. Use 0 to check
if Class is applied globally.

=cut

sub IsApplied {
    my $self = shift;
    my $id = shift;
    return unless defined $id;
    my $oc = RT::ObjectClass->new( $self->CurrentUser );
    $oc->LoadByCols( Class=> $self->id, ObjectId => $id,
                     ObjectType => ( $id ? 'RT::Queue' : 'RT::System' ));
    return undef unless $oc->id;
    return $oc;
}

=head2 AddToObject OBJECT

Apply this Class to a single object, to start with we support Queues

Takes an object

=cut


sub AddToObject {
    my $self  = shift;
    my $object = shift;
    my $id = $object->Id || 0;

    unless ( $object->CurrentUserHasRight('AdminClass') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $queue = RT::Queue->new( $self->CurrentUser );
    if ( $id ) {
        my ($ok, $msg) = $queue->Load( $id );
        unless ($ok) {
            return ( 0, $self->loc('Invalid Queue, unable to apply Class: [_1]',$msg ) );
        }

    }

    if ( $self->IsApplied( $id ) ) {
        return ( 0, $self->loc("Class is already applied to [_1]",$queue->Name) );
    }

    if ( $id ) {
        # applying locally
        return (0, $self->loc("Class is already applied Globally") )
            if $self->IsApplied( 0 );
    }
    else {
        my $applied = RT::ObjectClasses->new( $self->CurrentUser );
        $applied->LimitToClass( $self->id );
        while ( my $record = $applied->Next ) {
            $record->Delete;
        }
    }

    my $oc = RT::ObjectClass->new( $self->CurrentUser );
    my ( $oid, $msg ) = $oc->Create(
        ObjectId => $id, Class => $self->id,
        ObjectType => ( $id ? 'RT::Queue' : 'RT::System' ),
    );
    return ( $oid, $msg );
}


=head2 RemoveFromObject OBJECT

Remove this class from a single queue object

=cut

sub RemoveFromObject {
    my $self = shift;
    my $object = shift;
    my $id = $object->Id || 0;

    unless ( $object->CurrentUserHasRight('AdminClass') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $ocf = $self->IsApplied( $id );
    unless ( $ocf ) {
        return ( 0, $self->loc("This class does not apply to that object") );
    }

    # XXX: Delete doesn't return anything
    my ( $oid, $msg ) = $ocf->Delete;
    return ( $oid, $msg );
}

sub SubjectOverride {
    my $self = shift;
    my $override = $self->FirstAttribute('SubjectOverride');
    return $override ? $override->Content : 0;
}

sub SetSubjectOverride {
    my $self = shift;
    my $override = shift;

    if ( $override == $self->SubjectOverride ) {
        return (0, "SubjectOverride is already set to that");
    }

    my $cf = RT::CustomField->new($self->CurrentUser);
    $cf->Load($override);

    if ( $override ) {
        my ($ok, $msg) = $self->SetAttribute( Name => 'SubjectOverride', Content => $override );
        return ($ok, $ok ? $self->loc('Added Subject Override: [_1]', $cf->Name) :
                           $self->loc('Unable to add Subject Override: [_1] [_2]', $cf->Name, $msg));
    } else {
        my ($ok, $msg) = $self->DeleteAttribute('SubjectOverride');
        return ($ok, $ok ? $self->loc('Removed Subject Override') :
                           $self->loc('Unable to add Subject Override: [_1] [_2]', $cf->Name, $msg));
    }
}

=head2 IncludeName

Returns 1 if the class is configured for the article Name to
be included with article content, 0 otherwise.

=cut

sub IncludeName {
    my $self = shift;
    return $self->FirstAttribute('Skip-Name') ? 0 : 1;
}

=head2 IncludeSummary

Returns 1 if the class is configured for the article Summary to
be included with article content, 0 otherwise.

=cut

sub IncludeSummary {
    my $self = shift;
    return $self->FirstAttribute('Skip-Summary') ? 0 : 1;
}

=head2 EscapeHTML

Returns 1 if the content of custom fields should be filtered
through EscapeHTML, 0 otherwise.

=cut

sub EscapeHTML {
    my $self = shift;
    return $self->FirstAttribute('Skip-EscapeHTML') ? 0 : 1;
}

sub _BuildCFInclusionData {
    my $self = shift;

    # Return immediately if we already populated the info
    return if $self->{'_cf_include_hash'};

    my $include = $self->{'_cf_include_hash'} = {};
    my $excludes = $self->{'_cf_exclude_list'} = [];

    my $cfs = $self->ArticleCustomFields;

    while ( my $cf = $cfs->Next ) {
        my $cfid = $cf->Id;
        $include->{"Title-$cfid"} = not $self->FirstAttribute("Skip-CF-Title-$cfid");
        $include->{"Value-$cfid"} = not $self->FirstAttribute("Skip-CF-Value-$cfid");
        push @$excludes, $cfid unless $include->{"Title-$cfid"} or $include->{"Value-$cfid"};
    }
}

=head2 IncludedArticleCustomFields

As ArticleCustomFields, but filtered to only include those
that should have either their Title (Name) or Value included
in content.

=cut

sub IncludedArticleCustomFields {
    my $self = shift;

    $self->_BuildCFInclusionData;

    my $cfs = $self->ArticleCustomFields;

    if ( @{ $self->{'_cf_exclude_list'} } ) {
        $cfs->Limit( FIELD => 'id', OPERATOR => 'NOT IN', VALUE => $self->{'_cf_exclude_list'} );
    }

    return $cfs;
}

=head2 IncludeArticleCFTitle CustomFieldObject

Returns true if the title of the custom field should
be included in article content, and false otherwise.

=cut

sub IncludeArticleCFTitle {
    my $self = shift;
    my $cfobj = shift;

    $self->_BuildCFInclusionData;

    return $self->{'_cf_include_hash'}{"Title-".$cfobj->Id};
}

=head2 IncludeArticleCFValue CustomFieldObject

Returns true if the value of the custom field should
be included in article content, and false otherwise.

=cut

sub IncludeArticleCFValue {
    my $self = shift;
    my $cfobj = shift;

    $self->_BuildCFInclusionData;

    return $self->{'_cf_include_hash'}{"Value-".$cfobj->Id};
}

=head2 CurrentUserCanSee

Returns true if the current user can see the class, using I<SeeClass>.

=cut

sub CurrentUserCanSee {
    my $self = shift;
    return $self->CurrentUserHasRight('SeeClass');
}

=head2 CurrentUserCanCreate

Returns true if the current user can create a new class, using I<AdminClass>.

=cut

sub CurrentUserCanCreate {
    my $self = shift;
    return $self->CurrentUserHasRight('AdminClass');
}

=head2 CurrentUserCanModify

Returns true if the current user can modify the class, using I<AdminClass>.

=cut

sub CurrentUserCanModify {
    my $self = shift;
    return $self->CurrentUserHasRight('AdminClass');
}

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


=head2 SortOrder

Returns the current value of SortOrder. 
(In the database, SortOrder is stored as int(11).)



=head2 SetSortOrder VALUE


Set SortOrder to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, SortOrder will be stored as a int(11).)


=cut


=head2 Disabled

Returns the current value of Disabled. 
(In the database, Disabled is stored as int(2).)



=head2 SetDisabled VALUE


Set Disabled to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Disabled will be stored as a int(2).)


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
                {read => 1, type => 'int(11)', default => ''},
        Name => 
                {read => 1, write => 1, type => 'varchar(255)', default => ''},
        Description => 
                {read => 1, write => 1, type => 'varchar(255)', default => ''},
        SortOrder => 
                {read => 1, write => 1, type => 'int(11)', default => '0'},
        Disabled => 
                {read => 1, write => 1, type => 'int(2)', default => '0'},
        Creator => 
                {read => 1, auto => 1, type => 'int(11)', default => '0'},
        Created => 
                {read => 1, auto => 1, type => 'datetime', default => ''},
        LastUpdatedBy => 
                {read => 1, auto => 1, type => 'int(11)', default => '0'},
        LastUpdated => 
                {read => 1, auto => 1, type => 'datetime', default => ''},

 }
};

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    my $articles = RT::Articles->new( $self->CurrentUser );
    $articles->Limit( FIELD => "Class", VALUE => $self->Id );
    $deps->Add( in => $articles );

    my $topics = RT::Topics->new( $self->CurrentUser );
    $topics->LimitToObject( $self );
    $deps->Add( in => $topics );

    my $objectclasses = RT::ObjectClasses->new( $self->CurrentUser );
    $objectclasses->LimitToClass( $self->Id );
    $deps->Add( in => $objectclasses );

    # Scrips
    my $objs = RT::ObjectScrips->new( $self->CurrentUser );
    $objs->LimitToLookupType(RT::Article->CustomFieldLookupType);
    $objs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => $self->id,
                  ENTRYAGGREGATOR => 'OR' );
    $objs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => 0,
                  ENTRYAGGREGATOR => 'OR' );
    $deps->Add( in => $objs );

    # Custom Fields on things _in_ this class (CFs on the class itself
    # have already been dealt with)
    my $ocfs = RT::ObjectCustomFields->new( $self->CurrentUser );
    $ocfs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => $self->id,
                  ENTRYAGGREGATOR => 'OR' );
    $ocfs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => 0,
                  ENTRYAGGREGATOR => 'OR' );
    my $cfs = $ocfs->Join(
        ALIAS1 => 'main',
        FIELD1 => 'CustomField',
        TABLE2 => 'CustomFields',
        FIELD2 => 'id',
    );
    $ocfs->Limit( ALIAS    => $cfs,
                  FIELD    => 'LookupType',
                  OPERATOR => 'STARTSWITH',
                  VALUE    => 'RT::Class-' );
    $deps->Add( in => $ocfs );
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    return if $importer->MergeBy( "Name", $class, $uid, $data );

    return 1;
}

sub CustomFieldLookupType {
    "RT::Class";
}

sub __DependsOn {
    my $self = shift;
    my %args = (
        Shredder     => undef,
        Dependencies => undef,
        @_,
    );
    my $deps = $args{'Dependencies'};
    my $list = [];

    # Articles
    my $objs = RT::Articles->new( $self->CurrentUser );
    $objs->FindAllRows;
    $objs->Limit( FIELD => 'Class', VALUE => $self->Id );
    push( @$list, $objs );

    # ObjectClasses
    $objs = RT::ObjectClasses->new( $self->CurrentUser );
    $objs->LimitToClass( $self->id );
    push( @$list, $objs );

    # ObjectCustomFields
    $objs = RT::ObjectCustomFields->new( $self->CurrentUser );
    $objs->LimitToLookupType( $_->CustomFieldLookupType ) for qw/RT::Class RT::Article/;
    $objs->LimitToObjectId( $self->id );
    push( @$list, $objs );

    # Object Scrips
    $objs = RT::ObjectScrips->new( $self->CurrentUser );
    $objs->LimitToLookupType( RT::Article->CustomFieldLookupType );
    $objs->LimitToObjectId( $self->id );
    push( @$list, $objs );

    # Topics
    $objs = RT::Topics->new( $self->CurrentUser );
    $objs->LimitToObject($self);
    push( @$list, $objs );

    $deps->_PushDependencies(
        BaseObject    => $self,
        Flags         => RT::Shredder::Constants::DEPENDS_ON,
        TargetObjects => $list,
        Shredder      => $args{'Shredder'}
    );
    return $self->SUPER::__DependsOn(%args);
}

=head2 Templates

Returns an RT::Templates object of all of this class's templates.

=cut

sub Templates {
    my $self = shift;

    my $templates = RT::Templates->new( $self->CurrentUser );

    if ( $self->CurrentUserHasRight('ShowTemplate') ) {
        $templates->LimitToObjectId( $self->id );
        $templates->LimitToLookupType( RT::Article->CustomFieldLookupType );
    }

    return ($templates);
}

RT::Base->_ImportOverlays();

1;

