# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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

  RT::Search::Googlish

=head1 SYNOPSIS

=head1 DESCRIPTION

Use the argument passed in as a "Google-style" set of keywords

=head1 METHODS

=cut

package RT::Search::Googleish;

use strict;
use warnings;
use base qw(RT::Search);

use Regexp::Common qw/delimited/;
my $re_delim = qr[$RE{delimited}{-delim=>qq{\'\"}}];

sub _Init {
    my $self = shift;
    my %args = @_;

    $self->{'Queues'} = delete( $args{'Queues'} ) || [];
    $self->SUPER::_Init(%args);
}

sub Describe {
    my $self = shift;
    return ( $self->loc( "No description for [_1]", ref $self ) );
}

sub QueryToSQL {
    my $self = shift;
    my $query = shift || $self->Argument;

    my @keywords = grep length, map { s/^\s+//; s/\s+$//; $_ }
        split /((?:fulltext:)?$re_delim|\s+)/o, $query;

    my ( @keyvalue_clauses, @status_clauses, @other_clauses );

    for my $keyword (@keywords) {
        my @clauses;
        if (   ( @clauses = $self->TranslateCustom($keyword) )
            || ( @clauses = $self->TranslateKeyValue($keyword) ) )
        {
            push @keyvalue_clauses, @clauses;
            next;
        } elsif ( @clauses = $self->TranslateStatus($keyword) ) {
            push @status_clauses, @clauses;
            next;
        }

        for my $action (qw/Number User Queue Owner Others/) {
            my $translate = 'Translate' . $action;
            if ( my @clauses = $self->$translate($keyword) ) {
                push @other_clauses, @clauses;
                next;
            }
        }
    }

    push @other_clauses, $self->ProcessExtraQueues;
    unless (@status_clauses) {
        push @status_clauses, $self->ProcessExtraStatus;
    }

    my @tql_clauses = join( " AND ", sort @keyvalue_clauses );    # Yes, AND!
    push @tql_clauses, join( " OR ", sort @status_clauses );
    push @tql_clauses, join( " OR ", sort @other_clauses );
    @tql_clauses = grep { $_ ? $_ = "( $_ )" : undef } @tql_clauses;
    return join " AND ", sort @tql_clauses;
}

sub Prepare {
    my $self = shift;
    my $tql  = $self->QueryToSQL( $self->Argument );

    $RT::Logger->debug($tql);

    $self->TicketsObj->FromSQL($tql);
    return (1);
}

sub TranslateKeyValue {
    my $self = shift;
    my $key  = shift;

    if ( $key
        =~ /(subject|cf\.(?:[^:]*?)|content|requestor|id|status|owner|queue|fulltext):(['"]?)(.+)\2/i
       )
    {
        my $field = $1;
        my $value = $3;
        $value =~ s/(['"])/\\$1/g;

        if ( $field =~ /id|status|owner|queue/i ) {
            return "$field = '$value'";
        } elsif ( $field =~ /fulltext/i ) {
            return "Content LIKE '$value'";
        } else {
            return "$field LIKE '$value'";
        }
    }
    return;
}

sub TranslateNumber {
    my $self = shift;
    my $key  = shift;

    if ( $key =~ /^\d+$/ ) {
        return ( "id = '$key'", "Subject LIKE '$key'" );
    }
    return;
}

sub TranslateStatus {
    my $self = shift;
    my $key  = shift;

    my $Queue = RT::Queue->new( $self->TicketsObj->CurrentUser );
    if ( $Queue->IsValidStatus($key) ) {
        return "Status = '$key'";
    }
    return;
}

sub TranslateQueue {
    my $self = shift;
    my $key  = shift;

    my $Queue = RT::Queue->new( $self->TicketsObj->CurrentUser );
    $Queue->Load($key);
    if ( $Queue->id ) {
        my $quoted_queue = $Queue->Name;
        $quoted_queue =~ s/'/\\'/g;
        return "Queue = '$quoted_queue'";
    }
    return;
}

sub TranslateUser {
    my $self = shift;
    my $key  = shift;

    if ( $key =~ /\w+\@\w+/ ) {
        $key =~ s/(['"])/\\$1/g;
        return "Requestor LIKE '$key'";
    }
    return;
}

sub TranslateOwner {
    my $self = shift;
    my $key  = shift;

    my $User = RT::User->new( $self->TicketsObj->CurrentUser );
    $User->Load($key);
    if ( $User->id && $User->Privileged ) {
        my $name = $User->Name;
        $name =~ s/(['"])/\\$1/g;
        return "Owner = '" . $name . "'";
    }
    return;
}

sub TranslateOthers {
    my $self = shift;
    my $key  = shift;

    $key =~ s{^(['"])(.*)\1$}{$2};    # 'foo' => foo
    $key =~ s/(['"])/\\$1/g;          # foo'bar => foo\'bar

    return "Subject LIKE '$key'";
}

sub ProcessExtraQueues {
    my $self = shift;
    my %args = @_;

    # restrict to any queues requested by the caller
    my @clauses;
    for my $queue ( @{ $self->{'Queues'} } ) {
        my $QueueObj = RT::Queue->new( $self->TicketsObj->CurrentUser );
        next unless $QueueObj->Load($queue);
        my $quoted_queue = $QueueObj->Name;
        $quoted_queue =~ s/'/\\'/g;
        push @clauses, "Queue = '$quoted_queue'";
    }
    return @clauses;
}

sub ProcessExtraStatus {
    my $self = shift;

    if (RT::Config->Get(
            'OnlySearchActiveTicketsInSimpleSearch',
            $self->TicketsObj->CurrentUser
        )
       )
    {
        return join( " OR ",
            map "Status = '$_'",
            RT::Queue->ActiveStatusArray() );
    }
    return;
}

sub TranslateCustom {
    my $self = shift;
    return;
}

RT::Base->_ImportOverlays();

1;
