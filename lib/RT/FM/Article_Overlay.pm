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

use RT::FM;
use RT::FM::ArticleCollection;
use RT::FM::ObjectTopicCollection;
use RT::FM::ClassCollection;
use RT::Links;
use RT::URI::fsck_com_rtfm;
use RT::Transactions;

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



=begin testing

use_ok(RT::FM::Article);
use_ok(RT::FM::Class);

my $user = RT::CurrentUser->new('root');

my $class = RT::FM::Class->new($user);


my ($id, $msg) = $class->Create(Name =>'ArticleTest');
ok ($id, $msg);



my $article = RT::FM::Article->new($user);
ok (UNIVERSAL::isa($article, 'RT::FM::Article'));
ok (UNIVERSAL::isa($article, 'RT::FM::Record'));
ok (UNIVERSAL::isa($article, 'RT::Record'));
ok (UNIVERSAL::isa($article, 'DBIx::SearchBuilder::Record') , "It's a searchbuilder record!");


($id, $msg) = $article->Create( Class => 'ArticleTest', Summary => "ArticleTest");
ok ($id, $msg);
$article->Load($id);
is ($article->Summary, 'ArticleTest', "The summary is set correct");
my $at = RT::FM::Article->new($RT::SystemUser);
$at->Load($id);
is ($at->id , $id);
is ($at->Summary, $article->Summary);


=end testing


=cut

sub Create {
    my $self = shift;
    my %args = ( Name         => '',
                 Summary      => '',
                 Class        => '0',
                 CustomFields => {},
                 Links        => {},
                 @_ );

    my $class = RT::FM::Class->new($RT::SystemUser);
    $class->Load( $args{'Class'} );
    unless ( $class->Id ) {
        return ( 0, $self->loc('Invalid Class') );
    }

    unless ( $class->CurrentUserHasRight('CreateArticle') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    return (undef,$self->loc('Name in use')) unless $self->ValidateName($args{'Name'});

    $RT::Handle->BeginTransaction();
    my ( $id, $msg ) = $self->SUPER::Create( Name    => $args{'Name'},
                                             Class   => $class->Id,
                                             Summary => $args{'Summary'}, );
    unless ($id) {
        $RT::Handle->Rollback();
        return ( undef, $msg );
    }

    # {{{ Add custom fields

    foreach my $key ( keys %args ) {
        next unless ( $key =~ /^CustomField-(.*)$/ );
        my $cf   = $1;
        my @vals =
          ref( $args{$key} ) eq 'ARRAY' ? @{ $args{$key} } : ( $args{$key} );
        foreach my $val (@vals) {

            my ( $cfid, $cfmsg ) = $self->_AddCustomFieldValue(
                                                          Field   => $1,
                                                          Content => $val,
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

    foreach my $topic (@{$args{Topics}}) {
        my ( $cfid, $cfmsg ) = $self->AddTopic(Topic => $topic);
        
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

            my ( $linkid, $linkmsg ) = $self->AddLink( Type   => $type,
                                                       Target => $target,
                                                       Base   => $base,
                                                       RecordTransaction => 0 );

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

    $self->_NewTransaction( Type => 'Create' );

    $RT::Handle->Commit();

    return ( $id, $msg );
}

# }}}

# {{{ ValidateName

=head2 ValidateName NAME

Takes a string name. Returns true if that name isn't in use by another article

Empty names are permitted.


=begin testing

my  $a1 = RT::FM::Article->new($RT::SystemUser);
my ($id, $msg)  = $a1->Create(Class => 1, Name => 'ValidateNameTest');
ok ($id, $msg);



my  $a2 = RT::FM::Article->new($RT::SystemUser);
($id, $msg)  = $a2->Create(Class => 1, Name => 'ValidateNameTest');
ok (!$id, $msg);

my  $a3 = RT::FM::Article->new($RT::SystemUser);
($id, $msg)  = $a3->Create(Class => 1, Name => 'ValidateNameTest2');
ok ($id, $msg);
($id, $msg) =$a3->SetName('ValidateNameTest');

ok (!$id, $msg);

($id, $msg) =$a3->SetName('ValidateNametest2');

ok ($id, $msg);




=end testing


=cut

sub ValidateName {
    my $self = shift;
    my $name = shift;

    if (!$name) {
        return(1);
    }

    my $temp = RT::FM::Article->new($RT::SystemUser);
    $temp->LoadByCols(Name => $name);
    if ($temp->id && $temp->id != $self->id) {
        return(undef);
    }

    return(1);

}

# }}}

# {{{ Delete 

=head2 Delete

Delete all its transactions
Delete all its custom field values
Delete all its relationships
Delete this article.

=begin testing

my $newart = RT::FM::Article->new($RT::SystemUser);
$newart->Create(Name => 'DeleteTest', Class => '1');
my $id = $newart->Id;

ok($id, "New article has an id");


my $article = RT::FM::Article->new($RT::SystemUser);
$article->Load($id);
ok ($article->Id, "Found the article");
my ($val, $msg) = $article->Delete();
ok ($val, "Article Deleted: $msg");

my $a2 = RT::FM::Article->new($RT::SystemUser);
$a2->Load($id);
ok (!$a2->Id, "Did not find the article");


=end testing

=cut

sub Delete {
    my $self = shift;
    unless ( $self->CurrentUserHasRight('ModifyArticle') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    $RT::Handle->BeginTransaction();
    my $linksto   = $self->_Links( Field => 'Target' );
    my $linksfrom = $self->_Links( Field => 'Base' );
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

    while (my $item = $topics->Next) {
        my ($val, $msg ) = $item->Delete();
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

=begin testing

=end testing



=cut

sub AddLink {
    my $self = shift;
    my %args = ( Target            => '',
                 Base              => '',
                 Type              => 'RefersTo',
                 RecordTransaction => 1,
                 @_ );

    unless ( $self->CurrentUserHasRight('ModifyArticle') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my ( $link_type, $link_pointer );

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug(
             "$self tried to delete a link. both base and target were specified"
        );
        return ( 0, $self->loc("Can't specifiy both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
        $link_type      = "ReferredToBy";
        $link_pointer   = $args{'Base'};
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
        $link_type    = "RefersTo";
        $link_pointer = $args{'Target'};
    }
    else {
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    # {{{ We don't want references to ourself
    if ( $args{'Base'} eq $args{'Target'} ) {
        $RT::Logger->debug(
                 "Trying to link " . $args{'Base'} . " to " . $args{'Target'} );
        return ( 0, $self->loc("Can't link a ticket to itself") );
    }

    # }}}

    # If the base isn't a URI, make it a URI.
    # If the target isn't a URI, make it a URI.

    # {{{ Check if the link already exists - we don't want duplicates
    my $old_link = new RT::Link( $self->CurrentUser );
    $old_link->LoadByParams( Base   => $args{'Base'},
                             Type   => $args{'Type'},
                             Target => $args{'Target'} );
    if ( $old_link->Id ) {
        $RT::Logger->debug("$self Somebody tried to duplicate a link");
        return ( $old_link->id, $self->loc("Link already exists"), 0 );
    }

    # }}}

    # Storing the link in the DB.
    my $link = RT::Link->new( $self->CurrentUser );
    my ($linkid) = $link->Create( Target => $args{Target},
                                  Base   => $args{Base},
                                  Type   => $args{Type} );

    unless ($linkid) {
        return ( 0, $self->loc("Link could not be created") );
    }

    my $TransString = "$args{'Base'} $args{Type} $args{'Target'}";

    # Don't write the transaction if we're doing this on create
    if ( $args{'RecordTransaction'} ) {

        #Write the transaction
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
                                                     Type       => 'Link',
                                                     Field      => $link_type,
                                                     NewContent => $link_pointer
        );
        return ( $Trans, $self->loc( "Link created ([_1])", $TransString ) );
    }
    else {
        return ( 1, $self->loc( "Link created ([_1])", $TransString ) );
    }
}

# }}}

# {{{ Links

=head2 Links

The following routines deal with links and relationships between articles and
RT tickets.


=begin testing

my ($id, $msg);

$RT::Handle->SimpleQuery("DELETE FROM Links");

my $article_a = RT::FM::Article->new($RT::SystemUser);
($id, $msg) = $article_a->Create( Class => 'ArticleTest', Summary => "ArticleTestlink1");
ok($id,$msg);

my $article_b = RT::FM::Article->new($RT::SystemUser);
($id, $msg) = $article_b->Create( Class => 'ArticleTest', Summary => "ArticleTestlink2");
ok($id,$msg);

# Create a link between two articles
($id, $msg) = $article_a->AddLink( Type => 'RefersTo', Target => $article_b->URI);
ok($id,$msg);

# Make sure that Article B's "ReferredToBy" links object refers to to this article"
my $refers_to_b = $article_b->ReferredToBy;
ok($refers_to_b->Count == 1, "Found one thing referring to b");
my $first = $refers_to_b->First;
ok ($first->isa(RT::Link), "IT's an RT link - ref ".ref($first) );
ok ($first->TargetObj->Id == $article_b->Id, "Its target is B");

ok($refers_to_b->First->BaseObj->isa('RT::FM::Article'), "Yep. its an article");


# Make sure that Article A's "RefersTo" links object refers to this article"
my $referred_To_by_a = $article_a->RefersTo;
ok($referred_To_by_a->Count == 1, "Found one thing referring to b ".$referred_To_by_a->Count. "-".$referred_To_by_a->First->id . " - ".$referred_To_by_a->Last->id);
my $first = $referred_To_by_a->First;
ok ($first->isa(RT::Link), "IT's an RT link - ref ".ref($first) );
ok ($first->TargetObj->Id == $article_b->Id, "Its target is B - " . $first->TargetObj->Id);
ok ($first->BaseObj->Id == $article_a->Id, "Its base is A");

ok($referred_To_by_a->First->BaseObj->isa('RT::FM::Article'), "Yep. its an article");

# Delete the link
($id, $msg) = $article_a->DeleteLink(Type => 'RefersTo', Target => $article_b->URI);
ok($id,$msg);


# Create an Article A RefersTo Ticket 1 from the RTFM side
use RT::Ticket;


my $tick = RT::Ticket->new($RT::SystemUser);
$tick->Create(Subject => "Article link test ", Queue => 'General');
$tick->Load($tick->Id);
ok ($tick->Id, "Found ticket ".$tick->id);
($id, $msg) = $article_a->AddLink(Type => 'RefersTo', Target => $tick->URI);
ok($id,$msg);

# Find all tickets whhich refer to Article A

use RT::Tickets;
use RT::Links;

my $tix = RT::Tickets->new($RT::SystemUser);
ok ($tix, "Got an RT::Tickets object");
ok ($tix->LimitReferredToBy($article_a->URI)); 
ok ($tix->Count == 1, "Found one ticket linked to that article");
ok ($tix->First->Id == $tick->id, "It's even the right one");



# Find all articles which refer to Ticket 1
use RT::FM::ArticleCollection;

my $articles = RT::FM::ArticleCollection->new($RT::SystemUser);
ok($articles->isa('RT::FM::ArticleCollection'), "Created an article collection");
ok($articles->isa('RT::FM::SearchBuilder'), "Created an article collection");
ok($articles->isa('RT::SearchBuilder'), "Created an article collection");
ok($articles->isa('DBIx::SearchBuilder'), "Created an article collection");
ok($tick->URI, "The ticket does still have a URI");
$articles->LimitRefersTo($tick->URI);

is($articles->Count(), 1);
is ($articles->First->Id, $article_a->Id);
is ($articles->First->URI, $article_a->URI);



# Find all things which refer to ticket 1 using the RT API.

my $tix2 = RT::Links->new($RT::SystemUser);
ok ($tix2->isa('RT::Links'));
ok($tix2->LimitRefersTo($tick->URI));
ok ($tix2->Count == 1);
is ($tix2->First->BaseObj->URI ,$article_a->URI);



# Delete the link from the RT side.
my $t2 = RT::Ticket->new($RT::SystemUser);
$t2->Load($tick->Id);
($id, $msg)= $t2->DeleteLink( Base => $article_a->URI, Type => 'RefersTo');
ok ($id, $msg . " - $id - $msg");

# it's actually deleted
my $tix3 = RT::Links->new($RT::SystemUser);
$tix3->LimitReferredToBy($tick->URI);
ok ($tix3->Count == 0);

# Recreate the link from teh RT site
($id, $msg) = $t2->AddLink( Base => $article_a->URI, Type => 'RefersTo');
ok ($id, $msg);

# Find all tickets whhich refer to Article A

# Find all articles which refer to Ticket 1


=end testing



=cut

# {{{ sub DeleteLink

=head2 DeleteLink

Delete a link. takes a paramhash of Base, Target and Type.
Either Base or Target must be null. The null value will 
be replaced with this ticket\'s id

=cut 

sub DeleteLink {
    my $self = shift;
    my %args = ( Base   => undef,
                 Target => undef,
                 Type   => undef,
                 @_ );

    #check acls
    unless ( $self->CurrentUserHasRight('ModifyArticle') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    #we want one of base and target. we don't care which
    #but we only want _one_
    my ( $link_type, $link_pointer );
    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug("$self ->_DeleteLink. got both Base and Target\n");
        return ( 0, $self->loc("Can't specifiy both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
        $link_type      = "ReferredToBy";
        $link_pointer   = $args{'Base'};
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
        $link_type    = "RefersTo";
        $link_pointer = $args{'Target'};
    }
    else {
        $RT::Logger->debug("$self: Base or Target must be specified\n");
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    my $link = new RT::Link( $self->CurrentUser );
    $RT::Logger->debug( "Trying to load link: "
                        . $args{'Base'} . " "
                        . $args{'Type'} . " "
                        . $args{'Target'}
                        . "\n" );
    $link->LoadByParams( Base   => $args{'Base'},
                         Type   => $args{'Type'},
                         Target => $args{'Target'} );

    #it's a real link.
    if ( $link->id ) {
        my $linkid = $link->Id;
        $RT::Logger->debug( "We're going to delete link " . $link->id . "\n" );
        $link->Delete();

        my $TransString =
          "Ticket $args{'Base'} no longer $args{Type} ticket $args{'Target'}.";
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
                                                     Type       => 'Link',
                                                     Field      => $link_type,
                                                     OldContent => $link_pointer
        );

        return ( $linkid,
                 $self->loc( "Link deleted ([_1])",
                             $args{'Base'} . " "
                               . $args{'Type'} . " "
                               . $args{'Target'} ) );
    }

    #if it's not a link we can find
    else {
        $RT::Logger->debug("Couldn't find that link\n");
        return ( 0, $self->loc("Link not found") );
    }
}

# }}}

# {{{ sub RefersTo

=head2 RefersTo

Return an RT::Links object which contains pointers to all the things 
which this article refers to

=cut

sub RefersTo {
    my $self = shift;
    return $self->_Links( Field => 'Base', Type => 'RefersTo' );

}

# }}}

# {{{ sub ReferredToBy

=head2 ReferredToBy

Return an RT::Links object which contains pointers to all the things 
which refer to this article.

=cut

sub ReferredToBy {
    my $self = shift;
    return $self->_Links( Field => 'Target', Type => 'RefersTo' );

}

# }}}

# {{{ sub _Links

sub _Links {
    my $self = shift;
    my %args = ( Field => undef,
                 Type  => undef,
                 @_ );

    my $search = new RT::Links( $self->CurrentUser );
    if ( $self->CurrentUserHasRight('ShowArticle') ) {

        $search->Limit( FIELD => $args{'Field'}, VALUE => $self->URI );
        $search->Limit( FIELD => 'Type', VALUE => $args{'Type'} )
          if ( $args{'Type'} );
    }
    return ($search);
}

# }}}

# }}}

# {{{ sub URI

=head2 URI

Returns this article's URI


=begin testing

my ($id,$msg);
my $art = RT::FM::Article->new($RT::SystemUser);
($id, $msg) = $art->Create (Class => 'ArticleTest');
ok ($id,$msg);

ok($art->URI);
ok($art->__Value('URI') eq $art->URI, "The uri in the db is set correctly");


=end testing

         
=cut

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


=begin testing

my ($id,$msg);
my $art = RT::FM::Article->new($RT::SystemUser);
($id, $msg) = $art->Create (Class => 'ArticleTest');
ok ($id,$msg);

ok($art->URIObj);
ok($art->__Value('URI') eq $art->URIObj->URI, "The uri in the db is set correctly");


=end testing

         
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
    
    my $topics = new RT::FM::ObjectTopicCollection($self->CurrentUser);
    if ($self->CurrentUserHasRight('ShowArticle')) {
        $topics->LimitToObject($self);
    }
    return $topics;
}
# }}}

# {{{ AddTopic
sub AddTopic {
    my $self = shift;
    my %args = ( @_ );
    
    unless ( $self->CurrentUserHasRight('ModifyArticleTopics') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my $t = new RT::FM::ObjectTopic($self->CurrentUser);
    my ($tid) = $t->Create( Topic      => $args{'Topic'},
                            ObjectType => ref($self),
                            ObjectId   => $self->Id );
    if ($tid) {
        return ($tid, $self->loc("Topic membership added"));
    } else {
        return (0, $self->loc("Unable to add topic membership"));
    } 
}
# }}}

# {{{ DeleteTopic
sub DeleteTopic {
    my $self = shift;
    my %args = ( @_ );

    unless ( $self->CurrentUserHasRight('ModifyArticleTopics') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my $t = new RT::FM::ObjectTopic($self->CurrentUser);
    $t->LoadByCols(Topic => $args{'Topic'}, ObjectId => $self->Id, ObjectType => ref($self));
    if ($t->Id) {
        my $del = $t->Delete;
        unless ($del) {
            return ( undef, 
                     $self->loc("Unable to delete topic membership in [_1]",
                                $t->TopicObj->Name));
        } else {
            return ( 1,
                     $self->loc("Topic membership removed"));
        }
    } else {
        return ( undef,
                 $self->loc("Couldn't load topic membership while trying to delete it"));
    }
}
# }}}
# }}}

# {{{ CurrentUserHasRight

=head2 CurrentUserHasRight

Returns true if the current user has the right for this article, for the whole system or for this article's class

=cut

sub CurrentUserHasRight {
    my $self  = shift;
    my $right = shift;

    return ( $self->CurrentUser->HasRight(
                            Right        => $right,
                            Object       => $self,
                            EquivObjects => [ $RT::FM::System, $RT::System, $self->ClassObj ]
             ) );

}

# }}}

# {{{ _NewTransaction

=head2 _NewTransaction PARAMHASH


Takes a hash of:

Type
Field
OldContent
NewContent
Data 


=cut

sub _NewTransaction {
    my $self = shift;
    my %args = ( Type       => undef,
                 Field      => '',
                 OldContent => '',
                 NewContent => '',
                 ChangeLog  => '',
                 @_ );

    my $trans = RT::Transaction->new( $self->CurrentUser );
    $trans->Create( Object    => $self,
                    Type       => $args{'Type'},
                    Field      => $args{'Field'},
                    OldContent => $args{'OldContent'},
                    NewContent => $args{'NewContent'})

    #something bad happened;
    unless ( $trans->Id ) {
        $RT::Logger->crit(
                       $self . " could not create a transaction for " . %args );
        return ( undef, $self->loc("Internal error"), $trans );
    }

    return ( $trans->id, $self->loc("Transaction recorded"), $trans );
}

# }}}

=head2 Transactions

Returns an RT::FM::TransactionCollection pre-loaded with all the transactions for tthis Article. If the current user doesn't have the right to 'ShowArticleHistory',
this object is an _empty_ TransactionCollection

=cut

sub Transactions {
    my $self         = shift;
    my $transactions = RT::Transactions->new( $self->CurrentUser );

    if ( $self->CurrentUserHasRight('ShowArticleHistory') ) {
         $transactions->Limit( FIELD => 'ObjectType', VALUE => 'RT::FM::Article');
         $transactions->Limit( FIELD    => 'ObjectId', OPERATOR => '=', VALUE    => $self->Id );
    }

    return ($transactions);

}

# {{{ _Set

=head2 _Set { Field => undef, Value => undef

Internal helper method to record a transaction as we update some core field of the article


=begin testing

my $art = RT::FM::Article->new($RT::SystemUser);
$art->Load(1);
ok ($art->Id == 1, "Loaded article 1");
my $s =$art->Summary;
my ($val, $msg) = $art->SetSummary("testFoo");
ok ($val, $msg);
ok ($art->Summary eq 'testFoo', "The Summary was set to foo");
my $t = $art->Transactions();
my $trans = $t->Last;
ok ($trans->Type eq 'Core', "It's a core transaction");
ok ($trans->Field eq 'Summary', "it's about setting the Summary");
ok ($trans->NewContent eq 'testFoo', "The new content is 'foo'");
ok ($trans->OldContent, "There was some old value");


=end testing

=cut

sub _Set {
    my $self = shift;
    my %args = ( Field => undef,
                 Value => undef,
                 @_ );

    unless ( $self->CurrentUserHasRight('ModifyArticle') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    $self->_NewTransaction( Type       => 'Core',
                            Field      => $args{'Field'},
                            NewContent => $args{'Value'},
                            OldContent => $self->__Value( $args{'Field'} ) );

    return ( $self->SUPER::_Set(%args) );

}

=head2 _Value PARAM

Return "PARAM" for this object. if the current user doesn't have rights, returns undef

=cut

sub _Value {
    my $self = shift;
    my $arg  = shift;
    unless (    ( $arg eq 'Class' )
             || ( $self->CurrentUserHasRight('ShowArticle') ) ) {
        return (undef);
    }
    return $self->SUPER::_Value($arg);
}

# }}}

1;
