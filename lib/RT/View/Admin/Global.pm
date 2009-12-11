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

package RT::View::Admin::Global;
use Jifty::View::Declare -base;

template 'system' => page { title => _('Configure RT') } content {
    my $self    = shift;
    my $section = get('section');
    my $config  = new_action(
        class   => 'ConfigSystem',
        moniker => 'config_system',
    );
    $config->order(1);
    my $restart = new_action(
        class   => 'Jifty::Plugin::Config::Action::Restart',
        moniker => 'restart',
    );
    $restart->order(2);
    my $args = $config->arguments_by_sections;
    my $meta = $config->meta;

    if ($section) {
        with( name => 'config_system' ), form {
            for my $field ( sort keys %{ $args->{$section} } ) {
                div {
                    attr { class => 'hints' };
                    outs_raw($meta->{$field} && $meta->{$field}{doc});
                };
                outs_raw( $config->form_field($field) );
            }
            form_submit( label => _('Save') );
            form_submit(
                label  => _('Save and Restart RT'),
                submit => [
                    $config,
                    { action => $restart, arguments => { url => '/' } },
                ],
            );
        };
    }
    else {
        my $items      = {};
        my $sort_order = 'A';    # sort order begins with 'A'
        for my $section ( sort keys %$args ) {
            $items->{ $sort_order++ } = {
                title => _($section),
                path  => "/admin/global/system?section=$section"
            };
        }
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
                          $items->{$key}->{description}
                          || $items->{$key}->{text}
                          || '';
                    }

                }
            }
        };
    }
}

1;

