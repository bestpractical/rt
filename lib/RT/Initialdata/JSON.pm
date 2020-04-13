# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2020 Best Practical Solutions, LLC
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

RT::Initialdata::JSON - Support for JSON-format initialdata files

=head1 DESCRIPTION

RT supports pluggable parsers for initialdata in different source
formats. This module supports JSON.

Perl-based initialdata files can contain not just data, but also
perl code that executes when they are processed. The JSON format
is purely for data serialization and does not support code sections.

Files used with this handler must be UTF-8 encoded text containing a valid
JSON structure. See http://json.org for JSON syntax specifications.

=cut

package RT::Initialdata::JSON;

use strict;
use warnings;

use JSON;

=head2 C<CanLoad($json)>

This is called by base RT to determine if an initialdata file is whatever type
is associated with this module. It must return true or false. Takes one arg,
the content of the file to check.

=cut

sub CanLoad {
    my $self = shift;
    my $json = shift;
    return 0 unless $json;

    my $parsed;
    eval { $parsed = JSON->new->decode($json) };
    return 0 if ($@);
    return 1;
}


=head2 C<Load($data, \@Var, ...)>

This is the main routine called when initialdata file handlers are enabled. It
is passed the file contents and refs to the arrays that will be populated from
the file. If the file parsing fails, due to invalid JSON (generally indicating
that the file is actually a perl initialdata file), the sub will return false.

=cut

sub Load {
    my ($self, $json, $vars) = @_;
    return 0 unless $json;

    my $parsed;
    eval { $parsed = JSON->new->decode($json) };
    if ($@) {
        RT::Logger->debug("Could not parse initialdata as JSON: ($@)");
        return 0;
    }

    RT::Logger->info("JSON initialdata has unsupported 'Initial' or 'Final'; ignoring.")
        if ($parsed->{Initial} or $parsed->{Final});

    foreach (keys %$vars) {
        # Explicitly skip Initial and Final, because we don't want any code or
        # data that will be eval'd like these keys will be.
        next if /Initial/ or /Final/;
        next unless $parsed->{$_};
        die "JSON initialdata error: The key named $_ must have a value of type array, but does not."
            unless ref $parsed->{$_} eq 'ARRAY';
        no strict 'refs';
        @{$vars->{$_}} =  @{$parsed->{$_}};
    }

    return 1;
}


RT::Base->_ImportOverlays();

1;
