# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2024 Best Practical Solutions, LLC
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

use strict;
use warnings;

package RT::Record::Role::ObjectContent;
use Role::Basic;

=head1 NAME

RT::Record::Role::ObjectContent - Common methods for records having an ObjectContent record

=head1 PROVIDES

=head2 ContentObj

Returns corresponding L<RT::ObjectContent> object, undef if it does not exist.

=cut

sub ContentObj {
    my $self = shift;
    return undef unless $self->CurrentUserCanSee;
    my $record = RT::ObjectContent->new($self->CurrentUser);
    $record->LoadByCols( ObjectType => ref $self, ObjectId => $self->Id, Disabled => 0 );
    return $record->Id ? $record : undef;
}

=head2 Content

Returns corresponding L<RT::ObjectContent> object's content, undef if it doesn't exist.

=cut

sub Content {
    my $self = shift;
    # Call ContentObj($self) in case ContentObj is used for other purposes in target modules like RT::Transaction
    if ( my $object_content = ContentObj($self) ) {
        return $object_content->DecodedContent;
    }
    return undef;
}

=head2 SetContent CONTENT

Create/Update corresponding L<RT::ObjectContent> record.

Returns ($id, 'Success Message') or (0, 'Error message' ).

=cut

sub SetContent {
    my $self    = shift;
    my $content = shift;
    my %args = ( RecordTransaction => 1, @_ );

    my $object_content = ContentObj($self);

    if ( $self->isa('RT::Transaction') ) {
        # Not allow to update Content
        return ( 0, $self->loc('Permission Denied') ) if $object_content;
    }
    else {
        return ( 0, $self->loc('Permission Denied') ) unless $self->CurrentUserCanModify;
    }

    ( my $encoding, $content ) = RT::ObjectContent->_EncodeContent($content);

    my $old_content_id;

    if ($object_content) {
        $old_content_id = $object_content->Id;
        if ( $encoding eq $object_content->ContentEncoding && $content eq $object_content->__Value('Content') ) {
            return $old_content_id;
        }
    }

    RT->DatabaseHandle->BeginTransaction;
    if ($object_content) {
        my ( $ret, $msg ) = $object_content->Delete;
        if ( !$ret ) {
            RT->DatabaseHandle->Rollback;
            return ( $ret, $msg );
        }
    }

    $object_content = RT::ObjectContent->new( $self->CurrentUser );
    my ( $new_content_id, $msg ) = $object_content->Create(
        ObjectType      => ref $self,
        ObjectId        => $self->Id,
        ContentEncoding => $encoding,
        Content         => $content,
    );
    if ( !$new_content_id ) {
        RT->DatabaseHandle->Rollback;
        return ( $new_content_id, $msg );
    }

    if ( $args{'RecordTransaction'} ) {
        my ( $tid, $msg ) = $self->_NewTransaction(
            Type          => 'Set',
            Field         => 'Content',
            ReferenceType => 'RT::ObjectContent',
            NewReference  => $new_content_id,
            OldReference  => $old_content_id,
        );
        if ( !$tid ) {
            RT->DatabaseHandle->Rollback;
            return ( 0, $self->loc( "Couldn't create a transaction: [_1]", $msg ) );
        }
    }
    RT->DatabaseHandle->Commit;

    return ( $new_content_id, $self->loc("Content updated") );
}

1;
