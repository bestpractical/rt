use strict;
use warnings;

my $gnupg;
my @gnupg_versions;
my $homedir;
BEGIN {
    require RT::Test;
    require GnuPG::Interface;
    
    $gnupg = GnuPG::Interface->new;
    @gnupg_versions = split /\./, $gnupg->version;

    if ($gnupg_versions[0] < 2) {
        $homedir =
            RT::Test::get_abs_relocatable_dir( File::Spec->updir(),
                                               qw/data gnupg keyrings/ );
    } else {
        $homedir =
            RT::Test::get_abs_relocatable_dir( File::Spec->updir(),
                                               qw/data gnupg2 keyrings/ );
        $ENV{'GNUPGHOME'} = $homedir;
        system('gpgconf', '--quiet', '--kill', 'gpg-agent');
    }
}

END {
    if ($gnupg_versions[0] >= 2 && $gnupg_versions[1] >= 1) {
        system('gpgconf', '--quiet', '--kill', 'gpg-agent');
        delete $ENV{'GNUPGHOME'};
    }
}

use RT::Test::GnuPG
  tests          => undef,
  text_templates => 1,
  gnupg_options  => {
    passphrase    => 'rt-test',
    'trust-model' => 'always',
    homedir       => $homedir,
  };

RT::Test->import_gnupg_key('rt-recipient@example.com');
RT::Test->import_gnupg_key( 'rt-test@example.com' );

my $queue = RT::Test->load_or_create_queue(
    Name              => 'Regression',
    CorrespondAddress => 'rt-recipient@example.com',
    CommentAddress    => 'rt-recipient@example.com',
    Sign              => 1,
);
ok $queue && $queue->id, 'loaded or created queue';

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in';

create_and_test_outgoing_emails( $queue, $m );

done_testing;
