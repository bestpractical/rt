no warnings qw/redefine/;


=item Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(255) 'Value'.
  varchar(255) 'Summary'.
  int(11) 'Parent'.
  varchar(255) 'Filename'.
  varchar(80) 'ContentType'.
  varchar(80) 'ContentEncoding'.
  varchar(160) 'MessageId'.
  longblob 'Headers'.
  longblob 'Body'.
  int(11) 'Creator'.

=begin testing

use_ok(RT::FM::Content);

my $c = RT::FM::Content->new($RT::SystemUser);
my ($id, $msg) = $c->Create(Summary => 'Blah');
ok ($id, $msg);
$c = RT::FM::Content->new($RT::SystemUser);
my $foo = 'Blah';
($id, $msg) = $c->Create(Summary => $foo);
ok ($id, $msg);

$c = RT::FM::Content->new($RT::SystemUser);
 $foo = 'test2';
($id, $msg) = $c->Create(Summary => $foo);
ok ($id, $msg);

=end testing 

=cut



1;
