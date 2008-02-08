use warnings;
use strict;

package RT::View::Admin::Groups;
use Jifty::View::Declare -base;
use base 'Jifty::View::Declare::CRUD';

__PACKAGE__->use_mason_wrapper;


#sub per_page           {50}
sub object_type        {'Group'}
sub display_columns { qw(id name description) }

sub _current_collection {
    my $self = shift;
    my $c = $self->SUPER::_current_collection();
    warn $c;
    $c->limit_to_user_defined_groups();
    return $c;
}

1;
