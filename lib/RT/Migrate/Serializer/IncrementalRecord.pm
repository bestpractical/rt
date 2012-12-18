package RT::Migrate::Serializer::IncrementalRecord;
use base qw/RT::Record/;

use strict;
use warnings;

sub Table {'IncrementalRecords'}

sub _CoreAccessible {
    return {
        id         => { read => 1 },
        ObjectType => { read => 1 },
        ObjectId   => { read => 1 },
        UpdateType => { read => 1 },
        AlteredAt  => { read => 1 },
    };
};

1;

__END__

CREATE TABLE IncrementalRecords (
  id         INTEGER NOT NULL AUTO_INCREMENT,
  ObjectType VARCHAR(50) NOT NULL,
  ObjectId   INTEGER NOT NULL,
  UpdateType TINYINT NOT NULL,
  AlteredAt  TIMESTAMP NOT NULL,
  PRIMARY KEY(ObjectType, ObjectId),
  UNIQUE KEY(id),
  KEY(UpdateType)
);
