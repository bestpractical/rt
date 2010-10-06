# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
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
# http://www.gnu.org/copyleft/gpl.html.
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
package RT::FM::Article;

use strict;

no warnings qw/redefine/;

use RT::FM;
use RT::FM::ArticleCollection;
use RT::FM::ObjectTopicCollection;
use RT::FM::ClassCollection;
use RT::Links;
use RT::CustomFields;
use RT::URI::fsck_com_rtfm;
use RT::Transactions;

# This object takes custom fields

use RT::CustomField;
RT::CustomField->_ForObjectType( CustomFieldLookupType() => 'RTFM Articles' )
  ;    #loc

# {{{ Create

=item Create PARAMHASH

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
        @_
    );

    my $class = RT::FM::Class->new($RT::SystemUser);
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

            my ( $cfid, $cfmsg ) = $self->_AddCustomFieldValue(
                (UNIVERSAL::isa( $value => 'HASH' )
                    ? %$value
                    : (Value => $value)
                ),
                Field             => $cf,
                RecordTransaction => 0
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

    my $temp = RT::FM::Article->new($RT::SystemUser);
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

Delete all its transactions
Delete all its custom field values
Delete all its relationships
Delete this article.

=cut

sub Delete {
    my $self = shift;
    unless ( $self->CurrentUserHasRight('DeleteArticle') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    $RT::Handle->BeginTransaction();
    my $linksto   = $self->_Links(  'Target' );
    my $linksfrom = $self->_Links(  'Base' );
    my $cfvalues = $self->CustomFieldValues;
    my $txns     = $self->Transactions;
    my $topics   = $self->Topics;

    while ( my $item = $linksto->Next ) {
        my ( $val, $msg ) = $item->Delete();
        unless ($val) {
            $RT::Logger->crit( ref($item) . ": $msg" );
            $RT::Handle->Rollback();
            return ( 0, $self->loc('Internal Error') );
        }
    }

    while ( my $item = $linksfrom->Next ) {
        my ( $val, $msg ) = $item->Delete();
        unless ($val) {
            $RT::Logger->crit( ref($item) . ": $msg" );
            $RT::Handle->Rollback();
            return ( 0, $self->loc('Internal Error') );
        }
    }

    while ( my $item = $txns->Next ) {
        my ( $val, $msg ) = $item->Delete();
        unless ($val) {
            $RT::Logger->crit( ref($item) . ": $msg" );
            $RT::Handle->Rollback();
            return ( 0, $self->loc('Internal Error') );
        }
    }

    while ( my $item = $cfvalues->Next ) {
        my ( $val, $msg ) = $item->Delete();
        unless ($val) {
            $RT::Logger->crit( ref($item) . ": $msg" );
            $RT::Handle->Rollback();
            return ( 0, $self->loc('Internal Error') );
        }
    }

    while ( my $item = $topics->Next ) {
        my ( $val, $msg ) = $item->Delete();
        unless ($val) {
            $RT::Logger->crit( ref($item) . ": $msg" );
            $RT::Handle->Rollback();
            return ( 0, $self->loc('Internal Error') );
        }
    }

    $self->SUPER::Delete();
    $RT::Handle->Commit();
    return ( 1, $self->loc('Article Deleted') );

}

# }}}

# {{{ Children

=item Children

Returns an RT::FM::ArticleCollection object which contains
all articles which have this article as their parent.  This 
routine will not recurse and will not find grandchildren, great-grandchildren, uncles, aunts, nephews or any other such thing.  

=cut

sub Children {
    my $self = shift;
    my $kids = new RT::FM::ArticleCollection( $self->CurrentUser );

    unless ( $self->CurrentUserHasRight('ShowArticle') ) {
        $kids->LimitToParent( $self->Id );
    }
    return ($kids);
}

# }}}

# {{{ sub AddLink

=head2 AddLink

Takes a paramhash of Type and one of Base or Target. Adds that link to this tick
et.

=cut

sub DeleteLink {
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

    $self->_DeleteLink(%args);
}

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
    if ($args{'Target'} =~ /^\d+$/ || $args{'Base'} =~ /^\d+$/) {
        return ( 0, $self->loc("Cannot add link to plain number") );
    }

    # Check that we're actually getting a valid URI
    my $uri_obj = RT::URI->new( $self->CurrentUser );
    $uri_obj->FromURI( $args{'Target'}||$args{'Base'} );
    unless ( $uri_obj->Resolver && $uri_obj->Scheme ) {
        my $msg = $self->loc( "Couldn't resolve '[_1]' into a Link.", $args{'Target'} );
        $RT::Logger->warning( $msg );
        return( 0, $msg );
    }


    $self->_AddLink(%args);
}

sub URI {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ShowArticle') ) {
        return $self->loc("Permission Denied");
    }

    my $uri = RT::URI::fsck_com_rtfm->new( $self->CurrentUser );
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

    my $topics = new RT::FM::ObjectTopicCollection( $self->CurrentUser );
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

    my $t = new RT::FM::ObjectTopic( $self->CurrentUser );
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

    my $t = new RT::FM::ObjectTopic( $self->CurrentUser );
    $t->LoadByCols(
        Topic      => $args{'Topic'},
        ObjectId   => $self->Id,
        ObjectType => ref($self)
    );
    if ( $t->Id ) {
        my $del = $t->Delete;
        unless ($del) {
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

=head2 CurrentUserHasRight

Returns true if the current user has the right for this article, for the whole system or for this article's class

=cut

sub CurrentUserHasRight {
    my $self  = shift;
    my $right = shift;

    return (
        $self->CurrentUser->HasRight(
            Right        => $right,
            Object       => $self,
            EquivObjects => [ $RT::FM::System, $RT::System, $self->ClassObj ]
        )
    );

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

    unless ( $self->CurrentUserHasRight('ModifyArticle') ) {
        return ( 0, $self->loc("Permission Denied") );
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
    "RT::FM::Class-RT::FM::Article";
}

# _LookupId is the id of the toplevel type object the customfield is joined to
# in this case, that's an RT::FM::Class.

sub _LookupId {
    my $self = shift;
    return $self->ClassObj->id;

}

=head2 LoadByInclude Field Value

Takes the name of a form field from RTFM's "Include Article" callbacks
and the value submitted by the browser and attempts to load an Article.

This handles Articles included by searching, by the Name and via
the hotlist.

=cut

sub LoadByInclude {
    my $self = shift;
    my %args = @_;
    my $Field = $args{Field};
    my $Value = $args{Value};

    return unless $Field;

    if ( $Field eq 'RTFM-Include-Article' && $Value ) {
        return $self->Load( $Value );
    } elsif ( $Field =~ /^RTFM-Include-Article-(\d+)$/ ) {
        return $self->Load( $1 );
    } elsif ( $Field =~ /^RTFM-Include-Article-Named/ && $Value ) {
        if ( $Value =~ /\D/ ) {
            return $self->LoadByCols( Name => $Value );
        } else {
            return $self->LoadByCols( id => $Value );
        }
    }

}

1;
