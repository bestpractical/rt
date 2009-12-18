# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
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

package RT::View::Admin::Tools;
use Jifty::View::Declare -base;

template 'index.html' => page { title => _('System Tools') } content {
    my $items = {
        A => {
            title => _('System Configuration'),
            text  => _('View system configuration'),
            path  => '/admin/tools/configuration',
        },
        B => {
            title => _('Shredder'),
            text  => _('Shredder plugin'),
            path  => '/admin/tools/shredder',
        },
    };

    ul {
        attr { class => 'list-menu' };
        foreach my $key ( sort keys %$items ) {
            li {
                span {
                    attr { class => 'menu-item' };
                    a {
                        attr { href => RT->config->get('web_path')
                              . $items->{$key}->{'path'} };
                        $items->{$key}->{'title'};
                    }
                }
                span {
                    attr { class => 'description' }
                      $items->{$key}->{text}
                }

            }
        }
    };
}

template 'configuration' => page { title => _('System Configuration') }
  content {
    h2 { _('loaded perl modules') };
    require Module::Versions::Report;
    my $report = Module::Versions::Report::report();
    my @report = grep /v\d/, split( "\n", $report );
    pre {
        for (@report) {
            outs($_);
            br {};
        }
    };

    h2 { _('RT Config') };
    table {
        my $configs = RT::Model::ConfigCollection->new;
        $configs->unlimit;
        while ( my $config = $configs->next ) {
            my $val = $config->value;
            next unless defined $val;
            $val = '' if defined $val && $val eq $config->_empty_string;
            row {
                cell { $config->name };
                cell {
                    if ( !ref $val ) {
                        outs($val);
                    }
                    elsif ( ref $val eq 'ARRAY' ) {
                        outs( join ', ', @$val );
                    }
                    elsif ( ref $val eq 'HASH' ) {
                        outs( join ', ', %$val );
                    }
                    else {
                        outs( ref $val );
                    }
                    '';
                }
            };
        }
    };

    h2 { _('RT Variables') };
    table {
        no strict qw/refs/;
        for my $key ( sort keys %{*RT::} ) {
            next if !${'RT::'.$key} || ref ${'RT::'.$key};
            row {
                cell { 'RT::' . $key };
                cell { ${ 'RT::' . $key } };
            };
        }
    }
    
    h2 { _('Perl configuation') };
    require Config;
    pre {
        Config::myconfig();
    };

    h2 { _('Perl Include Paths (@INC)') };
    pre {
        for my $inc (@INC) {
            outs($inc);
            br {};
        }
    };
};

1;

