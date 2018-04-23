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

package RT::Article;
use base 'RT::Record';

use Role::Basic 'with';
with "RT::Record::Role::Links" => { -excludes => ["AddLink", "_AddLinksOnCreate"] };

use RT::Articles;
use RT::ObjectTopics;
use RT::Classes;
use RT::Links;
use RT::CustomFields;
use RT::URI::fsck_com_article;
use RT::Transactions;


sub Table {'Articles'}

# This object takes custom fields

use RT::CustomField;
RT::CustomField->RegisterLookupType( CustomFieldLookupType() => 'Articles' );    #loc

# {{{ Create

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'Name'.
  varchar(200) 'Summary'.
  int(11) 'Content'.
  Class ID  'Class'

  A paramhash called  'CustomFields', which contains 
  arrays of values for each custom field you want to fill in.
  Arrays aRe ordered. 




=cut

sub Create {
    my $self = shift;
    my %args = (
        Name         => '',
        Summary      => '',
        Class        => '0',
        CustomFields => {},
        Links        => {},
        Topics       => [],
        Disabled    => 0,
        @_
    );

    my $class = RT::Class->new( $self->CurrentUser );
    $class->Load( $args{'Class'} );
    unless ( $class->Id ) {
        return ( 0, $self->loc('Invalid Class') );
    }

    unless ( $class->CurrentUserHasRight('CreateArticle') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    return ( undef, $self->loc('Name in use') )
      unless $self->ValidateName( $args{'Name'} );

    $RT::Handle->BeginTransaction();
    my ( $id, $msg ) = $self->SUPER::Create(
        Name    => $args{'Name'},
        Class   => $class->Id,
        Summary => $args{'Summary'},
        Disabled => $args{'Disabled'},
    );
    unless ($id) {
        $RT::Handle->Rollback();
        return ( undef, $msg );
    }

    # {{{ Add custom fields

    foreach my $key ( keys %args ) {
        next unless ( $key =~ /CustomField-(.*)$/ );
        my $cf   = $1;
        my @vals = ref( $args{$key} ) eq 'ARRAY' ? @{ $args{$key} } : ( $args{$key} );
        foreach my $value (@vals) {
            next if $self->CustomFieldValueIsEmpty(
                Field => $cf,
                Value => $value,
            );

            my ( $cfid, $cfmsg ) = $self->_AddCustomFieldValue(
                (UNIVERSAL::isa( $value => 'HASH' )
                    ? %$value
                    : (Value => $value)
                ),
                Field             => $cf,
                RecordTransaction => 0,
                ForCreation       => 1,
            );

            unless ($cfid) {
                $RT::Handle->Rollback();
                return ( undef, $cfmsg );
            }
        }

    }

    # }}}
    # {{{ Add topics

    foreach my $topic ( @{ $args{Topics} } ) {
        my ( $cfid, $cfmsg ) = $self->AddTopic( Topic => $topic );

        unless ($cfid) {
            $RT::Handle->Rollback();
            return ( undef, $cfmsg );
        }
    }

    # }}}
    # {{{ Add relationships

    foreach my $type ( keys %args ) {
        next unless ( $type =~ /^(RefersTo-new|new-RefersTo)$/ );
        my @vals =
          ref( $args{$type} ) eq 'ARRAY' ? @{ $args{$type} } : ( $args{$type} );
        foreach my $val (@vals) {
            my ( $base, $target );
            if ( $type =~ /^new-(.*)$/ ) {
                $type   = $1;
                $base   = undef;
                $target = $val;
            }
            elsif ( $type =~ /^(.*)-new$/ ) {
                $type   = $1;
                $base   = $val;
                $target = undef;
            }

            my ( $linkid, $linkmsg ) = $self->AddLink(
                Type              => $type,
                Target            => $target,
                Base              => $base,
                RecordTransaction => 0
            );

            unless ($linkid) {
                $RT::Handle->Rollback();
                return ( undef, $linkmsg );
            }
        }

    }

    # }}}

    # We override the URI lookup. the whole reason
    # we have a URI column is so that joins on the links table
    # aren't expensive and stupid
    $self->__Set( Field => 'URI', Value => $self->URI );

    my ( $txn_id, $txn_msg, $txn ) = $self->_NewTransaction( Type => 'Create' );
    unless ($txn_id) {
        $RT::Handle->Rollback();
        return ( undef, $self->loc( 'Internal error: [_1]', $txn_msg ) );
    }
    $RT::Handle->Commit();

    return ( $id, $self->loc('Article [_1] created',$self->id ));
}

# }}}

# {{{ ValidateName

=head2 ValidateName NAME

Takes a string name. Returns true if that name isn't in use by another article

Empty names are permitted.


=cut

sub ValidateName {
    my $self = shift;
    my $name = shift;

    if ( !$name ) {
        return (1);
    }

    my $temp = RT::Article->new($RT::SystemUser);
    $temp->LoadByCols( Name => $name );
    if ( $temp->id && 
         (!$self->id || ($temp->id != $self->id ))) {
        return (undef);
    }

    return (1);

}

# }}}

# {{{ Delete

=head2 Delete

This does not remove from the database; it merely sets the Disabled bit.

=cut

sub Delete {
    my $self = shift;
    return $self->SetDisabled(1);
}

# }}}

# {{{ Children

=head2 Children

Returns an RT::Articles object which contains
all articles which have this article as their parent.  This 
routine will not recurse and will not find grandchildren, great-grandchildren, uncles, aunts, nephews or any other such thing.  

=cut

sub Children {
    my $self = shift;
    my $kids = RT::Articles->new( $self->CurrentUser );

    unless ( $self->CurrentUserHasRight('ShowArticle') ) {
        $kids->LimitToParent( $self->Id );
    }
    return ($kids);
}

# }}}

# {{{ sub AddLink

=head2 AddLink

Takes a paramhash of Type and one of Base or Target. Adds that link to this article.

Prevents the use of plain numbers to avoid confusing behaviour.

=cut

sub AddLink {
    my $self = shift;
    my %args = (
        Target => '',
        Base   => '',
        Type   => '',
        Silent => undef,
        @_
    );

    unless ( $self->CurrentUserHasRight('ModifyArticle') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    # Disallow parsing of plain numbers in article links.  If they are
    # allowed, they default to being tickets instead of articles, which
    # is counterintuitive.
    if (   $args{'Target'} && $args{'Target'} =~ /^\d+$/
        || $args{'Base'} && $args{'Base'} =~ /^\d+$/ )
    {
        return ( 0, $self->loc("Cannot add link to plain number") );
    }

    $self->_AddLink(%args);
}

sub URI {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ShowArticle') ) {
        return $self->loc("Permission Denied");
    }

    my $uri = RT::URI::fsck_com_article->new( $self->CurrentUser );
    return ( $uri->URIForObject($self) );
}

# }}}

# {{{ sub URIObj

=head2 URIObj

Returns this article's URI


=cut

sub URIObj {
    my $self = shift;
    my $uri  = RT::URI->new( $self->CurrentUser );
    if ( $self->CurrentUserHasRight('ShowArticle') ) {
        $uri->FromObject($self);
    }

    return ($uri);
}

# }}}
# }}}

# {{{ Topics

# {{{ Topics
sub Topics {
    my $self = shift;

    my $topics = RT::ObjectTopics->new( $self->CurrentUser );
    if ( $self->CurrentUserHasRight('ShowArticle') ) {
        $topics->LimitToObject($self);
    }
    return $topics;
}

# }}}

# {{{ AddTopic
sub AddTopic {
    my $self = shift;
    my %args = (@_);

    unless ( $self->CurrentUserHasRight('ModifyArticleTopics') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my $t = RT::ObjectTopic->new( $self->CurrentUser );
    my ($tid) = $t->Create(
        Topic      => $args{'Topic'},
        ObjectType => ref($self),
        ObjectId   => $self->Id
    );
    if ($tid) {
        return ( $tid, $self->loc("Topic membership added") );
    }
    else {
        return ( 0, $self->loc("Unable to add topic membership") );
    }
}

# }}}

sub DeleteTopic {
    my $self = shift;
    my %args = (@_);

    unless ( $self->CurrentUserHasRight('ModifyArticleTopics') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my $t = RT::ObjectTopic->new( $self->CurrentUser );
    $t->LoadByCols(
        Topic      => $args{'Topic'},
        ObjectId   => $self->Id,
        ObjectType => ref($self)
    );
    if ( $t->Id ) {
        my ($ok, $msg) = $t->Delete;
        unless ($ok) {
            return (
                undef,
                $self->loc(
                    "Unable to delete topic membership in [_1]",
                    $t->TopicObj->Name
                )
            );
        }
        else {
            return ( 1, $self->loc("Topic membership removed") );
        }
    }
    else {
        return (
            undef,
            $self->loc(
                "Couldn't load topic membership while trying to delete it")
        );
    }
}

=head2 CurrentUserCanSee

Returns true if the current user can see the article, using ShowArticle

=cut

sub CurrentUserCanSee {
    my $self = shift;
    return $self->CurrentUserHasRight('ShowArticle');
}

# }}}

# {{{ _Set

=head2 _Set { Field => undef, Value => undef

Internal helper method to record a transaction as we update some core field of the article


=cut

sub _Set {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
        @_
    );

    if ( $args{Field} eq 'Disabled' ) {
        unless ( $self->CurrentUserHasRight( 'DisableArticle' ) ) {
            return ( 0, $self->loc( "Permission Denied" ) );
        }
    }
    else {
        unless ( $self->CurrentUserHasRight( 'ModifyArticle' ) ) {
            return ( 0, $self->loc( "Permission Denied" ) );
        }
    }

    $self->_NewTransaction(
        Type     => 'Set',
        Field    => $args{'Field'},
        NewValue => $args{'Value'},
        OldValue => $self->__Value( $args{'Field'} )
    );

    return ( $self->SUPER::_Set(%args) );

}

=head2 _Value PARAM

Return "PARAM" for this object. if the current user doesn't have rights, returns undef

=cut

sub _Value {
    my $self = shift;
    my $arg  = shift;
    unless ( ( $arg eq 'Class' )
        || ( $self->CurrentUserHasRight('ShowArticle') ) )
    {
        return (undef);
    }
    return $self->SUPER::_Value($arg);
}

# }}}

sub CustomFieldLookupType {
    "RT::Class-RT::Article";
}


sub ACLEquivalenceObjects {
    my $self = shift;
    return $self->ClassObj;
}

sub ModifyLinkRight { "ModifyArticle" }

=head2 LoadByInclude Field Value

Takes the name of a form field from "Include Article"
and the value submitted by the browser and attempts to load an Article.

This handles Articles included by searching, by the Name and via
the hotlist.

If you optionaly pass an id as the Queue argument, this will check that
the Article's Class is applied to that Queue.

=cut

sub LoadByInclude {
    my $self = shift;
    my %args = @_;
    my $Field = $args{Field};
    my $Value = $args{Value};
    my $Queue = $args{Queue};

    return unless $Field;

    my ($ok, $msg);
    if ( $Field eq 'Articles-Include-Article' && $Value ) {
        ($ok, $msg) = $self->Load( $Value );
    } elsif ( $Field =~ /^Articles-Include-Article-(\d+)$/ ) {
        ($ok, $msg) = $self->Load( $1 );
    } elsif ( $Field =~ /^Articles-Include-Article-Named/ && $Value ) {
        if ( $Value =~ /\D/ ) {
            ($ok, $msg) = $self->LoadByCols( Name => $Value );
        } else {
            ($ok, $msg) = $self->LoadByCols( id => $Value );
        }
    }

    unless ($ok) { # load failed, don't check Class
        return wantarray ? ($ok, $msg) : $ok;
    }

    unless ($Queue) { # we haven't requested extra sanity checking
        return wantarray ? ($ok, $msg) : $ok;
    }

    # ensure that this article is available for the Queue we're
    # operating under.
    my $class = $self->ClassObj;
    unless ($class->IsApplied(0) || $class->IsApplied($Queue)) {
        $self->LoadById(0);
        return wantarray ? (0, $self->loc("The Class of the Article identified by [_1] is not applied to the current Queue",$Value)) : 0;
    }

    return wantarray ? ($ok, $msg) : $ok;

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


=head2 Summary

Returns the current value of Summary. 
(In the database, Summary is stored as varchar(255).)



=head2 SetSummary VALUE


Set Summary to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Summary will be stored as a varchar(255).)


=cut


=head2 SortOrder

Returns the current value of SortOrder. 
(In the database, SortOrder is stored as int(11).)



=head2 SetSortOrder VALUE


Set SortOrder to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, SortOrder will be stored as a int(11).)


=cut


=head2 Class

Returns the current value of Class. 
(In the database, Class is stored as int(11).)



=head2 SetClass VALUE


Set Class to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Class will be stored as a int(11).)


=cut


=head2 ClassObj

Returns the Class Object which has the id returned by Class


=cut

sub ClassObj {
    my $self = shift;
    my $Class =  RT::Class->new($self->CurrentUser);
    $Class->Load($self->Class());
    return($Class);
}

=head2 Parent

Returns the current value of Parent. 
(In the database, Parent is stored as int(11).)



=head2 SetParent VALUE


Set Parent to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Parent will be stored as a int(11).)


=cut


=head2 URI

Returns the current value of URI. 
(In the database, URI is stored as varchar(255).)



=head2 SetURI VALUE


Set URI to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, URI will be stored as a varchar(255).)


=cut

=head2 Disabled

Returns the current value of Disabled.
(In the database, Disabled is stored as int(2).)



=head2 SetDisabled VALUE


Set Disabled to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Disabled will be stored as a int(2).)



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
        Summary => 
                {read => 1, write => 1, type => 'varchar(255)', default => ''},
        SortOrder => 
                {read => 1, write => 1, type => 'int(11)', default => '0'},
        Class => 
                {read => 1, write => 1, type => 'int(11)', default => '0'},
        Parent => 
                {read => 1, write => 1, type => 'int(11)', default => '0'},
        URI => 
                {read => 1, write => 1, type => 'varchar(255)', default => ''},
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

    # Links
    my $links = RT::Links->new( $self->CurrentUser );
    $links->Limit(
        SUBCLAUSE       => "either",
        FIELD           => $_,
        VALUE           => $self->URI,
        ENTRYAGGREGATOR => 'OR'
    ) for qw/Base Target/;
    $deps->Add( in => $links );

    $deps->Add( out => $self->ClassObj );
    $deps->Add( in => $self->Topics );
}

sub PostInflate {
    my $self = shift;

    $self->__Set( Field => 'URI', Value => $self->URI );
}

RT::Base->_ImportOverlays();

1;


1;
