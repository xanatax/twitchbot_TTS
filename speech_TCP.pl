#!perl

use warnings;
use strict;

use POE qw(  Component::Server::TCP  Wheel::Run  );

my $say_prog = '/usr/bin/say';


POE::Component::Server::TCP->new(
	Port => 12345,
		ClientConnected => sub {
		print "got a connection from $_[HEAP]{remote_ip}\n";
		$_[HEAP]{client}->put("Smile from the server!");
	},
	ClientInput => sub {
		my $client_input = $_[ARG0];
		$_[KERNEL]->yield(  'mac_say', $client_input  );
	},
	PackageStates => [
		main => [ qw( 
			got_child_stdout  got_child_stderr  got_child_close  got_child_signal 
			mac_say
		) ],
	],
);


print 'Server running on port 12345', $/;
print $/;
print '... on a Mac or Linux, you can connect from this computer with:', $/;
print '> nc locahost 12345', $/;
print "\t", '--or--', $/; 
print '> nc 127.0.0.1 12345', $/;
print "\t", '--or--', $/; 
print '> telnet 127.0.0.1 12345', $/;
print "\t", '[ but *really* you want "nc"!   "telnet" is so unnescessary ]', $/;
print "\t", '[ ...not even kidding, this test is so simple a full telnet client is overkill! ]', $/;

print $/;
print 'from any computer on the local network by replacing "localhost" with this computer\'s local IP address', $/;
print $/;
print 'windows users can use "telnet 127.0.0.1 12345" on the command line', $/;
print 'or download "putty.exe" and open a "telnet" connection to port 12345', $/;
print $/;
print $/;

POE::Kernel->run;
exit;



### -----------

### -----------------------------------------------------
### -----------------------------------------------------
### -----------------------------------------------------
#	
#	this block, handle child-processes, copied from :
#	http://search.cpan.org/dist/POE/lib/POE/Wheel/Run.pm#SYNOPSIS
#
#		4 subroutines, to handle what happens when the child:
#			outputs something
#			warns us about an error / prints debug info
#			closes all data pipes
#			is dead  (e.g. finished normally)  :)
#			
#
### ----------------------------
#
#	shows us standard text output from the text-to-speech program
#		( the 'say' program on Mac is *really* boring. )
# 

sub got_child_stdout {
	my(  $stdout_line, $wheel_id  ) = @_[ARG0, ARG1];
	my $child = $_[HEAP]{children_by_wid}{$wheel_id};

	print "pid ", $child->PID, " STDOUT: $stdout_line\n";
}



### ----------------------------
#
#	this shows us any debug output from the text-to-speech program
#

sub got_child_stderr {
	my(  $stderr_line, $wheel_id  ) = @_[ARG0, ARG1];
	my $child = $_[HEAP]{children_by_wid}{$wheel_id};

	print "pid ", $child->PID, " STDERR: $stderr_line\n";
}



### ----------------------------
#
#	make sure the cleanup gets started
#

sub got_child_close {
	my $wheel_id = $_[ARG0];
	my $child = delete $_[HEAP]{children_by_wid}{$wheel_id};

	# May have been reaped by on_child_signal().
	unless(  defined $child  ){
		print "wid $wheel_id closed all pipes.\n";
		return;
	}

	print "pid ", $child->PID, " closed all pipes.\n";
	delete $_[HEAP]{children_by_pid}{$child->PID};
}



### ----------------------------
#
#	make sure the cleanup gets finished
#

sub got_child_signal {
	print "pid $_[ARG1] exited with status $_[ARG2].\n";
	my $child = delete $_[HEAP]{children_by_pid}{$_[ARG1]};

	# May have been reaped by on_child_close().
	return unless defined $child;

	delete $_[HEAP]{children_by_wid}{$child->ID};

}



### ----------------------------
### -----------------------------------------------------
### -----------------------------------------------------




### -----------------------------------------------------
#
#	subroutine to launch the "say" command.
#

# 'say', good old Apple built-in text-to-speech   =D
### -----------------------------------------------------

sub mac_say {
	my $ttspeak = $_[ARG0];

	my $voice;
	if(  defined($_[ARG1])  ){  $voice = $_[ARG1];  }
	else{  $voice = 'Fred';  }
	
# 	print '> say -v ', $voice, ' "', $ttspeak, '"', $/;
	my $output = '> say -v ' . $voice . ' "' . $ttspeak . '"';
	print $output, $/;
	$_[HEAP]{client}->put(  $output  );

	# ----
	my $child = POE::Wheel::Run->new(
		Program => [ $say_prog, '-v', $voice, $ttspeak ],
		StdoutEvent  => 'got_child_stdout',
		StderrEvent  => 'got_child_stderr',
		CloseEvent   => 'got_child_close',
	);

	$_[KERNEL]->sig_child(  $child->PID, 'got_child_signal'  );

	# Wheel events include the wheel's ID.
	$_[HEAP]{children_by_wid}{$child->ID} = $child;

	# Signal events include the process ID.
	$_[HEAP]{children_by_pid}{$child->PID} = $child;

	print(
		'Child pid-', $child->PID,
		' started as wheel #', $child->ID, '.', $/
	);
	

}

#	my "mac_say" subroutine above, the first few lines setup $voice, and $ttspeak
#	bottom section is a copy of:
#	http://search.cpan.org/dist/POE/lib/POE/Wheel/Run.pm#SYNOPSIS
#		 the "on_start" subroutine
#		   ( except  "Program => "  switched to 'say' for text-to-speech )
#

### -----------------------------------------------------



# end.

### ------------
### ------------
### ------------
