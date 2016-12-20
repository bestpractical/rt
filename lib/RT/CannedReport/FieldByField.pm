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
    my $report = shift;
    return [{Option => "field2", Values => [{Name => "By Owner",  Key => 'owner'},
                                            {Name => "By Queue",  Key => 'queue'}]
            },
            {Option => "within", Values => [{Name => "Today",     Key => 'Today'},
                                            {Name => "This Week", Key => '7 Days'}]
            },
    ];
}

#Placeholder for chosen options
sub Config {
    my $self = shift;
    return {Field1 => "Resolved",
            Field2 => "Owner",
            Within => "7 Days", # '__Custom__' to use start & end
            Start  => "2016/01/01",
            End    => "2017/01/01",
    };
}

#TODO: status shouldn't be hardcoded
sub Results {
    my $self = shift;

    my %config = %{$self->Config()};
    my %state;#State machine for building the query
    #type
    #   field - add all field values
    #   count - count tickets

    my $collection = RT::Tickets->new(RT->SystemUser);

    my $query = "";

    my $f1 = lc $config{Field1};
    if ($f1 eq "resolved" || $f1 eq "open" || $f1 eq "stalled") {
        $query .= "status = '$f1'";
        $state{"f1"}{"type"} = "count";
    }elsif ($f1 eq "timeworked") {
        $state{"f1"}{"type"} = "field";
    }else{
        $query .= "status = '$f1'";
        $state{"f1"}{"type"} = "count";
    }

    my $within = $config{Within};
    if (!$within || $within eq "__Custom__") {
        $query .= " AND LastUpdated < '$within'";
    }else{
        my $start = $config{Start};
        my $end = $config{End};
        $query .= " AND LastUpdated > '$start' AND LastUpdated < '$end'";
    }

    $collection->FromSQL($query);
    $collection->UnLimit();
    my %results;
    my $f2 = lc $config{Field2};
    if (lc $f2 eq "queue") {
        while (my $ticket = $collection->Next) {
            $results{$ticket->QueueObj->Name} += 1;
        }
    }else{#Default
        while (my $ticket = $collection->Next) {
            $results{$ticket->OwnerObj->Name} += 1;
        }
    }
    return %results;
}

1;
