#!/usr/bin/perl -w

use 5.024;
use strict;
use Getopt::Std;
use IO::Socket;
use Fcntl;

# xenrcar.pl -  LCDd client showing system IP address and status of installed DUTs.
#
# Used for OSSTest setup based on RCar gen2 (H2) and gen3 (H3) Starter Kits.
# Supported configuration: 2x16 character display, 6 boards on EPAM's backplane v1.0
# Raspberry Pi 3b+ with custom Raspbian image.
# Cucles throug: Raspberry's IP address, state of EN_ and general purpose GPIOs.
# Based on iosock.pl - an example client for LCDproc
#
# Copyright (c) 2018, Artem Mygaiev <joculator@gmail.com>
# Copyright (c) 1999, William Ferrell, Selene Scriven
#               2001, David Glaude
#               2001, Jarda Benkovsky
#               2002, Jonathan Oxer
#               2002, Rene Wagner <reenoo@gmx.de>
#               2006, Peter Marschall
#
# This file is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this file; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
#

my $ver = "0.1";

############################################################
# Configurable part. Set it according your setup.
############################################################

# Host which runs lcdproc daemon (LCDd)
my $SERVER = "localhost";

# Port on which LCDd listens to requests
my $PORT = "13666";

# Boards enable GPIOs
my @EN  = ("13", "26", "12", "23", "27", "22");
my @IO1 = ("21", "20",  "6",  "7", "18",  "9");
my @IO2 = ( "8", "10", "11", "17", "24", "25");

############################################################
# End of user configurable parts
############################################################

my $progname = $0;
   $progname =~ s#.*/(.*?)$#$1#;

# declare functions
sub error($@);
sub usage($);
sub get_ips();
sub get_gpios(@);

## main routine ##
my %opt = ();

# get options #
if (getopts('F:s:P:hV', \%opt) == 0) {
	usage(1);
}

# check options
usage(0)  if ($opt{h});
if ($opt{V}) {
	print STDERR $progname ." version $ver\n";
	exit(0);
}

# check number of arguments
#usage(1)  if ($#ARGV >= 0);

# set variables
$SERVER = defined($opt{s}) ? $opt{s} : $SERVER;
$PORT = defined($opt{p}) ? $opt{p} : $PORT;

# Connect to the server...
my $remote = IO::Socket::INET->new(
		Proto     => 'tcp',
		PeerAddr  => $SERVER,
		PeerPort  => $PORT,
	)
	or  error(1, "cannot connect to LCDd daemon at $SERVER:$PORT");

# Make sure our messages get there right away
$remote->autoflush(1);

sleep (1);	# Give server plenty of time to notice us...

print $remote "hello\n";
# Note: it's good practice to listen for a response after a print to the
# server even if there isn't meant to be one. If you don't, you may find
# your program crashes after running for a while when the buffers fill up:
my $lcdresponse = <$remote>;
#print $lcdresponse;

# Turn off blocking mode...
fcntl($remote, F_SETFL, O_NONBLOCK);

# Set up some screen widgets...
print $remote "client_set name {$progname}\n";
$lcdresponse = <$remote>;
print $remote "screen_add xenrcar\n";
$lcdresponse = <$remote>;
print $remote "screen_set xenrcar name {Ping Status}\n";
$lcdresponse = <$remote>;
print $remote "widget_add xenrcar title title\n";
$lcdresponse = <$remote>;
print $remote "widget_set xenrcar title {Xen R-Car v$ver}\n";
$lcdresponse = <$remote>;
print $remote "widget_add xenrcar info frame\n";
$lcdresponse = <$remote>;
print $remote "widget_set xenrcar info 1 2 16 2 16 3 v 20\n"; 
$lcdresponse = <$remote>;
print $remote "widget_add xenrcar ip string -in info\n";
$lcdresponse = <$remote>;
print $remote "widget_add xenrcar status string -in info\n";
$lcdresponse = <$remote>;
print $remote "widget_add xenrcar gpio string -in info\n";
$lcdresponse = <$remote>;

while (1) {
	my $status = "";
	while (defined(my $line = <$remote>)) {
	    next  if ($line =~ /^success$/o);
	    print $line;
	}

	my @ipaddrs = get_ips();
	print $remote "widget_set xenrcar ip 1 1 {$ipaddrs[0]}\n";
	$lcdresponse = <$remote>;

	# Boards' power On/Off
	my @en = get_gpios(@EN);
	foreach my $i (0..$#en) {
		my $val = $en[$i];
		if    ($val eq "0") { $status .= " X"; }
		elsif ($val eq "1") { $status .= " R"; }
		else                { $status .= " ?"; }
	}
	print $remote "widget_set xenrcar status 1 2 {PWR:$status}\n";
	$lcdresponse = <$remote>;

	# Boards' GPIO_1/GPIO_2 status
	my @io1 = get_gpios(@IO1);
	my @io2 = get_gpios(@IO2);
	$status = "";
	foreach my $i (0..$#io1) {
		my $val = $io1[$i].$io2[$i];
		if    ($val eq "00") { $status .= " A"; }
		elsif ($val eq "01") { $status .= " B"; }
		elsif ($val eq "10") { $status .= " C"; }
		elsif ($val eq "11") { $status .= " D"; }
		else                 { $status .= " ?"; }
	}
	print $remote "widget_set xenrcar gpio 1 3 {INF:$status}\n";
	$lcdresponse = <$remote>;

	# wait a bit
	sleep(1);
}

close($remote)  or  error(1, "close() failed: $!");
exit;

## determine host IP address ##
# Synopsis: get_ips()
sub get_ips()
{
	# Check current IP address
	my @ip_output = `ip addr show scope global up`; # dev eth0 ?
	my @ip_all;
	foreach my $ip_line (@ip_output) {
		if (my @ip_match = $ip_line =~ m/inet (.+)\//g) {
			push (@ip_all, $ip_match[0]);
		}
	}
	if (!@ip_all) { $ip_all[0] = "No IP assigned!"; }

	return @ip_all;
}

sub get_gpios(@)
{
	my @pins = @_;
	my @status;

	foreach my $pin (@pins) {
		my $val = `cat /sys/class/gpio/gpio$pin/value`;
		if (!$val) { $val = "-"; }
		else       { $val =~ s/[\x0A\x0D]//g; }
		push (@status, $val);
	}

	return @status;
}

## print out error message and eventually exit ##
# Synopsis:  error($status, $message)
sub error($@)
{
	my $status = shift;
	my @msg = @_;

	print STDERR $progname . ": " . join(" ", @msg) . "\n";

	exit($status) if ($status);
}

## print out usage message and exit ##
# Synopsis:  usage($status)
sub usage($)
{
	my $status = shift;

	print STDERR "Usage: $progname [<options>] [<host> ...]\n";
	if (!$status) {
	print STDERR	"  where <options> are\n" .
			"    -s <server>    connect to <server> (default: $SERVER)\n" .
			"    -p <port>      connect to <port> on <server> (default: $PORT)\n" .
			"    -h             show this help page\n" .
			"    -V             display version number\n";
	}
	else {
		print STDERR "For help, type: $progname -h\n";
	}

	exit($status);
}

__END__

=pod

=head1 NAME

rcartest.pl -- show system IP address and status of DUTs on LCD


=head1 SYNOPSIS

B<rcartest.pl>
[B<-s> I<server>]
[B<-p> I<port>]
[B<-h>]
[B<-V>]
[I<host> ...]


=head1 DESCRIPTION

B<rcartest.pl> is an LCDd client showing system IP address and status of installed DUTs.

=head1 OPTIONS

=over 4

=item B<-s> I<server>

Connect to the LCDd daemon at host I<server> instead of the default C<localhost>.

=item B<-p> I<port>

Use port I<port> when connecting to the LCDd server instead of the default
LCDd port C<13666>.

=item B<-h>

Display a short help page and exit.

=item B<-V>

Display rcartest.pl's version number and exit.

=back


=head1 SEE ALSO

L<LCDd(8)>


=head1 AUTHORS

rcartest.pl was written by Artem Mygaiev based on iosock.pl from lcdproc team 

=cut

# EOF

