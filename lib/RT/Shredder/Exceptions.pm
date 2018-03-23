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
Dependencies list has reached its limit.
See \$RT::DependenciesLimit in RT::Shredder docs.
END

    SystemObject => <<END,
System object was selected for deletion, shredder couldn't
do that because system would be unusable then.
END

    CouldntLoadObject => <<END,
Shredder couldn't load object. Most likely it's not a fatal error.
Perhaps you've used the Objects plugin and asked to delete an object that
doesn't exist in the system. If you think that your request was
correct and it's a problem of the Shredder then you can get a full error
message from RT log files and send a bug report.
END

    NoResolver => <<END,
Object has dependency that could be resolved, but resolver
wasn't defined. You have to re-read the documentation of the
plugin you're using. For example the 'Users' plugin has
option 'replace_relations' argument.
END
);

sub Fields { return ((shift)->SUPER::Fields(@_), 'tag') }

sub tag { return (shift)->{'tag'} }

sub full_message {
    my $self = shift;
    my $error = $self->message;
    if ( my $tag = $self->tag ) {
        my $message = $DESCRIPTION{ $self->tag } || '';
        warn "Tag '$tag' doesn't exist" unless $message;
        $message .= "\nAdditional info:\n$error" if $error;
        return $message;
    }
    return $DESCRIPTION{$error} || $error;
}

sub show_trace { return 0 }

1;
