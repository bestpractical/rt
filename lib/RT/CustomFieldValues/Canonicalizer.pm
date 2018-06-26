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

package RT::CustomFieldValues::Canonicalizer;

use strict;
use warnings;
use base 'RT::Base';

=head1 NAME

RT::CustomFieldValues::Canonicalizer - base class for custom field value
canonicalizers

=head1 SYNOPSIS

=head1 DESCRIPTION

This class is the base class for custom field value canonicalizers. To
implement a new canonicalizer, you must create a new class that subclasses
this class. Your subclass must implement the method L</CanonicalizeValue> as
documented below. You should also implement the method L</Description> which
is the label shown to users. Finally, add the new class name to
L<RT_Config/@CustomFieldValuesCanonicalizers>.

See L<RT::CustomFieldValues::Canonicalizer::Uppercase> for a complete
example.

=head2 new

The object constructor takes one argument: L<RT::CurrentUser> object.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless ($self, $class);
    $self->CurrentUser(@_);
    return $self;
}

=head2 CanonicalizeValue

Receives a parameter hash including C<CustomField> (an L<RT::CustomField>
object) and C<Content> (a string of user-provided content).

You may also access C<< $self->CurrentUser >> in case you need the user's
language or locale.

This method is expected to return the canonicalized C<Content>.

=cut

sub CanonicalizeValue {
    my $self = shift;
    die "Subclass " . ref($self) . " of " . __PACKAGE__ . " does not implement required method CanonicalizeValue";
}

=head2 Description

A class method that returns the human-friendly name for this canonicalizer
which appears in the admin UI. By default it is the class name, which is
not so human friendly. You should override this in your subclass.

=cut

sub Description {
    my $class = shift;
    return $class;
}

RT::Base->_ImportOverlays();

1;

