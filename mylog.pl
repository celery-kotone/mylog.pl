#!/usr/bin/env perl
use strict;
use warnings;

use utf8;
use Encode;

###############################################################################
#                                                                             #
# Create a directory for logs                                                 #
#                                                                             #
###############################################################################

my $log_dir = sprintf( "%s/%s", $ENV{'HOME'}, "opt/mylog" );

if ( defined( $ENV{'MYLOG_DIR'} ) ) {
    $log_dir = $ENV{'MYLOG_DIR'};
}

unless ( -e $log_dir ) {
    printf STDERR "Logging directory not found.\nCreating at %s\n", $log_dir;
    my $cd = "";
    foreach my $dir ( split( /\//, $log_dir ) ) {
	next unless ( length( $dir ) );

	$cd .= sprintf( "/%s", $dir );

	unless( -e $cd ) {
	    unless( defined( mkdir( $cd ) ) ) {
		die( sprintf( "Failed to create directory %s\n", $cd ) );
	    }
	}
    }
}




###############################################################################
#                                                                             #
# Process the arguments                                                       #
#                                                                             #
###############################################################################

my $i;
my ($command, $query);
my %opts;

for ( $i = 0; $i < scalar @ARGV; ++$i ) {
    $ARGV[$i] = decode_utf8( $ARGV[$i] );
    if( $ARGV[$i] =~ s/^--?// ) {
	if( $i+1 < scalar @ARGV ) {
	    if( $ARGV[$i+1] =~ /^--?/ ) {
		$opts{$ARGV[$i]} = 1;
	    } else {
		$opts{$ARGV[$i]} = $ARGV[$i+1];
		++$i;
	    }
	} else {
	    $opts{$ARGV[$i]} = 1;
	}
    } else {
	unless( defined( $command ) ) {
	    $command = $ARGV[$i];
	} else {
	    unless( defined( $query ) ) {
		$query = $ARGV[$i];
	    } else {
		$query .= sprintf( " %s", $ARGV[$i] );
	    }
	}
    }
}

if( defined( $opts{'h'} ) || defined( $opts{'help'} ) ) {
    &print_help();
}

die( "No command specified" ) unless( $command );

my $tag = $opts{'tag'} if defined( $opts{'tag'} );
my $key = $opts{'key'} if defined( $opts{'key'} );
my $pri = $opts{'pri'} if defined( $opts{'pri'} ) && $opts{'pri'} =~ /^\d$/;
my $id  = $opts{'id'}  if defined( $opts{'id'} );




###############################################################################
#                                                                             #
# Defined the subroutines                                                     #
#                                                                             #
###############################################################################


my ($sec, $min, $hour, $day, $month, $year) = localtime time;
$year += 1900;
$month += 1;

sub log_read {
    my $query = shift;

    if( defined( $query ) ) {
	if( $query eq "yesterday" ) {
	    --$day;
	} elsif ( $query =~ /(\d+) days ago/ ) {
	    $day -= $1;
	} elsif ( $query =~ /[\d-]+/ ) {
	    my @date = reverse( split( /-/, $query ) );
	    if( scalar( @date ) ) {
		$day = shift( @date );
	    }
	    if( scalar( @date ) ) {
		$month = shift( @date );
	    }
	    if( scalar( @date ) ) {
		$year = shift( @date );
	    }
	}
    }

    my $filename = sprintf( "%s/%s.mylog",
			    $log_dir,
			    join( '-', $year, $month, $day ) );

    if( -e $filename ) {
	open( my $lf, "<", $filename );

	printf ( "Reading log %s\n", $filename );

	if( defined( $tag ) ) {
	    printf ( "Filter TAG: %s\n", $tag );
	}

	if( defined( $key ) ) {
	    printf ( "Filter KEY: %s\n", $tag );
	}

	if( defined( $pri ) ) {
	    printf ( "Filter PRIORITY: %d\n", $pri );
	}

	my ( $logs, $header, $logid );
	my ( $flog, $i ) = ( 0, 0 );

	while( <$lf> ) {
	    chomp;

	    if( /^#/ && !defined( $header ) ) {
		$header = $_;
		next;
	    }

	    if( /^LOG:([\d-]+)/ ) {
		my ( $year, $month, $day, $hour, $min, $sec ) = split( /-/, $1 );
		$logid = sprintf( "%d-%02d-%02d-%02d-%02d-%02d", $year, $month, $day, $hour, $min, $sec );
		next;
	    }

	    if( /^START$/ ) {
		$flog = 1;
		next;
	    }

	    if( /^END$/ ) {
		$flog = 0;
		next;
	    }

	    if( /^ID:(\d+)$/ ) {
		$logs->{$logid}->{'id'} = $1;
	    }

	    if( defined( $tag ) ) {
		if( /^TAG:(.+)$/ ) {
		    my $tmp = $1;
		    if( $tmp =~ /$tag/ ) {
			$logs->{$logid}->{'tag'} = $tmp;
		    } else {
			$logs->{$logid}->{'tag'} = 0;
		    }
		}
	    } else {
		if( /^TAG:(.+)$/ ) {
		    $logs->{$logid}->{'tag'} = $1;
		}
		$logs->{$logid}->{'tag'} = "None" if
		    !$logs->{$logid}->{'tag'};
	    }

	    if( /^PRI:(\d)$/ ) {
		$logs->{$logid}->{'pri'} = $1;
	    }

	    if( $flog ) {
		$logs->{$logid}->{'log'} .= $_;
	    }
	}

	foreach my $log ( map{ $_->[0] }
			  sort{ $a->[1] <=> $b->[1] }
			  map{ [$_, join('',
					 map{ $_ = sprintf( "%02d", $_ ) }
					 split( /-/, $_ ) )] }
			  keys %$logs ) {
	    next unless $logs->{$log}->{'tag'};
	    next unless $logs->{$log}->{'log'};

	    if( defined( $key ) ) {
		next unless $logs->{$log}->{'log'} =~ /$key/;
	    }

	    if( defined( $pri ) ) {
		next unless defined( $logs->{$log}->{'pri'} );
		next unless $logs->{$log}->{'pri'} > $pri;
	    }

	    ( $year, $month, $day, $hour, $min, $sec ) = split( /-/, $log );
	    printf( "Log of %d-%02d-%02d %02d:%02d:%02d TAG:%s ID:%d\n- %s\n",
		    $year, $month, $day, $hour, $min, $sec,
		    $logs->{$log}->{'tag'},
		    $logs->{$log}->{'id'},
		    $logs->{$log}->{'log'} );
	}
    } else {
	die( sprintf( "Logfile %s not found\n", $filename ) );
    }
}

sub log_write {
    my $log = shift;

    my $filename = sprintf( "%s/%s.mylog",
			    $log_dir,
			    join( '-', $year, $month, $day ) );

    my $lf;

    unless( -e $filename ) {
	open( $lf, ">", $filename)
	    or die( sprintf( "Failed to open %s\n", $filename ) );

	printf $lf ( "#Log of %d/%d/%d\n",
		     $year,
		     $month,
		     $day );
    } else {
	open( $lf, ">>", $filename )
	    or die( sprintf( "Failed to open %s\n", $filename ) );
	}

    printf $lf ( "LOG:%d-%02d-%02d-%02d-%02d-%02d\n",
		 $year, $month, $day, $hour, $min, $sec );
    printf $lf ( "ID:%d\n", $year * ( $month + $day + $hour + $min + $sec ) );
    printf $lf ( "TAG:%s\n", $tag ) if defined( $tag );
    printf $lf ( "PRI:%d\n", $pri ) if defined( $pri );
    printf $lf ( "START\n%s\nEND\n", encode_utf8( $log ) );

    close $lf;
}

sub log_remove {
    my $query = shift;
    my $id = shift;

    if( defined( $query ) ) {
	if( $query eq "yesterday" ) {
	    --$day;
	} elsif ( $query =~ /(\d+) days ago/ ) {
	    $day -= $1;
	} elsif ( $query =~ /[\d-]+/ ) {
	    my @date = reverse( split( /-/, $query ) );
	    if( scalar( @date ) ) {
		$day = shift( @date );
	    }
	    if( scalar( @date ) ) {
		$month = shift( @date );
	    }
	    if( scalar( @date ) ) {
		$year = shift( @date );
	    }
	}
    }

    my $filename = sprintf( "%s/%s.mylog",
			    $log_dir,
			    join( '-', $year, $month, $day ) );

    if( -e $filename ) {
	open( my $lf, "<", $filename );

	printf ( "Removing from  log %s\n", $filename );

	my ( $logs, $header, $logid );
	my ( $flog, $i ) = ( 0, 0 );

	while( <$lf> ) {
	    chomp;

	    if( /^#/ && !defined( $header ) ) {
		$header = $_;
		next;
	    }

	    if( /^LOG:([\d-]+)/ ) {
		my ( $year, $month, $day, $hour, $min, $sec ) =
		    split( /-/, $1 );
		$logid = sprintf( "%d-%02d-%02d-%02d-%02d-%02d",
				  $year, $month, $day, $hour, $min, $sec );
		next;
	    }

	    if( /^START$/ ) {
		$flog = 1;
		next;
	    }

	    if( /^END$/ ) {
		$flog = 0;
		next;
	    }

	    if( /^ID:(\d+)$/ ) {
		if($1 == $id) {
		    $logs->{$logid}->{'remove'} = 1;
		}
	    }

	    if( defined( $tag ) ) {
		if( /^TAG.+$/ ) {
		    if( /$tag/ ) {
			$logs->{$logid}->{'tag'} = 1;
		    } else {
			$logs->{$logid}->{'tag'} = 0;
		    }
		}
	    } else {
		$logs->{$logid}->{'tag'} = 1;
	    }

	    if( /^PRI:(\d)$/ ) {
		$logs->{$logid}->{'pri'} = $1;
	    }

	    if( $flog ) {
		$logs->{$logid}->{'log'} .= $_;
	    }
	}

	foreach my $log ( map{ $_->[0] }
			  sort{ $a->[1] <=> $b->[1] }
			  map{ [$_, join('',
					 map{ $_ = sprintf( "%02d", $_ ) }
					 split( /-/, $_ ) )] }
			  keys %$logs ) {
	    next if $logs->{$log}->{'remove'};

	    print $logs->{$log}->{'remove'}. "\n";

	    ( $year, $month, $day, $hour, $min, $sec ) = split( /-/, $log );
	    printf( "Log of %d-%02d-%02d %02d:%02d:%02d\n- %s\n",
		    $year, $month, $day, $hour, $min, $sec,
		    $logs->{$log}->{'log'} );
	}
    } else {
	die( sprintf( "Logfile %s not found\n", $filename ) );
    }
}

sub print_help {
    print STDERR <<EOS;
Synopsis:
    mylog [-h|-help|--help] <command> [arguments]

Description:
    A simple interface for the management of logs.
    mylog.pl write <some string> [-tag TAGNAME] [-pri PRIORITY]
    mylog.pl read <some string> [-tag TAGNAME] [-pri PRIORITY] [-key KEYWORD]
EOS
exit;
}



###############################################################################
#                                                                             #
# Process the query                                                           #
#                                                                             #
###############################################################################

if( $command eq "write" ) {
    log_write( $query );
}elsif ( $command eq "read" ) {
    log_read( $query );
} elsif ( $command eq "remove" ) {
    log_remove( $query, $id );
} else {
    die( sprintf( "Specified command %s is invalid\n", $command ) );
}
