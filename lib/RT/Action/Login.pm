use warnings;
use strict;
package RT::Action::Login;
use base qw/Jifty::Plugin::Authentication::Password::Action::Login/;

sub load_user {
    my $self = shift;
    my $username = shift;
    my $user = Jifty->app_class('Model', 'User')->new(current_user => Jifty->app_class('CurrentUser')->superuser);
    $user->load_by_cols( name => $username);
    return $user;


}
1;
