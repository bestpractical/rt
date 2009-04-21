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
# http://www.gnu.org/copyleft/gpl.html.
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
use warnings;
use strict;
package RT::Model::Config;
use base qw/RT::Record/;

sub table {'Configs'}

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column namespace => max_length is 16, type is 'varchar(16)', default is '';
    column name   => max_length is 64, type is 'varchar(64)', default is '';
    column value => type is 'text',
        filters are qw( Jifty::DBI::Filter::Storable
                Jifty::DBI::Filter::base64 );
};

use Jifty::Plugin::ActorMetadata::Mixin::Model::ActorMetadata map => {
    created_by => 'creator',
    created_on => 'created',
    updated_by => 'last_updated_by',
    updated_on => 'last_updated',
};

sub _get {
    my $self = shift;
    my $name = shift;

    my $config = RT::Model::Config->new;
    my ( $ret, $msg ) = $config->load_by_cols( name => $name );
    if ($ret) {
        my $value = $config->value;
        return '' if defined $value && $value eq '[empty string]';
        return $value;
    }
    else {
        return;
    }
}

sub get {
    my $self = shift;
    my $name = shift;
    my $user = shift;

    # get user's preference if possible
    if ( $user && $user->id ) {
        $user = $user->user_object if $user->isa('RT::CurrentUser');
        my $prefs = $user->preferences( RT->system );
        if ( $prefs ) {
            my $value = $prefs->{$name};
            return $value if defined $value;
        }
    }

    my $value = $self->_get( $name );
    if ( defined $value ) {
        $value =~ s/{{(\w+)}}/$self->get($1) || ''/ge if $value && !ref $value;
        return $value;
    }
    else {
        return;
    }
}

sub set {
    my $self  = shift;
    my $name  = shift;
    my $value = shift;

    $value = $self->_empty_string if defined $value && $value eq '';
    my $config = RT::Model::Config->new( current_user => RT->system_user );
    my ( $ret, $msg ) = $config->load_by_cols( name => $name );
    if ($ret) {
        return $config->set_value( $value );
    }
    else {
        Jifty->log->info( "no $name exist yet, will create a new item" );
        return $config->create( name => $name, value => $value );
    }
}

sub create {
    my $self = shift;
    my %args = @_;
    $args{value} = $self->_empty_string
      if defined $args{value} && $args{value} eq '';
    return $self->SUPER::create(%args);
}

sub _empty_string {
    return '[empty string]';
}

1;

