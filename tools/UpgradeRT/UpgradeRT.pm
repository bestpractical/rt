package DBIx::Copy::UpgradeRT;

use strict;
use vars qw($VERSION @ISA);
use DBIx::Copy 0.03;

@ISA = qw(DBIx::Copy);
$VERSION = '0.02';

sub new {
    my $object_or_class = shift; my $class = ref($object_or_class) || $object_or_class;
    my ($rt10, $rt11, $dir, $options)=@_;
    $options->{table_translation_table}={
	'queues' => 'Queues',
	'queue_acl' => 'QueueACL',
	'users' => 'Users',
	'each_req' => 'Tickets',
	'transactions' => 'Transactions'
	};
    $options->{column_translation_table}->{queues}={
	'queue_id' => 'QueueID',
	'mail_alias' => 'CorrespondAddress',
	'm_owner_trans' => 'MailOwnerOnTransaction',
	'm_members_trans' => 'MailMembersOnTransaction',
	'm_members_corresp' => 'MailMembersOnCorrespondence',
	'm_members_comment' => 'MailMembersOnComment',
	'm_user_trans' => 'MailRequestorOnTransaction',
	'm_user_create' => 'MailRequestorOnCreation',
	'allow_user_create' => 'PermitNonmemberCreate',
	'default_prio' => 'InitialPriority',
	'default_final_prio' => 'FinalPriority',
	'default_due_in' => 'DefaultDueIn'
	};
    $options->{column_translation_table}->{each_req}={
	# TODO: Actors table!
	'serial_num' => 'id',
	'effective_sn' => 'EffectiveId',
	'alias' => 'Alias',
	'requestors' => 'Requestors',
	'subject' => 'Subject',
	'initial_priority' => 'FinalPriority',
	'priority' => 'Priority',
	'status' => 'Status',
	'time_worked' => 'TimeWorked',
	'date_created' => 'Created',
	'date_told' => 'Told',
	'date_acted' => 'LastUpdated',
	'date_due' => 'Due'
	};
    $options->{column_translation_table}->{users}={
	'user_id' => 'UserId',
	'real_name' => 'RealName',
	'password' => 'Password',
	'email' => 'EmailAddress',
	'phone' => 'Phone',
	'office' => 'Office',
	'comments' => 'Comments',
	'admin_rt' => 'IsAdministrator'
	};
    $options->{column_translation_table}->{transactions}={
	'effective_sn'=>'EffectiveTicket',
	'serial_num'=>'Ticket',
	'type'=>'Type',
	'trans_data'=>'Data',
	'trans_date'=>'Created'
	};
    $options->{_transaction_dir}=$dir;

    # Todo: templates

    my $self=$object_or_class->SUPER::new($rt10, $rt11, $options);
    return $self;
} 

sub copy {
    my $self=shift;
    $self->SUPER::copy([qw/queues users queue_acl each_req transactions/]);
}

sub copy_transactions {
    my $self=shift;
    my $dir=$self->{opts}->{'_transaction_dir'};
    my $insert_attachment=$self->{dst}->prepare
	(
	 "insert into Attachments 
                      (TransactionId, MessageId, Subject, ContentType, Content, Headers) 
               values (?, ?, ?, 'text/plain', ?, ?)");
    for my $ydir (<$dir/*>) {
	for my $mdir (<$ydir/*>) {
	    for my $ddir (<$mdir/*>) {
		for my $file (<$ddir/*>) {
		    $file =~ m|/(\d+)\.(\d+)$|;
		    my $transaction_id=$2;
		    open (TRANS, "<$file");
		    undef $/;
		    my $headers=<TRANS>;
		    my $message=undef;
		    while ($headers =~ /\n--- Headers Follow ---\n/s) {
			$message.=$`;
			$headers=$';
		    }
		    $headers =~ s/^(\s*)//s;
		    $headers =~ s/^\>//s;
		    $headers =~ m|^Message-Id: (.*)$|im;
		    my $message_id=$1;
		    $headers =~ m|^Subject: (.*)$|im;
		    my $subject=$1;
		    $insert_attachment->execute($transaction_id, $message_id, $subject, $message ? $message : $headers, $message ? $headers : undef);
		}
	    }
	}
    }
}

sub construct_insert_statement {
    my $self=shift;
    my $table=shift;
    my $dest=shift;
    my $row=shift;
    if ($table eq 'queues') {
	my $statement=$self->SUPER::construct_insert_statement($table, $dest, $row);
	$statement =~ s{\(}{\(CommentAddress,}m;
	$statement =~ s{values \(}{values \(?,};
	return $statement;
    } elsif ($table eq 'transactions') {
	my $statement=$self->SUPER::construct_insert_statement($table, $dest, $row);
	$statement =~ s|\) values \(|, Creator) select |;
	$statement =~ s|\)$|, Users.id 
	             from Users 
		     where Users.UserId=?|;
        return $statement;
    } elsif ($table eq 'each_req') {
	my $statement=$self->SUPER::construct_insert_statement($table, $dest, $row);
	$statement =~ s|\) values \(|,Queue, Owner) select |;
	$statement =~ s|\)$|, Queues.id, Users.id 
	             from Queues, Users 
		     where Queues.QueueId=? and Users.UserId=?|;
        return $statement;
    } else {
	return $self->SUPER::construct_insert_statement($table, $dest, $row);
    }
}

sub get_insert_row_sub {
    my $self=shift;
    my $table=shift;
    if ($table eq 'queues') {
	my $cnt=0;
	for (keys %{$self->{opts}->{column_translation_table}->{$table}}) {
	    last if /^mail_alias$/;
	    $cnt++;
	}
	# Closure - $cnt will be stored in the sub below if I'm not mistaken.
	return sub { 
	    my ($self, $row, $insert_sth)=@_; 
	    $insert_sth->execute($row->[$cnt].'-comment', @$row);
	    $insert_sth->finish;
	};
    } elsif ($table eq 'queue_acl') {
	# Closure - $insert_subscribtion and $insert_acl will be
	# stored in the sub below if I'm not mistaken.
	my $insert_acl=$self->{dst}->prepare("insert into QueueACL (Queue, User, Right) select Queues.id, Users.id, ? from Queues, Users where Queues.QueueId=? and Users.UserId=?");

	# TODO
#	my $insert_subscription=$self->{dst}->prepare("insert into Subscriptions (Scope, Value, 

	return sub {
	    my $self=shift;
	    my $row=shift;
	    my $insert_sth=shift; # We're not going to use this one anyway 

	    my $c=$#$row;
	    
	    # mail
	    if ($row->[$c--]) {
		# $insert_subscription->execute(
	    }

	    # admin 
	    if ($row->[$c--]) {
		$insert_acl->execute("Admin", @$row[0..1]);
		$insert_acl->finish;
	    }

	    # manipulate / Write
	    if ($row->[$c--]) {
		$insert_acl->execute("Write", @$row[0..1]);
		$insert_acl->finish;
	    }

	    # display / Read
	    if ($row->[$c--]) {
		$insert_acl->execute("Read", @$row[0..1]);
		$insert_acl->finish;
	    }
	};

    } else {
	return $self->SUPER::get_insert_row_sub() ;
    }
}

sub construct_select_statement {
    my $self=shift;
    my ($table)=@_;
    if ($table eq 'queue_acl') {
	return "select queue_id, user_id, display, manipulate, admin, mail from queue_acl";
    } elsif ($table eq 'each_req') {
	my $statement=$self->SUPER::construct_select_statement(@_);
	$statement =~ s| from |, queue_id, owner from |;
	return $statement;
    } elsif ($table eq 'transactions') {
	my $statement=$self->SUPER::construct_select_statement(@_);
	$statement =~ s| from |, actor from |;
	return $statement;
    } else {
	return $self->SUPER::construct_select_statement(@_);
    }
}



1;


__END__


=head1 NAME

DBIx::Copy::UpgradeRT - For importing requests from RT 1.0 into RT 1.1

=head1 SYNOPSIS

use DBIx::Copy::UpgradeRT;

my $rt10 = DBI->connect
    ('dbi:mysql:database=rt;host=localhost', 
     'rt',
     'rtpasshere', 
     {RaiseError=>1, PrintError=>1});

my $rt11 = DBI->connect
    ('dbi:mysql:database=RT;host=localhost', 
     'rt',
     'rtpasshere', 
     {RaiseError=>1, PrintError=>1});

my $cpy=DBIx::Copy::UpgradeRT->new($rt10, $rt11, "/path/to/transactions);

$cpy->copy;

=head1 DESCRIPTION

Copies the content of an RT 1.0 database (with transaction content
stored in files) to RT 1.1. 

RT is written by Jesse Vincent and can be found at
http://www.fsck.com/projects/rt/

This is also a good example of how to utilize my DBIx::Copy package.

I'm assuming that the comment alias = mail_alias . "-comment" ... if
this is wrong, edit the get_insert_row_sub.  I guess the same thing
could be achievable only by modifying the insert statement and using
the SQL function concat ... but I'm not sure of compatibility, and I
wanted to test out if this concept of using a code reference worked
out at all.

=head1 TODO

Search for "todo" in the code and fix those things.

Smart mirroring; changes done in the 1.0 base should be inserted into
1.1

Reverse copy; it should be easy to revert to 1.0, taking in all data
from 1.1

=head1 AUTHOR

Tobias Brox <tobix@irctos.org>

=cut
