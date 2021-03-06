#!/usr/bin/perl
#
# idrlogin.pl    -- sample Perl 5 script to identify the network source of a
#		    network (remote) login via rlogind, sshd, or telnetd


# IMPORTANT DEFINITIONS
# =====================
#
# 1.  Set the interpreter line of this script to the local path of the
#     Perl 5 executable.


# Copyright 1997 Purdue Research Foundation, West Lafayette, Indiana
# 47907.  All rights reserved.
#
# Written by Victor A. Abell
#
# This software is not subject to any license of the American Telephone
# and Telegraph Company or the Regents of the University of California.
#
# Permission is granted to anyone to use this software for any purpose on
# any computer system, and to alter it and redistribute it freely, subject
# to the following restrictions:
#
# 1. Neither the authors nor Purdue University are responsible for any
#    consequences of the use of this software.
#
# 2. The origin of this software must not be misrepresented, either by
#    explicit claim or by omission.  Credit to the authors and Purdue
#    University must appear in documentation and sources.
#
# 3. Altered versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
#
# 4. This notice may not be removed or altered.

# Initialize variables.

$dev = $faddr = $tty = "";					# fd variables
$pidst = 0;							# process state
$cmd = $login = $pgrp = $pid = $ppid = "";			# process var.

# Set path to lsof.

if (($LSOF = &isexec("../lsof")) eq "") {	# Try .. first
    if (($LSOF = &isexec("lsof")) eq "") {	# Then try . and $PATH
	print "can't execute $LSOF\n"; exit 1
    }
}

# Open a pipe from lsof

if (! -x "$LSOF") { die "Can't execute $LSOF\n"; }
open (P, "$LSOF -R -FcDfLpPRn0|") || die "Can't pipe from $LSOF\n";

# Process the lsof output a line at a time

while (<P>) {
    chop;
    @F = split('\0', $_, 999);
    if ($F[0] =~ /^p/) {

# A process set begins with a PID field whose ID character is `p'.

	if ($pidst) { &save_proc }
	foreach $i (0 .. ($#F - 1)) {

	    PROC: {
		if ($F[$i] =~ /^c(.*)/) { $cmd = $1; last PROC }
		if ($F[$i] =~ /^p(.*)/) { $pid = $1; last PROC }
		if ($F[$i] =~ /^R(.*)/) { $ppid = $1; last PROC }
		if ($F[$i] =~ /^L(.*)/) { $login = $1; last PROC }
	    }
	}
	$pidst = 1;
	next;
    }

# A file descriptor set begins with a file descriptor field whose ID
# character is `f'.

    if ($F[0] =~ /^f/) {
	if ($faddr ne "") { next; }
	$proto = $name = "";
	foreach $i (0 .. ($#F - 1)) {

	    FD: {
		if ($F[$i] =~ /^P(.*)/) { $proto = $1; last FD; }
		if ($F[$i] =~ /^n(.*)/) { $name = $1; last FD; }
		if ($F[$i] =~ /^D(.*)/) { $dev = $1; last FD; }
	    }
	}
	if ($proto eq "TCP"
	&&  $faddr eq ""
	&&  (($cmd =~ /rlogind/) || ($cmd =~ /sshd/) || ($cmd =~ /telnetd/))) {
	    if (($name =~ /[^:]*:[^-]*->([^:]*):.*/)) {
		$faddr = $1;
	    }
	} elsif ($tty eq "" && ($cmd =~ /.*sh$/)) {
	    if (($name =~ m#/dev.*ty.*#)) {
		($tty) = ($name =~ m#/dev.*/(.*)#);
	    } elsif (($name =~ m#/dev/(pts/\d+)#)) {
		$tty = $1;
	    } elsif (($name =~ m#/dev.*pts.*#)) {
		$d = oct($dev);
		$tty = sprintf("pts/%d", $d & 0xffff);
	    }
	}
	next;
    }
}

# Flush any stored file or process output.

if ($pidst) { &save_proc }

# List the shell processes that have rlogind/sshd/telnetd parents.

$hdr = 0;
foreach $pid (sort keys(%shcmd)) {
    $p = $pid;
    if (!defined($raddr{$pid})) {
        for ($ff = 0; !$ff && defined($Ppid{$p}); ) {
	    $p = $Ppid{$p};
	    if ($p < 2 || defined($raddr{$p})) { $ff = 1; }
        }
    } else { $ff = 2; }
    if ($ff && defined($raddr{$p})) {
	if (!$hdr) {
	    printf "%-8.8s %-8.8s %6s %-10.10s %6s %-10.10s %s\n",
		"Login", "Shell", "PID", "Via", "PID", "TTY", "From";
	    $hdr = 1;
	}
	printf "%-8.8s %-8.8s %6d %-10.10s %6s %-10.10s %s\n",
	    $shlogin{$pid}, $shcmd{$pid}, $pid,
	    ($ff == 2) ? "(direct)" : $rcmd{$p},
	    ($ff == 2) ? "" : $p,
	    ($shtty{$pid} eq "") ? "(unknown)" : $shtty{$pid},
	    $raddr{$p};
    }
}
exit(0);


# save_proc -- save process information
#	       Values are stored inelegantly in global variables.

sub save_proc {
    if (!defined($Ppid{$pid})) { $Ppid{$pid} = $ppid; }
    if ($faddr ne "") {
	$raddr{$pid} = $faddr;
	if (($cmd =~ /.*sh$/)) {
	    $shcmd{$pid} = $cmd;
	    $shlogin{$pid} = $login;
	} else { $rcmd{$pid} = $cmd; }
    }
    if ($tty ne "") {
	$shcmd{$pid} = $cmd;
	$shtty{$pid} = $tty;
	$shlogin{$pid} = $login;
    }

# Clear variables.

    $cmd = $dev = $faddr = $pgrp = $pid = $ppid = $tty = "";
    $pidst = 0;
}


## isexec($path) -- is $path executable
#
# $path   = absolute or relative path to file to test for executabiity.
#	    Paths that begin with neither '/' nor '.' that arent't found as
#	    simple references are also tested with the path prefixes of the
#	    PATH environment variable.

sub
isexec {
    my ($path) = @_;
    my ($i, @P, $PATH);

    $path =~ s/^\s+|\s+$//g;
    if ($path eq "") { return(""); }
    if (($path =~ m#^[\/\.]#)) {
	if (-x $path) { return($path); }
	return("");
    }
    $PATH = $ENV{PATH};
    @P = split(":", $PATH);
    for ($i = 0; $i <= $#P; $i++) {
	if (-x "$P[$i]/$path") { return("$P[$i]/$path"); }
    }
    return("");
}
