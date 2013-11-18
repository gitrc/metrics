#!/usr/bin/perl -w
#
# gather per-CPU SAN statistics - borrowed from http://aditya.grot.org/2009/02/netapp-ontap-per-volume-statistics.html
#
# do not forget to create a non-root user/role in ONTAP for this
#
# Rod Cordova (@gitrc)
#

use strict;
use RRDs;
use Data::Dumper;

my $username = "someuser";
my @netappHostnames = ( "netapp1", "netapp2" );

my $netappHostname;
my ($getStatCols);

$getStatCols->{'processor'}->{'type'} = "cpuStats";
@{ $getStatCols->{'processor'}->{'cols'} } =
  ( "processor_busy" );

foreach $netappHostname (@netappHostnames) {
    for my $stat ( keys %{$getStatCols} ) {
        my ($stattxt) = "${stat}:*:"
          . join( " ${stat}:*:", @{ $getStatCols->{$stat}->{'cols'} } );
        getStatTable( $username, $netappHostname,
            $getStatCols->{$stat}->{'type'},
            $stattxt, \&rrdupdate );
    }
}

sub getStatTable {

    #print Dumper my ( $user, $host, $id, $statcmd, $callback ) = @_;
    my ( $user, $host, $id, $statcmd, $callback ) = @_;

    my (@ret) =
`ssh ${user}\@${host} "stats stop -I ${id} -O print_zero_values=off -c -d |"`;
    my (@start) = `ssh ${user}\@${host} "stats start -I ${id} ${statcmd}"`;
    my ($startcmd) = join( ' ', @start );
    if ($startcmd) {
        $startcmd =~ s/\s+//g;
        chomp($startcmd);
        if ( $startcmd ne "" ) {
            print STDERR
              "ERROR starting stats collection for ${user}\@${host} $statcmd: "
              . $startcmd . "\n";
        }
    }

    if ( $#ret <= 2 ) {
        print STDERR "ERROR retrieving stats from ${user}\@${host} ${statcmd}: "
          . join( " ", @ret ) . "\n";
    }
    else {
        shift(@ret);
        shift(@ret);
        shift(@ret);
        for ( my $i = 0 ; $i <= $#ret ; $i++ ) {
            my ($l) = $ret[$i];
            chomp($l);
            $l =~ s/^\s+//g;
            $l =~ s/\s+$//g;
            if ( $l !~ /|$/ ) {
                $l .= "|";
            }
            my (@cols) = ( $id, $i, split( /\|/, $l ) );
            push @cols, $host;
            &$callback(@cols);
        }
    }
}

sub printfun {

    #shift(@_);
    my (@vals) = @_;
    for ( my $i = 0 ; $i <= $#vals ; $i++ ) {
        if ( !$vals[$i] || $vals[$i] eq '' ) {
            $vals[$i] = 0;
        }
    }

    #next if (! @vals);
    #next if (! $vals[0] || ! $vals[1]);
    print join( '|', @vals ) . "|\n";
}

sub rrdupdate {
    my (@vals) = @_;
    for ( my $i = 0 ; $i <= $#vals ; $i++ ) {
        if ( !$vals[$i] || $vals[$i] eq '' ) {
            $vals[$i] = 0;
        }
    }

    #print join('|', @vals) . "|\n";
    # rrd here
    #print "DEBUG: $netappHostname\n";

    my (
        $index, $instance, $processor,
        $processor_busy,
        $host
    ) = @vals;

    #print Dumper @vals;
    my $rrdir = "/path/to/metrics/netapp_cpu/$host";

    # if rrdtool database doesn't exist, create it
    if ( !-e "$rrdir/$processor.rrd" ) {
        print "creating rrd database for $processor ...\n";
        RRDs::create "$rrdir/$processor.rrd", "-s 300",
          "DS:processor_busy:GAUGE:600:U:U",
          "RRA:AVERAGE:0.5:1:600",          "RRA:AVERAGE:0.5:6:700",
          "RRA:AVERAGE:0.5:24:775",         "RRA:AVERAGE:0.5:288:797";
    }

    # do the update
    RRDs::update "$rrdir/$processor.rrd", "-t",
      "processor_busy",
      "N:$processor_busy";
}

