package RT::Shredder::Exception;

use warnings;
use strict;

use Exception::Class;
use base qw(Exception::Class::Base);

BEGIN {
    __PACKAGE__->NoRefs(0);
}

#sub NoRefs { return 0 }
sub show_trace { return 1 }

package RT::Shredder::Exception::Info;

use base qw(RT::Shredder::Exception);

my %DESCRIPTION = (
    DependenciesLimit => <<END,
Dependecies list have reached its limit.
See \$RT::DependenciesLimit in RT::Shredder docs.
END

    SystemObject => <<END,
System object was requested for deletion, shredder couldn't
do that because system would be unusable than.
END

    CouldntLoadObject => <<END,
Shredder couldn't load object. Most probably it's not fatal error.
May be you've used Objects plugin and asked to delete object that
doesn't exist in the system. If you think that your request was
correct and it's problem of the Shredder then you can get full error
message from RT log files and send bug report.
END

    NoResolver => <<END,
Object has dependency that could be resolved, but resolver
wasn't defined. You have to re-read documentation of the
plugin you're using, for example the 'Users' plugin has
option 'replace_relations' argument.
END
);

sub full_message {
    my $self = shift;
    my $error = $self->message;
    return $DESCRIPTION{$error} || $error;
}

sub show_trace { return 0 }

1;
