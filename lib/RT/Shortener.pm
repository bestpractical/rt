# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2021 Best Practical Solutions, LLC
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

=head1 NAME

RT::Shortener - RT Shortener object

=head1 SYNOPSIS

  use RT::Shortener;

=head1 DESCRIPTION

Object to operate on a single RT Shortener record.

=head1 METHODS

=cut


package RT::Shortener;

use strict;
use warnings;

use base 'RT::Record';

sub Table {'Shorteners'}

use Digest::SHA 'sha1_hex';
use URI;
use URI::QueryParam;
use RT::Interface::Web;

=head2 Create { PARAMHASH }

=cut

sub Create {
    my $self = shift;
    my %args = (
        Content => undef,
        @_,
    );

    unless ( $args{'Content'} ) {
        return ( 0, $self->loc("Must specify 'Content' attribute") );
    }

    $args{Code} ||= substr sha1_hex( $args{Content} ), 0, 10;

    return $self->SUPER::Create(%args);
}

sub LoadOrCreate {
    my $self = shift;
    my %args = (
        Content   => undef,
        Permanent => 0,
        @_,
    );

    if ( $args{Content} ) {
        my $sha1 = sha1_hex( $args{Content} );
        my $code;

        # In case there is a conflict, which should be quite rare.
        for my $length ( 8 .. 40 ) {
            $code = substr $sha1, 0, $length;
            $self->LoadByCode($code);
            if ( $self->Id ) {
                if ( $self->Content eq $args{Content} ) {
                    if ( $args{Permanent} && !$self->Permanent ) {
                        my ( $ret, $msg ) = $self->SetPermanent( $args{Permanent} );
                        unless ($ret) {
                            RT->Logger->error( "Could not set shortener #" . $self->Id . " to permanent: $msg" );
                        }
                    }
                    return $self->Id;
                }
            }
            else {
                last;
            }
        }

        return $self->Create( Code => $code, Content => $args{Content}, Permanent => $args{Permanent} );
    }
    else {
        return ( 0, $self->loc("Must specify 'Content' attribute") );
    }
}

sub LoadByCode {
    my $self = shift;
    my $code  = shift;
    return $self->LoadByCols( Code => $code );
}

sub DecodedContent {
    my $self    = shift;
    my $content = shift || $self->Content;
    my $uri     = URI->new;
    $uri->query($content);

    my $query = $uri->query_form_hash;
    RT::Interface::Web::DecodeARGS($query);
    return $query;
}

=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 Code

Returns the current value of Code.
(In the database, Code is stored as varchar(64).)

=cut

=head2 Content

Returns the current value of Content.
(In the database, Content is stored as blob.)

=head2 Permanent

Returns the current value of Permanent.
(In the database, Permanent is stored as smallint(6).)

=head2 Creator

Returns the current value of Creator.
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created.
(In the database, Created is stored as datetime.)


=cut

=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy.
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated.
(In the database, LastUpdated is stored as datetime.)

=cut

=head2 LastAccessedBy

Returns the current value of LastAccessedBy.
(In the database, LastAccessedBy is stored as int(11).)


=cut

=head2 LastAccessedByObj

  Returns an RT::User object of the last user to access this object

=cut

sub LastAccessedByObj {
    my $self = shift;
    unless ( exists $self->{LastAccessedByObj} ) {
        $self->{'LastAccessedByObj'} = RT::User->new( $self->CurrentUser );
        $self->{'LastAccessedByObj'}->Load( $self->LastAccessedBy );
    }
    return $self->{'LastAccessedByObj'};
}


=head2 LastAccessed

Returns the current value of LastAccessed.
(In the database, LastAccessed is stored as datetime.)

=cut

=head2 LastAccessedObj

Returns an RT::Date object of the current value of LastAccessed.

=cut

sub LastAccessedObj {
    my $self = shift;
    my $obj  = RT::Date->new( $self->CurrentUser );

    $obj->Set( Format => 'sql', Value => $self->LastAccessed );
    return $obj;
}

=head2 LastAccessedAsString

Returns the localized string of C<LastAccessedObj> with current user's
preferred format and timezone.

=cut

sub LastAccessedAsString {
    my $self = shift;
    if ( $self->LastAccessed ) {
        return ( $self->LastAccessedObj->AsString() );
    } else {
        return "never";
    }
}

=head2 _SetLastAccessed

This routine updates the LastAccessed and LastAccessedBy columns of the row in question
It takes no options.

=cut

sub _SetLastAccessed {
    my $self = shift;
    my $now  = RT::Date->new( $self->CurrentUser );
    $now->SetToNow();

    my ( $ret, $msg );
    if ( $self->LastAccessed ne $now->ISO ) {
        ( $ret, $msg ) = $self->__Set(
            Field => 'LastAccessed',
            Value => $now->ISO,
        );
        if ( !$ret ) {
            RT->Logger->error( "Couldn't set LastAccessed for " . $self->Id . ": $msg" );
        }
    }

    if ( $self->LastAccessedBy != $self->CurrentUser->id ) {
        ( $ret, $msg ) = $self->__Set(
            Field => 'LastAccessedBy',
            Value => $self->CurrentUser->id,
        );
        if ( !$ret ) {
            RT->Logger->error( "Couldn't set LastAccessedBy for " . $self->Id . ": $msg" );
        }
    }

    return wantarray ? ( $ret, $msg ) : $ret;
}


sub _CoreAccessible {
    {
        id =>
            {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Code =>
            {read => 1, write => 1, sql_type => 12, length => 64,  is_blob => 0,  is_numeric => 0,  type => 'varchar(40)', default => ''},
        Content =>
            {read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'longtext', default => ''},
        Permanent =>
            {read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '1'},
        Creator =>
            {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created =>
            {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy =>
            {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated =>
            {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastAccessedBy =>
            {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastAccessed =>
            {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
    }
};

RT::Base->_ImportOverlays();


1;
