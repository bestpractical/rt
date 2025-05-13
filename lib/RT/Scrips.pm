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

=head1 NAME

  RT::Scrips - a collection of RT Scrip objects

=head1 SYNOPSIS

  use RT::Scrips;

=head1 DESCRIPTION


=head1 METHODS



=cut


package RT::Scrips;

use strict;
use warnings;

use base 'RT::SearchBuilder';

use RT::Scrip;
use RT::ObjectScrips;

sub Table { 'Scrips'}

sub _Init {
    my $self = shift;

    $self->{'with_disabled_column'} = 1;

    return ( $self->SUPER::_Init(@_) );
}


=head2 LimitToLookupType LOOKUPTYPE

Takes LookupType and limits collection.

=cut

sub LimitToLookupType {
    my $self = shift;
    my $lookup = shift;

    $self->Limit( FIELD => 'LookupType', VALUE => $lookup );
}


=head2 LimitToObjectId

Takes an object id (numerical) as its only argument. Makes sure that 
Scopes it pulls out apply to this object (or another that you've selected with
another call to this method

=cut

sub LimitToObjectId {
    my $self      = shift;
    my $object_id = shift;
    return unless defined $object_id;

    my $alias = RT::ObjectScrips->new( $self->CurrentUser )->JoinTargetToThis($self);
    $self->Limit(
        ALIAS => $alias,
        FIELD => 'ObjectId',
        VALUE => int $object_id,
    );
}

sub LimitToQueue {
    my $self = shift;
    RT->Deprecated(
        Message => 'LimitToQueue is deprecated',
        Instead => 'LimitToObjectId',
        Remove  => 6.2,
    );
    return $self->LimitToObjectId(@_);
}

=head2 LimitToGlobal

Makes sure that 
Scopes it pulls out apply to all queues (or another that you've selected with
another call to this method or LimitToQueue

=cut


sub LimitToGlobal  {
    my $self = shift;
    return $self->LimitToObjectId(0);
}

sub LimitToAdded {
    my $self = shift;
    return RT::ObjectScrips->new( $self->CurrentUser )
        ->LimitTargetToAdded( $self => @_ );
}

sub LimitToNotAdded {
    my $self = shift;
    return RT::ObjectScrips->new( $self->CurrentUser )
        ->LimitTargetToNotAdded( $self => @_ );
}

sub LimitByStage  {
    my $self = shift;
    my %args = @_%2? (Stage => @_) : @_;
    return unless defined $args{'Stage'};

    my $alias = RT::ObjectScrips->new( $self->CurrentUser )
        ->JoinTargetToThis( $self, %args );
    $self->Limit(
        ALIAS => $alias,
        FIELD => 'Stage',
        VALUE => $args{'Stage'},
    );
}

=head2 LimitByTemplate

Takes a L<RT::Template> object and limits scrips to those that
use the template.

=cut

sub LimitByTemplate {
    my $self = shift;
    my $template = shift;

    $self->LimitToLookupType( $template->LookupType );
    $self->Limit( FIELD => 'Template', VALUE => $template->Name );
    if ( $template->ObjectId ) {
        # if template is local then we are interested in global and
        # object specific scrips
        $self->LimitToObjectId( $template->ObjectId );
        $self->LimitToGlobal;
    }
    else { # template is global
        # if every object has a custom version then there
        # is no scrip that uses the template
        {
            my $collection_class = $template->CollectionClassFromLookupType( $template->RecordClassFromLookupType );
            my $collection       = $collection_class->new( $self->CurrentUser );

            my $alias = $collection->Join(
                TYPE   => 'LEFT',
                ALIAS1 => 'main',
                FIELD1 => 'id',
                TABLE2 => 'Templates',
                FIELD2 => 'ObjectId',
            );
            $collection->Limit(
                LEFTJOIN   => $alias,
                ALIAS      => $alias,
                FIELD      => 'Name',
                VALUE      => $template->Name,
            );
            $collection->Limit(
                ALIAS      => $alias,
                FIELD      => 'id',
                OPERATOR   => 'IS',
                VALUE      => 'NULL',
            );
            return $self->Limit( FIELD => 'id', VALUE => 0 )
                unless $collection->Count;
        }

        # otherwise it's either a global scrip or application to
        # a queue with custom version of the template.
        my $os_alias = RT::ObjectScrips->new( $self->CurrentUser )
            ->JoinTargetToThis( $self );
        my $tmpl_alias = $self->Join(
            TYPE   => 'LEFT',
            ALIAS1 => $os_alias,
            FIELD1 => 'ObjectId',
            TABLE2 => 'Templates',
            FIELD2 => 'ObjectId',
        );
        $self->Limit(
            LEFTJOIN => $tmpl_alias, ALIAS => $tmpl_alias, FIELD => 'Name', VALUE => $template->Name,
        );
        $self->Limit(
            LEFTJOIN => $tmpl_alias, ALIAS => $tmpl_alias, FIELD => 'ObjectId', OPERATOR => '!=', VALUE => 0,
        );

        $self->_OpenParen('UsedBy');
        $self->Limit( SUBCLAUSE => 'UsedBy', ALIAS => $os_alias, FIELD => 'ObjectId', VALUE => 0 );
        $self->Limit(
            SUBCLAUSE => 'UsedBy',
            ALIAS => $tmpl_alias,
            FIELD => 'id',
            OPERATOR => 'IS',
            VALUE => 'NULL',
        );
        $self->_CloseParen('UsedBy');
    }
}

sub ApplySortOrder {
    my $self = shift;
    my $order = shift || 'ASC';
    $self->OrderByCols( {
        ALIAS => RT::ObjectScrips->new( $self->CurrentUser )
            ->JoinTargetToThis( $self => @_ )
        ,
        FIELD => 'SortOrder',
        ORDER => $order,
    } );
}

=head2 AddRecord

Overrides the collection to ensure that only scrips the user can see are
returned.

=cut

sub AddRecord {
    my $self = shift;
    my ($record) = @_;

    return unless $record->CurrentUserHasRight('ShowScrips');
    return $self->SUPER::AddRecord( $record );
}

=head2 Apply

Run through the relevant scrips.  Scrips will run in order based on 
description.  (Most common use case is to prepend a number to the description,
forcing the scrips to run in ascending alpha-numerical order.)

=cut

sub Apply {
    my $self = shift;

    my %args = ( TicketObj      => undef,
                 Ticket         => undef,
                 Transaction    => undef,
                 TransactionObj => undef,
                 Stage          => undef,
                 Type           => undef,
                 @_ );

    $self->Prepare(%args);
    $self->Commit();

}

=head2 Commit

Commit all of this object's prepared scrips

=cut

sub Commit {
    my $self = shift;

    foreach my $scrip (@{$self->Prepared}) {
        my $type = $self->{'Object'}->RecordType;
        $RT::Logger->debug(
            "Committing scrip #". $scrip->id
            ." on txn #". $self->{'TransactionObj'}->id
            ." of ". lc($type) ." #". $self->{'Object'}->id
        );

        $scrip->Commit(
            Object         => $self->{'Object'},
            TicketObj      => $self->{'TicketObj'},
            AssetObj       => $self->{'AssetObj'},
            ArticleObj     => $self->{'ArticleObj'},
            TransactionObj => $self->{'TransactionObj'}
        );
    }

}


=head2 Prepare

Only prepare the scrips, returning an array of the scrips we're interested in
in order of preparation, not execution

=cut

sub Prepare { 
    my $self = shift;
    my %args = (
        Object         => undef,
        ObjectType     => undef,
        ObjectId       => undef,
        LookupType     => undef,
        Transaction    => undef,
        TransactionObj => undef,
        Stage          => undef,
        Type           => undef,
        @_
    );

    # Backward-compatibility
    $args{'LookupType'} ||= 'RT::Queue-RT::Ticket';

    #We're really going to need a non-acled ticket for the scrips to work
    $self->_SetupSourceObjects(
        Object         => $args{'Object'},
        ObjectId       => $args{'ObjectId'},
        LookupType     => $args{'LookupType'},
        TransactionObj => $args{'TransactionObj'},
        Transaction    => $args{'Transaction'}
    );

    $self->_FindScrips( Stage => $args{'Stage'}, Type => $args{'Type'} );


    #Iterate through each script and check it's applicability.
    while ( my $scrip = $self->Next() ) {

        unless (
            $scrip->IsApplicable(
                Object         => $self->{'Object'},
                $self->{'Object'}->RecordType . 'Obj' => $self->{'Object'},
                TransactionObj => $self->{'TransactionObj'},
            )
            )
        {
            $RT::Logger->debug( "Skipping Scrip #" . $scrip->Id . " because it isn't applicable" );
            next;
        }


        #If it's applicable, prepare and commit it
        unless (
            $scrip->Prepare(
                Object                                => $self->{'Object'},
                $self->{'Object'}->RecordType . 'Obj' => $self->{'Object'},
                TransactionObj                        => $self->{'TransactionObj'}
            )
            )
        {
            $RT::Logger->debug( "Skipping Scrip #" . $scrip->Id . " because it didn't Prepare" );
            next;
        }

        push @{$self->{'prepared_scrips'}}, $scrip;

    }

    return (@{$self->Prepared});

};

=head2 Prepared

Returns an arrayref of the scrips this object has prepared


=cut

sub Prepared {
    my $self = shift;
    return ($self->{'prepared_scrips'} || []);
}

=head2  _SetupSourceObjects { Object, ObjectId, LookupType, Transaction, TransactionObj }

Setup a ticket and transaction for this Scrip collection to work with as it runs through the 
relevant scrips.  (Also to figure out which scrips apply)

Returns: nothing

=cut


sub _SetupSourceObjects {

    my $self = shift;
    my %args = (
        Object         => undef,
        ObjectId       => undef,
        LookupType     => undef,
        Transaction    => undef,
        TransactionObj => undef,
        @_
    );

    $self->{'LookupType'} = $args{'LookupType'};

    my $class = RT::Scrip->ObjectTypeFromLookupType( $self->{'LookupType'} );
    if ( $args{'Object'} ) {
        # This loads a clean copy of the Ticket object to ensure that we
        # don't accidentally escalate the privileges of the passed in
        # ticket (this function can be invoked from the UI).
        # We copy the TransactionBatch transactions so that Scrips
        # running against the new Ticket will have access to them. We
        # use RanTransactionBatch to guard against running
        # TransactionBatch Scrips more than once.
        $self->{'Object'} = $class->new( $self->CurrentUser );
        $self->{'Object'}->Load( $args{'Object'}->Id );
        if ( $args{'Object'}->TransactionBatch ) {
            # try to ensure that we won't infinite loop if something dies, triggering DESTROY while 
            # we have the _TransactionBatch objects;
            $self->{'Object'}->RanTransactionBatch(1);
            $self->{'Object'}->{'_TransactionBatch'} = $args{'Object'}->{'_TransactionBatch'};
        }
    }
    else {
        $self->{'Object'} = $class->new( $self->CurrentUser );
        $self->{'Object'}->Load( $args{'ObjectId'} )
          || $RT::Logger->err("$self couldn't load ". lc($class->RecordType) ." $args{'ObjectId'}");
    }

    if ( ( $self->{'TransactionObj'} = $args{'TransactionObj'} ) ) {
        $self->{'TransactionObj'}->CurrentUser( $self->CurrentUser );
    }
    else {
        $self->{'TransactionObj'} = RT::Transaction->new( $self->CurrentUser );
        $self->{'TransactionObj'}->Load( $args{'Transaction'} )
          || $RT::Logger->err( "$self couldn't load transaction $args{'Transaction'}");
    }
} 



=head2 _FindScrips

Find only the appropriate scrips for whatever we're doing now.  Order
them by the SortOrder field from the ObjectScrips table.

=cut

sub _FindScrips {
    my $self = shift;
    my %args = (
                 Stage => undef,
                 Type => undef,
                 @_ );

    $self->LimitToLookupType( $self->{'LookupType'} );
    my $method = RT::Scrip->RecordClassFromLookupType($self->{'LookupType'})->RecordType ."Obj";
    $self->LimitToObjectId( $self->{'Object'}->$method->Id );
    $self->LimitToGlobal;
    $self->LimitByStage( $args{'Stage'} );

    my $ConditionsAlias = $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'ScripCondition',
        TABLE2 => 'ScripConditions',
        FIELD2 => 'id',
    );

    #We only want things where the scrip applies to this sort of transaction
    # TransactionBatch stage can define list of transaction
    foreach( split /\s*,\s*/, ($args{'Type'} || '') ) {
        $self->Limit(
            ALIAS           => $ConditionsAlias,
            FIELD           => 'ApplicableTransTypes',
            OPERATOR        => 'LIKE',
            VALUE           => $_,
            ENTRYAGGREGATOR => 'OR',
        )
    }

    # Or where the scrip applies to any transaction
    $self->Limit(
        ALIAS           => $ConditionsAlias,
        FIELD           => 'ApplicableTransTypes',
        OPERATOR        => 'LIKE',
        VALUE           => "Any",
        ENTRYAGGREGATOR => 'OR',
    );

    $self->ApplySortOrder;

    # we call Count below, but later we always do search
    # so just do search and get count from results
    $self->_DoSearch if $self->{'must_redo_search'};

    my $type = $self->{'Object'}->RecordType;
    $RT::Logger->debug(
        "Found ". $self->Count ." scrips for $args{'Stage'} stage"
        ." with applicable type(s) $args{'Type'}"
        ." for txn #".$self->{TransactionObj}->Id
        ." on ". lc($type) ." #".$self->{'Object'}->Id
    );
}

RT::Base->_ImportOverlays();

1;
