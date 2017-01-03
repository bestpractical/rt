# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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

package RT::CannedReport::FieldByField;

use strict;
use warnings;
use base 'RT::CannedReport';

sub Reports {
    my $self = shift;
    return {"Resolved"    => {Option => 'resolved',    Key => 'Field1'},
            "Created"     => {Option => 'created',     Key => 'Field1'},
            "Time Worked" => {Option => 'timeworked',  Key => 'Field1'},
    };
}

sub Options {
    my $self = shift;
    return [{Option => "field2", Values => [{Name => "By Owner",  Key => 'owner'},
                                            {Name => "By Queue",  Key => 'queue'}]
            },
            {Option => "within", Values => [{Name => "Today",     Key => 'Today'},
                                            {Name => "This Week", Key => '7 Days'}]
            },
    ];
}

#TODO: status shouldn't be hardcoded
sub Results {
    my $self = shift;
    my $parameters = shift;

    my $collection = RT::Tickets->new(RT->SystemUser);

    my $query = "";

    my $name = lc $parameters->{"name"};
    if (!$name || $name eq "resolved") { ### DEFAULT ###
        $query .= "status = 'resolved'";
    }

    $collection->FromSQL($query);
    $collection->UnLimit();
    my %results;

    if ($name eq "created") {
        while (my $ticket = $collection->Next) {
            $results{$ticket->CreatorObj->Name} += 1;
        }
    }elsif ($name eq "time worked") {
        while (my $ticket = $collection->Next) {
            $results{$ticket->CreatorObj->Name} += $ticket->TimeWorked;
        }
    }else{#if ($name eq "Resolved") { ### DEFAULT ###
        while (my $ticket = $collection->Next) {
            $results{$ticket->OwnerObj->Name} += 1;
        }
    }

    my @values;
    for my $key (keys %results) {
        push @values, {name => $key, value => $results{$key}};
    }

    return \@values;
}


1;
