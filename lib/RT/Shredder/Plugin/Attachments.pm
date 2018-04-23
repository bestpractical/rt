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

package RT::Shredder::Plugin::Attachments;

use strict;
use warnings FATAL => 'all';
use base qw(RT::Shredder::Plugin::Base::Search);

=head1 NAME

RT::Shredder::Plugin::Attachments - search plugin for wiping attachments.

=head1 ARGUMENTS

=head2 files_only - boolean value

Search only file attachments.

=head2 file - mask

Search files with specific file name only.

Example: '*.xl?' or '*.gif'

=head2 longer - attachment content size

Search attachments which content is longer than specified.
You can use trailing 'K' or 'M' character to specify size in
kilobytes or megabytes.

=cut

sub SupportArgs { return $_[0]->SUPER::SupportArgs, qw(files_only file longer) }

sub TestArgs
{
    my $self = shift;
    my %args = @_;
    my $queue;
    if( $args{'file'} ) {
        unless( $args{'file'} =~ /^[\w\. *?]+$/) {
            return( 0, "Files mask '$args{file}' has invalid characters" );
        }
        $args{'file'} = $self->ConvertMaskToSQL( $args{'file'} );
    }
    if( $args{'longer'} ) {
        unless( $args{'longer'} =~ /^\d+\s*[mk]?$/i ) {
            return( 0, "Invalid file size argument '$args{longer}'" );
        }
    }
    return $self->SUPER::TestArgs( %args );
}

sub Run
{
    my $self = shift;
    my @conditions = ();
    my @values = ();
    if( $self->{'opt'}{'file'} ) {
        my $mask = $self->{'opt'}{'file'};
        push @conditions, "( Filename LIKE ? )";
        push @values, $mask;
    }
    if( $self->{'opt'}{'files_only'} ) {
        push @conditions, "( LENGTH(Filename) > 0 )";
    }
    if( $self->{'opt'}{'longer'} ) {
        my $size = $self->{'opt'}{'longer'};
        $size =~ s/([mk])//i;
        $size *= 1024 if $1 && lc $1 eq 'k';
        $size *= 1024*1024 if $1 && lc $1 eq 'm';
        push @conditions, "( LENGTH(Content) > ? )";
        push @values, $size;
    }
    return (0, "At least one condition should be provided" ) unless @conditions;
    my $query = "SELECT id FROM Attachments WHERE ". join ' AND ', @conditions;
    if( $self->{'opt'}{'limit'} ) {
        $RT::Handle->ApplyLimits( \$query, $self->{'opt'}{'limit'} );
    }
    my $sth = $RT::Handle->SimpleQuery( $query, @values );
    return (0, "Internal error: '$sth'. Please send bug report.") unless $sth;

    my @objs;
    while( my $row = $sth->fetchrow_arrayref ) {
        push @objs, $row->[0];
    }
    return (0, "Internal error: '". $sth->err ."'. Please send bug report.") if $sth->err;

    @objs = map {"RT::Attachment-$_"} @objs;

    return (1, @objs);
}

1;

