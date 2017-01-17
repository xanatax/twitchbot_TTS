#!/usr/bin/perl -w

#
#	this... will... of course... FAIL!
#		...if you don't have "modules" installed, that I use!!
#	DON'T PANIC!   =D
#		errors on lines 99-110 mean you need to install something!
#		for instructions to install perl modules: read lines 81-91
#



my $VERSION = 0.02; # 2017 jan 16 -- xanatax, uploaded to github!

#
#	perl mac_speechbot.pl
#		connect to twitch-chat, text-to-speech
#
#	[ basic example, bot code running on a Mac!!  PogChamp  A MAC!!!  ]
#	[ nothing is included for cooldowns, auto-speak, etc.  ]
#	[     "left as an exercise for the reader"  ;)  ]
#	[ commands are caster only, atm.  ]
#	[     altho... update for 'mods-only' is pretty easy.  ]
#
#	please read & modify this block of variables...
#		the first 30-lines are just config!
#
#	this is perl code, not C ... to some extent, humans read this!
#		( or, skim over the code, and read the comments. )
#

my $twitch_channel = 'your_channel';

my $twitch_botname = 'your_bot_name';

my $twitch_bot_oauth = 'oauth:xxxthisisnotactuallymyoauthxxx';
	###	 e.g. login to twitch *AS YOUR BOT*, and go to:
	###			https://twitchapps.com/tmi		--or--
	###			https://www.twitchtools.com/chat-token


my $prefix = '\!';

my $say_prog = '/usr/bin/say';
	###  this might be in the same place on Macs, (you'd think right?)
	###   but who knows... if your 'say' is located is somewhere else,
	###   type:  " which say " into the Terminal, 
	###    it will report the correct location 

my $default_voice = 'Fred';
	###  type:  " say -v ? " into the Terminal, 
	###    prints a list of voices.



#
#	INDEX :: layout of the code:
#
#		- stuff you should edit above.
#		- this INDEX! <-- you are here.
#		- use modules!
#		- set utf8  [ allows foreign lang. characters & emoji ]
#		- setup IRC/twitch-chat connection info
#		- config POE & start bot kernel
#		- a number of  irc_  subroutines
#			i.e. handle the _start, irc_001, irc_002, etc. welcome msgs.
#			usernames, pings, joins, parts <-- just get ignored
#		- irc_ctcp_action  for /me  -- nothing atm.
#		- irc_whisper  for /whisper -- nohting atm.
#		- IRC_PUBLIC  subroutine, where channel commands are made!	<---  
#		- handlers for child-processes (just output info to debug)
#		- the subroutine that calls "say" for text-to-speech   =D
#



# ------	we're going to use some perl modules to make life easy!
#
#	this is where you can stop reading!   (unless you haven't installed modules, yet)
#
#	if you don't have any of the modules, listed next, you *will* get an error
#	if the error says, "maybe you don't have <module> installed?"
#
#	this can be fixed, by installing the module.  
#	this means going to to Terminal, and typing:
#		sudo bash
#		<enter your passwd>
#		cpan
#		  install <module>
#		  exit
#		exit
#
#
#	#	config-file is done, code starts below    =D
#



use strict;
use warnings;
use utf8;

use Switch;                                          # <--- 

use POE;
use POE qw( Component::IRC );                        # <---
use POE qw( Wheel::Run );

use Time::HiRes qw( time );
use Time::Local qw( timegm );

#
#		these are essentially identical examples:
#	http://poe.perl.org/?POE_Cookbook/IRC_Bots
#	http://search.cpan.org/~bingos/POE-Component-IRC-6.88/lib/POE/Component/IRC.pm#SYNOPSIS
#		literally, this code, +OAuth key from twitch-API == working bot.
#		also:	http://www.stonehenge.com/merlyn/PerlJournal/col09.html  similar bot
#		
#		additionally:
#	http://search.cpan.org/dist/POE/lib/POE/Wheel/Run.pm#SYNOPSIS
#		we want to run the text-to-speech in the background "multi-threaded" 
#		already using POE, so POE::Wheel::Run is *much* better than fork()
#



# ------	set output mode to "correct"  :P

$|++;

binmode STDOUT, ":encoding(UTF-8)";



# ------	config file for behind-the-scenes variables   =D

my $server   = 'irc.chat.twitch.tv';

my $channame = '#' . $twitch_channel;
my $botchan = '#' . $twitch_botname;

my @channels = ( $channame, $botchan );


print '-->| ', $twitch_botname, ' |<--';
print "\t\t\t\t",'-->{ ', $channame, ' }<--',$/;



# ------
# ------
# We create a new PoCo-IRC object

my $irc = POE::Component::IRC->spawn(
	nick => $twitch_botname,
	ircname => $twitch_botname,
	server  => $server,
	password => $twitch_bot_oauth,
) or die "Oh noooo! $!";


# ------
# ------
# ------
# declare every subroutine that will be managed by POE!

POE::Session->create(
	package_states => [
		main => [ qw( 
			      _default  _start  _stop  irc_connected  irc_cap  irc_376
			      irc_public  irc_whisper  irc_ctcp_action  irc_ctcp 
			      irc_353  irc_366  irc_ping  irc_join  irc_part
			      irc_mode
			      got_child_stdout  got_child_stderr  got_child_close  got_child_signal 
			      mac_say
		        ) ],
	],
	inline_states => {
		irc_001 =>	=> \&irc_welcome,
		irc_002 =>	=> \&irc_welcome,
		irc_003 =>	=> \&irc_welcome,
		irc_004 =>	=> \&irc_welcome,
		irc_372 =>	=> \&irc_welcome,
		irc_375 =>	=> \&irc_welcome,
	},
	heap => { irc => $irc },
);


# ------
# ------
# ------


###################
$poe_kernel->run();
###################



### -----------
# We registered for all events, this will produce some debug info.

sub _default {
	my ($event, $args) = @_[ARG0 .. $#_];
	my @output = ( "$event: " );

	for my $arg (@$args) {
		if ( ref $arg eq 'ARRAY' ) {
			push( @output, '[' . join(', ', @$arg ) . ']' );
		}
		else {
			push ( @output, "'$arg'" );
		}
	}
	print join ' ', @output, "\n";
	return;
}

#
#	this  "_default" routine is directly from:
#	http://poe.perl.org/?POE_Cookbook/IRC_Bot_Debugging    --and--
#	http://search.cpan.org/~bingos/POE-Component-IRC-6.88/lib/POE/Component/IRC.pm#SYNOPSIS
#



### -----------
# specifically, this runs once when POE session starts

sub _start {

# 	$_[HEAP]->{next_alarm_time} = time() + 20;
# 	$_[KERNEL]->alarm(  tick => $_[HEAP]->{next_alarm_time}  );

	my $heap = $_[HEAP];
	$heap->{'capACK'} = 0;


	# we should put this on the heap too!
	$heap->{'started'} = time();
	print 'started:  ', $heap->{'started'}, $/;
	
	
	# retrieve our component's object from the heap where we stashed it
	my $irc = $heap->{irc};

	$irc->yield( register => 'all' );
	$irc->yield( connect => { } );
	return;
}



### -----------
#  just some text so we know when  _stop  gets called.

sub _stop {

	print 'I want to stop!  let me stop!',$/;
	
	return;
}



### -----------
#  runs once when we connect to twitch-chat server.

sub irc_connected {
	my( $sender, $serv ) = @_[SENDER, ARG0] ;

	my $irc = $sender->get_heap();

	print "Connected: \t", $serv, "\n";
# 	print "Connected to ", $irc->server_name(), "\n";

	# --- magic ---
        $irc->yield(  quote => 'CAP REQ :twitch.tv/membership'  );
        $irc->yield(  quote => 'CAP REQ :twitch.tv/commands'  );
        $irc->yield(  quote => 'CAP REQ :twitch.tv/tags'  );
	# ---
	
	# say hello!
	$_[KERNEL]->yield(  'mac_say', 'hello!'  );

	return;
}

#
#	this  "irc_connected" routine is from:
#	http://search.cpan.org/~bingos/POE-Component-IRC-6.88/lib/POE/Component/IRC.pm#SYNOPSIS
#	
#	added some twitch-magic, and a greeting!
#



### -----------
#  nice to know when we are actually ready   =D
#  all the CAP REQ stuff, ... twitch-magic.

sub irc_cap {
	my( $cmd, $param ) = @_[ARG0 .. $#_];
	my $heap = $_[HEAP];

	print "\t CAP:    ", $cmd, '    ', $param, $/;  
  
	switch(  $cmd  ){
	
		case(  'NAK'  ){    }
		case(  'LS'   ){    }
		case(  'ACK'  ){
			$heap->{'capACK'}++;    
		}
		
	}

	if(  3 == $heap->{'capACK'}  ){
		$_[KERNEL]->yield(  'mac_say', 'ready', 'trinoids'  );
	}

	return;
}



### -----------
#  make the welcome message pretty looking   =D

sub irc_welcome {
	my( $welcome ) = $_[ARG1];
	print '###   ', $welcome, $/;

	
	return;
}



### -----------
#  welcome message is done.

sub irc_376 {
	my( $welcome ) = $_[ARG1];
	print '###   ', $welcome, $/;


	# ------  moved 'joins' here from 001	
	#			001 is the beginning of welcome msg
	#			376 is the end of welcome msg
	#			seems better to wait until it's done   =)
	
	# we join our channels
	$irc->yield( join => $_ ) for @channels;

	
	return;
}



### -----------
### -----------
# in case we want to know who the mods are.

my %chan_mods;

sub irc_mode {
	my( $server, $channel, $state, $nick ) = @_[ARG0 .. $#_];

	print "\t MODE:  ", $channel, '    ', $state, '    ', $nick, $/;
	switch(  $state  ){
		case(  '+o'  ){  $chan_mods{ $nick } = 1;  }
		case(  '-o'  ){  $chan_mods{ $nick } = 0;  }
	}
	
	return;
}



### -----------
#  just not using this info, so I'm going to ignore it.   :P
#  ( these can get a little spammy if I leave them as 'debug' info )
#  assigning an empty subroutine means "do nothing at all"

sub irc_353 {  }
sub irc_366 {  }

sub irc_join {  }
sub irc_part {  }

sub irc_ping {  }



### -----------
#	receive /me
#		idk ... if ppl want bot that responds to /me !botcommand  
#		this bot... doesn't.
#

sub irc_ctcp_action { 
	# my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. $#_];
 	# my $nick = ( split /!/, $who )[0];
 	
	# print "\t--\t", $nick, ' ', $what, '    ', $where->[0], $/;

	#
	# if you wanted the bot to respond to /me actions
	# ...feel free to add code here.   =D
	#
	
	return;
}

sub irc_ctcp {
	#
	# twitch sends a duplicate set of data for /me actions.
	# ...usually, this means pick one, discard the other.
	#
	#	...this subroutine implements, the latter.
	#
	return;
}



### -----------
#	receive /whisper
#

sub irc_whisper {  
	my ($from, $to, $message) = @_[ARG0 .. $#_];
	my $nick = ( split /!/, $from )[0];
	print $/, 'WHISPER from: ', $nick, "\t::\t", $message, $/, $/;

# 	my $str_out = $nick . ' just whispered me!  <3';
# 	$irc->yield(  privmsg => $botchan => $str_out  );

	#
	# if you wanted the bot to respond to /whisper 
	# ...feel free to add code here.   =D
	#


	return;
}



### -----------
### -----------------------------------------------------
### -----------



sub irc_public {
	my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
 	my $nick = ( split /!/, $who )[0];
	my $channel = $where->[0];


	#
	#  strip the prefix, 
	#	(makes it easier to have a variable prefix char)
	#		*** this is from grue-bot   =)
	###				http://grue.sourceforge.net/
	### -----------------------------------------------------

	if(  ($what =~ /^(${prefix}\S+)/i)  ){
		# remove the prefix!
		$what =~ s/^${prefix}//; 		

	}else{
		return;
	}



	### -----------------------------------------------------
	### -----------------------------------------------------

	# 	we'll only accept commands from a few accounts.
	if(    ( 
		'xanatax' eq $nick  ||  'imperialgrrl' eq $nick  ||
		$twitch_channel eq $nick  ||  $twitch_botname eq $nick 
	    )    ){
		
		
		
		print $/, "\t[ MOD ]  ", $nick, "\t-->|", $what, "|<--", $/;


	
		if(  $what =~ /^say (.*)$/  ){
			$_[KERNEL]->yield(  'mac_say', $1, $default_voice  );
		}

		if(  $what =~ /^fred (.*)$/  ){
			$_[KERNEL]->yield(  'mac_say', $1, 'Fred'  );
		}

		if(  $what =~ /^zarvox (.*)$/  ){
			$_[KERNEL]->yield(  'mac_say', $1, 'Zarvox'  );
		}

		if(  $what =~ /^trinoids (.*)$/  ){
			$_[KERNEL]->yield(  'mac_say', $1, 'Trinoids'  );
		}


	}
	
	

	###  ---------------- end of bot cmds ----------------

	return;
}





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
	
	return;
}



### ----------------------------
#
#	this shows us any debug output from the text-to-speech program
#

sub got_child_stderr {
	my(  $stderr_line, $wheel_id  ) = @_[ARG0, ARG1];
	my $child = $_[HEAP]{children_by_wid}{$wheel_id};

	print "pid ", $child->PID, " STDERR: $stderr_line\n";
	
	return;
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
	
	return;
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

	return;
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
	
	print '> say -v ', $voice, ' "', $ttspeak, '"', $/;

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
