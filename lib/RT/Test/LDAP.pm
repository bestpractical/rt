# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

# Portions Copyright 2023-2025 Andrew Ruthven <andrew@etc.gen.nz>

package RT::Test::LDAP;

use strict;
use warnings;

use base 'RT::Test';

sub new {
    my $proto   = shift;
    my %options = @_;
    my $class = ref($proto) ? ref($proto) : $proto;
    my $self  = bless {
        base_dn => $options{base_dn} || 'dc=bestpractical,dc=com',
    }, $class;

    # Set a base default. Some tests will add or override portions of this
    # hash.
    $self->{'externalauth'} = {
        'My_LDAP' => {
            'type'            => 'ldap',
            'base'            => $self->{'base_dn'},
            'filter'          => '(objectClass=*)',
            'd_filter'        => '()',
            'tls'             => 0,
            'net_ldap_args'   => [ version => 3 ],
            'attr_match_list' => [ 'Name', 'EmailAddress' ],
            'attr_map'        => {
                'Name'         => 'uid',
                'EmailAddress' => 'mail',
                'RealName'     => 'cn',
                'Gecos'        => 'uid',
                'NickName'     => 'nick',
            },
        },
    };

    return $self;
}

sub import {
    my $class = shift;
    my %args  = @_;

    eval {
        require RT::LDAPImport;
        require RT::Authen::ExternalAuth;
        require Net::LDAP::Server::Test;
        1;
    } or do {
        RT::Test::plan(
            skip_all => 'Unable to test without Net::LDAP and Net::LDAP::Server::Test'
        );
    };

    RT::Test::plan( tests => $args{'tests'} ) if $args{tests};

    delete $args{tests};
    $class->SUPER::import(%args);
    __PACKAGE__->export_to_level(1);
}

sub new_server {
    my $self = shift;

    $self->{'ldap_port'}   = RT::Test->find_idle_port;

    $self->{'ldap_server'} = Net::LDAP::Server::Test->new(
        $self->{'ldap_port'}, auto_schema => 1
    ) || die "Failed to spawn test LDAP server on port " . $self->{'ldap_port'};

    my $ldap_client
        = Net::LDAP->new('localhost:' . $self->{'ldap_port'})
        || die "Failed to connect to LDAP server: $@";

    $ldap_client->bind();
    $ldap_client->add($self->{'base_dn'});

    return $ldap_client;
}

sub config_set_externalauth {
    my $self     = shift;
    my $settings = shift;

    $settings->{'ExternalAuthPriority'}       //= ['My_LDAP'];
    $settings->{'ExternalInfoPriority'}       //= ['My_LDAP'];
    $settings->{'AutoCreateNonExternalUsers'} //= 0;
    $settings->{'AutoCreate'} //= undef;

    while (my ($key, $val) = each %{$settings}) {
        RT->Config->Set($key, $val);
    }

    $self->{'externalauth'}{'My_LDAP'}{'server'} //=
        'localhost:' . $self->{'ldap_port'};

    RT->Config->Set(ExternalSettings => $self->{'externalauth'});
    RT->Config->PostLoadCheck;
}

sub config_set_ldapimport {
    my $self     = shift;
    my $settings = shift;

    $settings->{'LDAPHost'}
        //= 'ldap://localhost:' . $self->{'ldap_port'};
    $settings->{'LDAPMapping'} //= {
        Name         => 'uid',
        EmailAddress => 'mail',
        RealName     => 'cn',
    };
    $settings->{'LDAPBase'}   //= $self->{'base_dn'};
    $settings->{'LDAPFilter'} //= '(objectClass=User)';
    $settings->{'LDAPSkipAutogeneratedGroup'} //= 1;

    while (my ($key, $val) = each %{$settings}) {
        RT->Config->Set($key, $val);
    }
}

sub config_set_ldapimport_group {
    my $self     = shift;
    my $settings = shift;

    $settings->{'LDAPGroupBase'}   //= $self->{'base_dn'};
    $settings->{'LDAPGroupFilter'} //= '(objectClass=Group)';

    while (my ($key, $val) = each %{$settings}) {
        RT->Config->Set($key, $val);
    }
}

1;
