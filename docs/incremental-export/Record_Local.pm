use strict;
use warnings;

package RT::Record;
no warnings 'redefine';

my ($update, $create, $delete);
BEGIN {
    $update = RT::Record->can("__Set");
    $create = RT::Record->can("Create");
    $delete = RT::Record->can("Delete");
}


sub __Set {
    my $self = shift;
    my %args = @_;
    my $ret = $update->($self, @_);

    my $class = ref($self);
    return ( $ret->return_value ) unless $RT::IncrementalExport;
    return ( $ret->return_value ) unless $ret;
    return ( $ret->return_value ) if $class eq "RT::CachedGroupMember";

    $self->_Handle->SimpleQuery( <<EOQ, $class, $self->__Value("Id") );
INSERT INTO IncrementalRecords (ObjectType, ObjectId, UpdateType, AlteredAt)
                  VALUES (?, ?, 1, NOW())
       ON DUPLICATE KEY UPDATE
          AlteredAt = AlteredAt
EOQ

    return ( $ret->return_value );
}


sub Create {
    my $self = shift;
    my ($id, $msg) = $create->($self, @_);

    if ($RT::IncrementalExport and $id and ref($self) ne "RT::CachedGroupMember") {
        $self->_Handle->SimpleQuery( <<EOQ, ref($self), $id );
INSERT INTO IncrementalRecords (ObjectType, ObjectId, UpdateType, AlteredAt)
                  VALUES (?, ?, 2, NOW())
EOQ
    }

    if (wantarray) {
        return ( $id, $msg );
    } else {
        return ( $id );
    }
}

sub Delete {
    my $self = shift;
    my ($ok, $msg) = $delete->($self,@_);

    if ($RT::IncrementalExport and $ok and ref($self) ne "RT::CachedGroupMember") {
        $self->_Handle->SimpleQuery( <<EOQ, ref($self), $self->__Value("Id") );
INSERT INTO IncrementalRecords (ObjectType, ObjectId, UpdateType, AlteredAt)
                  VALUES (?, ?, 3, NOW())
       ON DUPLICATE KEY UPDATE
          UpdateType = UpdateType + 2
EOQ
    }

    if (wantarray) {
        return ( $ok, $msg );
    } else {
        return ( $ok );
    }
}

1;
