use strict;
no warnings qw(redefine);

# {{{ LINKDIRMAP
# A helper table for relationships mapping to make it easier
# to build and parse links between tickets

use vars '%LINKDIRMAP';

%LINKDIRMAP = (
    MemberOf => { Base => 'MemberOf',
                  Target => 'HasMember', },
    RefersTo => { Base => 'RefersTo',
                Target => 'ReferredToBy', },
    DependsOn => { Base => 'DependsOn',
                   Target => 'DependedOnBy', },
    MergedInto => { Base => 'MergedInto',
                   Target => 'MergedInto', },

);

sub Update {
    my $self = shift;

    my %args = (
        ARGSRef       => undef,
        AttributesRef => undef,
        AttributePrefix => undef,
        @_
    );

    my $attributes = $args{'AttributesRef'};
    my $ARGSRef    = $args{'ARGSRef'};
    my @results;

    foreach my $attribute (@$attributes) {
        my $value;
        if ( defined $ARGSRef->{$attribute} ) {
            $value = $ARGSRef->{$attribute};
        }
        elsif (
              defined( $args{'AttributePrefix'} )
              && defined(
                  $ARGSRef->{ $args{'AttributePrefix'} . "-" . $attribute }
              )
          ) {
            $value = $ARGSRef->{ $args{'AttributePrefix'} . "-" . $attribute };

        } else {
                next;
        }

            $value =~ s/\r\n/\n/gs;

        if ($value ne $self->$attribute()){

              my $method = "Set$attribute";
              my ( $code, $msg ) = $self->$method($value);

              push @results, $self->loc("Ticket [_1]", $self->id) . ': ' . $self->loc($attribute) . ': ' . $self->loc_fuzzy($msg);
=for loc
                                   "[_1] could not be set to [_2].",       # loc
                                   "That is already the current value",    # loc
                                   "No value sent to _Set!\n",             # loc
                                   "Illegal value for [_1]",               # loc
                                   "The new value has been set.",          # loc
                                   "No column specified",                  # loc
                                   "Immutable field",                      # loc
                                   "Nonexistant field?",                   # loc
                                   "Invalid data",                         # loc
                                   "Couldn't find row",                    # loc
                                   "Missing a primary key?: [_1]",         # loc
                                   "Found Object",                         # loc
=cut
          };

    }

    return @results;
}

# {{{ loc_fuzzy

=head2 loc_fuzzy STRING

loc_fuzzy is for handling localizations of messages that may already
contain interpolated variables, typically returned from libraries
outside RT's control.  It takes the message string and extracts the
variable array automatically by matching against the candidate entries
inside the lexicon file.

=cut

sub loc_fuzzy {
    my $self = shift;
    my $msg  = shift;
    
    if ($self->CurrentUser && 
        UNIVERSAL::can($self->CurrentUser, 'loc')){
        return($self->CurrentUser->loc_fuzzy($msg));
    }
    else  {
        my $u = RT::CurrentUser->new($RT::SystemUser->Id);
        return ($u->loc_fuzzy($msg));
    }
}

# }}}


# {{{ loc

=head2 loc ARRAY

loc is a nice clean global routine which calls $session{'CurrentUser'}->loc()
with whatever it's called with. If there is no $session{'CurrentUser'}, 
it creates a temporary user, so we have something to get a localisation handle
through

=cut

sub loc {
    my $self = shift;

    if ($self->CurrentUser && 
        UNIVERSAL::can($self->CurrentUser, 'loc')){
        return($self->CurrentUser->loc(@_));
    }
    elsif ( my $u = eval { RT::CurrentUser->new($RT::SystemUser->Id) } ) {
        return ($u->loc(@_));
    }
    else {
	# pathetic case -- SystemUser is gone.
	return $_[0];
    }
}

# }}}

# {{{ Routines dealing with Links and Relations between tickets

# {{{ Link Collections

# {{{ sub Members

=head2 Members

  This returns an RT::Links object which references all the tickets 
which are 'MembersOf' this ticket

=cut

sub Members {
    my $self = shift;
    return ( $self->_Links( 'Target', 'MemberOf' ) );
}

# }}}

# {{{ sub MemberOf

=head2 MemberOf

  This returns an RT::Links object which references all the tickets that this
ticket is a 'MemberOf'

=cut

sub MemberOf {
    my $self = shift;
    return ( $self->_Links( 'Base', 'MemberOf' ) );
}

# }}}

# {{{ RefersTo

=head2 RefersTo

  This returns an RT::Links object which shows all references for which this ticket is a base

=cut

sub RefersTo {
    my $self = shift;
    return ( $self->_Links( 'Base', 'RefersTo' ) );
}

# }}}

# {{{ ReferredToBy

=head2 ReferredToBy

  This returns an RT::Links object which shows all references for which this ticket is a target

=cut

sub ReferredToBy {
    my $self = shift;
    return ( $self->_Links( 'Target', 'RefersTo' ) );
}

# }}}

# {{{ DependedOnBy

=head2 DependedOnBy

  This returns an RT::Links object which references all the tickets that depend on this one

=cut

sub DependedOnBy {
    my $self = shift;
    return ( $self->_Links( 'Target', 'DependsOn' ) );
}

# }}}



=head2 HasUnresolvedDependencies

  Takes a paramhash of Type (default to '__any').  Returns true if
$self->UnresolvedDependencies returns an object with one or more members
of that type.  Returns false otherwise


=begin testing

my $t1 = RT::Ticket->new($RT::SystemUser);
my ($id, $trans, $msg) = $t1->Create(Subject => 'DepTest1', Queue => 'general');
ok($id, "Created dep test 1 - $msg");

my $t2 = RT::Ticket->new($RT::SystemUser);
my ($id2, $trans, $msg2) = $t2->Create(Subject => 'DepTest2', Queue => 'general');
ok($id2, "Created dep test 2 - $msg2");
my $t3 = RT::Ticket->new($RT::SystemUser);
my ($id3, $trans, $msg3) = $t3->Create(Subject => 'DepTest3', Queue => 'general', Type => 'approval');
ok($id3, "Created dep test 3 - $msg3");
my ($addid, $addmsg);
ok (($addid, $addmsg) =$t1->AddLink( Type => 'DependsOn', Target => $t2->id));
ok ($addid, $addmsg);
ok (($addid, $addmsg) =$t1->AddLink( Type => 'DependsOn', Target => $t3->id));

ok ($addid, $addmsg);
ok ($t1->HasUnresolvedDependencies, "Ticket ".$t1->Id." has unresolved deps");
ok (!$t1->HasUnresolvedDependencies( Type => 'blah' ), "Ticket ".$t1->Id." has no unresolved blahs");
ok ($t1->HasUnresolvedDependencies( Type => 'approval' ), "Ticket ".$t1->Id." has unresolved approvals");
ok (!$t2->HasUnresolvedDependencies, "Ticket ".$t2->Id." has no unresolved deps");
;

my ($rid, $rmsg)= $t1->Resolve();
ok(!$rid, $rmsg);
ok($t2->Resolve);
($rid, $rmsg)= $t1->Resolve();
ok(!$rid, $rmsg);
ok($t3->Resolve);
($rid, $rmsg)= $t1->Resolve();
ok($rid, $rmsg);


=end testing

=cut

sub HasUnresolvedDependencies {
    my $self = shift;
    my %args = (
        Type   => undef,
        @_
    );

    my $deps = $self->UnresolvedDependencies;

    if ($args{Type}) {
        $deps->Limit( FIELD => 'Type', 
              OPERATOR => '=',
              VALUE => $args{Type}); 
    }
    else {
	    $deps->IgnoreType;
    }

    if ($deps->Count > 0) {
        return 1;
    }
    else {
        return (undef);
    }
}


# {{{ UnresolvedDependencies 

=head2 UnresolvedDependencies

Returns an RT::Tickets object of tickets which this ticket depends on
and which have a status of new, open or stalled. (That list comes from
RT::Queue->ActiveStatusArray

=cut


sub UnresolvedDependencies {
    my $self = shift;
    my $deps = RT::Tickets->new($self->CurrentUser);

    my @live_statuses = RT::Queue->ActiveStatusArray();
    foreach my $status (@live_statuses) {
        $deps->LimitStatus(VALUE => $status);
    }
    $deps->LimitDependedOnBy($self->Id);

    return($deps);

}

# }}}

# {{{ AllDependedOnBy

=head2 AllDependedOnBy

Returns an array of RT::Ticket objects which (directly or indirectly)
depends on this ticket; takes an optional 'Type' argument in the param
hash, which will limit returned tickets to that type, as well as cause
tickets with that type to serve as 'leaf' nodes that stops the recursive
dependency search.

=cut

sub AllDependedOnBy {
    my $self = shift;
    my $dep = $self->DependedOnBy;
    my %args = (
        Type   => undef,
	_found => {},
	_top   => 1,
        @_
    );

    while (my $link = $dep->Next()) {
	next unless ($link->BaseURI->IsLocal());
	next if $args{_found}{$link->BaseObj->Id};

	if (!$args{Type}) {
	    $args{_found}{$link->BaseObj->Id} = $link->BaseObj;
	    $link->BaseObj->AllDependedOnBy( %args, _top => 0 );
	}
	elsif ($link->BaseObj->Type eq $args{Type}) {
	    $args{_found}{$link->BaseObj->Id} = $link->BaseObj;
	}
	else {
	    $link->BaseObj->AllDependedOnBy( %args, _top => 0 );
	}
    }

    if ($args{_top}) {
	return map { $args{_found}{$_} } sort keys %{$args{_found}};
    }
    else {
	return 1;
    }
}

# }}}

# {{{ DependsOn

=head2 DependsOn

  This returns an RT::Links object which references all the tickets that this ticket depends on

=cut

sub DependsOn {
    my $self = shift;
    return ( $self->_Links( 'Base', 'DependsOn' ) );
}

# }}}




# {{{ sub _Links 

sub _Links {
    my $self = shift;

    #TODO: Field isn't the right thing here. but I ahave no idea what mnemonic ---
    #tobias meant by $f
    my $field = shift;
    my $type  = shift || "";

    unless ( $self->{"$field$type"} ) {
        $self->{"$field$type"} = new RT::Links( $self->CurrentUser );
            # at least to myself
            $self->{"$field$type"}->Limit( FIELD => $field,
                                           VALUE => $self->URI,
                                           ENTRYAGGREGATOR => 'OR' );
            $self->{"$field$type"}->Limit( FIELD => 'Type',
                                           VALUE => $type )
              if ($type);
    }
    return ( $self->{"$field$type"} );
}

# }}}

# }}}

# {{{ sub _AddLink

=head2 _AddLink

Takes a paramhash of Type and one of Base or Target. Adds that link to this ticket.


=cut


sub _AddLink {
    my $self = shift;
    my %args = ( Target => '',
                 Base   => '',
                 Type   => '',
                 Silent => undef,
                 @_ );


    # Remote_link is the URI of the object that is not this ticket
    my $remote_link;
    my $direction;

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug(
"$self tried to delete a link. both base and target were specified\n" );
        return ( 0, $self->loc("Can't specifiy both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
	my $class = ref($self);
        $remote_link    = $args{'Base'};
        $direction      = 'Target';
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
	my $class = ref($self);
        $remote_link  = $args{'Target'};
        $direction    = 'Base';
    }
    else {
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    # {{{ Check if the link already exists - we don't want duplicates
    use RT::Link;
    my $old_link = RT::Link->new( $self->CurrentUser );
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
    my ($linkid, $linkmsg) = $link->Create( Target => $args{Target},
                                  Base   => $args{Base},
                                  Type   => $args{Type} );

    unless ($linkid) {
        $RT::Logger->error("Link could not be created: ".$linkmsg);
        return ( 0, $self->loc("Link could not be created") );
    }

    my $TransString =
      "Record $args{'Base'} $args{Type} record $args{'Target'}.";

    return ( 1, $self->loc( "Link created ([_1])", $TransString ) );
}

# }}}

# {{{ sub _DeleteLink 

=head2 _DeleteLink

Delete a link. takes a paramhash of Base, Target and Type.
Either Base or Target must be null. The null value will 
be replaced with this ticket\'s id

=cut 

sub _DeleteLink {
    my $self = shift;
    my %args = (
        Base   => undef,
        Target => undef,
        Type   => undef,
        @_
    );

    #we want one of base and target. we don't care which
    #but we only want _one_

    my $direction;
    my $remote_link;

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug("$self ->_DeleteLink. got both Base and Target\n");
        return ( 0, $self->loc("Can't specifiy both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
	$remote_link = $args{'Base'};
    	$direction = 'Target';
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
	$remote_link = $args{'Target'};
        $direction='Base';
    }
    else {
        $RT::Logger->debug("$self: Base or Target must be specified\n");
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    my $link = new RT::Link( $self->CurrentUser );
    $RT::Logger->debug( "Trying to load link: " . $args{'Base'} . " " . $args{'Type'} . " " . $args{'Target'} . "\n" );


    $link->LoadByParams( Base=> $args{'Base'}, Type=> $args{'Type'}, Target=>  $args{'Target'} );
    #it's a real link. 
    if ( $link->id ) {

        my $linkid = $link->id;
        $link->Delete();

        my $TransString = "Record $args{'Base'} no longer $args{Type} record $args{'Target'}.";
        return ( 1, $self->loc("Link deleted ([_1])", $TransString));
    }

    #if it's not a link we can find
    else {
        $RT::Logger->debug("Couldn't find that link\n");
        return ( 0, $self->loc("Link not found") );
    }
}

# }}}


1;
