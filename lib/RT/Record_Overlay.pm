use strict;
no warnings qw(redefine);

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


1;
