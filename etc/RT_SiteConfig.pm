
Set( $rtname, 'example.com');
Set( $WebPort , 11235);
Set( $WebBaseURL , "http://localhost:$WebPort");

   $RTIR_CONFIG_FILE = $RT::LocalEtcPath."/IR/RTIR_Config.pm";

   require $RTIR_CONFIG_FILE
     || die ("Couldn't load RTIR config file '$RTIR_CONFIG_FILE'\n$@");

Set( %GnuPG,
    Enable => 1,
    OutgoingMessagesFormat => 'RFC', # Inline
);


Set(%GnuPGOptions, homedir => '/home/clkao/.gnupg');
Set(@MailPlugins, 'Auth::GnuPGNG');


1;

