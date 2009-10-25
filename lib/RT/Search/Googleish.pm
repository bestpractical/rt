
# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
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

# sub _Init {{{
sub _Init {
    my $self = shift;
    my %args = @_;

    $self->{'Queues'} = delete($args{'Queues'}) || [];
    $self->SUPER::_Init(%args);
}
# }}}

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return ($self->loc("No description for [_1]", ref $self));
}
# }}}

# {{{ sub QueryToSQL
sub QueryToSQL {
    my $self     = shift;
    my $query    = shift || $self->Argument;

    my @keywords = grep length, map { s/^\s+//; s/\s+$//; $_ }
      split /((?:fulltext:)?$re_delim|\s+)/o, $query;

    my (
        @keyvalue_clauses, @number_clauses, @status_clauses,
        @queue_clauses,    @user_clauses,   @owner_clauses,
        @others_clauses,   @tql_clauses
    );

    my %map = (
        KeyValue => \@keyvalue_clauses,
        Number   => \@number_clauses,
        Status   => \@status_clauses,
        Queue    => \@queue_clauses,
        User     => \@user_clauses,
        Owner    => \@owner_clauses,
        Others   => \@others_clauses
    );

  KEYWORD:
    for my $keyword (@keywords) {
        for my $action (qw/KeyValue Number User Status Queue Owner Others/) {
            my $translate = 'Translate' . $action;
            my $clause    = $map{$action};
            my @clauses   = $self->$translate($keyword);
            if (@clauses) {
                push @{$clause}, @clauses;
                next KEYWORD;
            }
        }
    }

    $self->ProcessAfterTranslate(
        key_value => \@keyvalue_clauses,
        number    => \@number_clauses,
        user      => \@user_clauses,
        status    => \@status_clauses,
        queue     => \@queue_clauses,
        owner     => \@owner_clauses,
        other     => \@others_clauses,
        final     => \@tql_clauses,
    );

    $self->CallbackAfterProcess(
        key_value => \@keyvalue_clauses,
        number    => \@number_clauses,
        user      => \@user_clauses,
        status    => \@status_clauses,
        queue     => \@queue_clauses,
        owner     => \@owner_clauses,
        other     => \@others_clauses,
        final     => \@tql_clauses,
    );

    push @tql_clauses, join( " AND ", sort @keyvalue_clauses );    # Yes, AND!

    push @tql_clauses, join( " OR ", sort @number_clauses );
    push @tql_clauses, join( " OR ", sort @owner_clauses );
    push @tql_clauses, join( " OR ", sort @user_clauses );
    push @tql_clauses, join( " OR ", sort @queue_clauses );
    push @tql_clauses, join( " OR ", sort @status_clauses );
    push @tql_clauses, join( " OR ", sort @others_clauses );
    @tql_clauses = grep { $_ ? $_ = "( $_ )" : undef } @tql_clauses;
    return join " AND ", sort @tql_clauses;
}

# }}}

# {{{ sub Prepare
sub Prepare {
    my $self = shift;
    my $tql  = $self->QueryToSQL( $self->Argument );

    $RT::Logger->debug($tql);

    $self->TicketsObj->FromSQL($tql);
    return (1);
}

# }}}

sub TranslateKeyValue {
    my $self = shift;
    my $key  = shift;
    my @clauses;
    if ( $key =~
/(subject|cf\.(?:[^:]*?)|content|requestor|id|status|owner|queue|fulltext):(['"]?)(.+)\2/i
      )
    {
        my $field = $1;
        my $value = $3;
        $value =~ s/(['"])/\\$1/g;

        if ( $field =~ /id|status|owner|queue/i ) {
            push @clauses, "$field = '$value'";
        }
        elsif ( $field =~ /fulltext/i ) {
            push @clauses, "Content LIKE '$value'";
        }
        else {
            push @clauses, "$field LIKE '$value'";
        }
    }
    return @clauses;
}

sub TranslateNumber {
    my $self = shift;
    my $key  = shift;
    my @clauses;
    if ( $key =~ /^\d+$/ ) {
        push @clauses, "id = '$key'", "Subject LIKE '$key'";
    }
    return @clauses;
}

sub TranslateStatus {
    my $self = shift;
    my $key  = shift;
    my @clauses;
    my $Queue = RT::Queue->new( $self->TicketsObj->CurrentUser );
    if ( $Queue->IsValidStatus($key) ) {
        push @clauses, "Status = '$key'";
    }
    return @clauses;
}

sub TranslateQueue {
    my $self = shift;
    my $key  = shift;
    my @clauses;
    my $Queue = RT::Queue->new( $self->TicketsObj->CurrentUser );
    my ( $ret ) = $Queue->Load($key);
    if ( $ret && $Queue->Id ) {
        my $quoted_queue = $Queue->Name;
        $quoted_queue =~ s/'/\\'/g;
        push @clauses, "Queue = '$quoted_queue'";
    }
    return @clauses;
}

sub TranslateUser {
    my $self = shift;
    my $key  = shift;
    my @clauses;
    if ( $key =~ /\w+\@\w+/ ) {
        $key =~ s/(['"])/\\$1/g;
        push @clauses, "Requestor LIKE '$key'";
    }
    return @clauses;
}

sub TranslateOwner {
    my $self = shift;
    my $key  = shift;
    my @clauses;
    my $User = RT::User->new( $self->TicketsObj->CurrentUser );
    my ( $ret ) = $User->Load($key);
    if ( $ret && $User->Privileged ) {
        my $name = $User->Name;
        $name =~ s/(['"])/\\$1/g;
        push @clauses, "Owner = '" . $name . "'";
    }
    return @clauses;
}

sub TranslateOthers {
    my $self = shift;
    my $key  = shift;
    my @clauses;
    $key =~ s{^(['"])(.*)\1$}{$2};    # 'foo' => foo
    $key =~ s/(['"])/\\$1/g;          # foo'bar => foo\'bar

    push @clauses, "Subject LIKE '$key'";
    return @clauses;
}

sub ProcessAfterTranslate {
    my $self           = shift;
    my %args           = @_;
    my $queue_clauses  = $args{queue};
    my $status_clauses = $args{status};

    # restrict to any queues requested by the caller
    for my $queue ( @{ $self->{'Queues'} } ) {
        my $QueueObj = RT::Queue->new( $self->TicketsObj->CurrentUser );
        my ( $ret ) = $QueueObj->Load($queue);
        next unless $ret;
        my $quoted_queue = $QueueObj->Name;
        $quoted_queue =~ s/'/\\'/g;
        push @$queue_clauses, "Queue = '$quoted_queue'";
    }

    if (
        !@$status_clauses
        && RT::Config->Get(
            'OnlySearchActiveTicketsInSimpleSearch',
            $self->TicketsObj->CurrentUser
        )
      )
    {
        push @$status_clauses,
          join( " OR ", map "Status = '$_'", RT::Queue->ActiveStatusArray() );
    }
}

sub CallbackAfterProcess {
    my $self = shift;

}

eval "require RT::Search::Googleish_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Search/Googleish_Vendor.pm});
eval "require RT::Search::Googleish_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Search/Googleish_Local.pm});

1;
