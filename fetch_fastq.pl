#!/usr/bin/perl
use strict;
use warnings;

use IO::Zlib;

##########################
# TODO: 2019/9/4 7:59 PM Add Get Option
##########################

my $in_fq = IO::Zlib->new( $ARGV[0], "rb" );

my %info;
while (<$in_fq>) {
    chomp;
    chomp(my ($seq,$t,$qua) = <FQ>);
    $info{$_} = $seq."\n".$t."\n".$qua."\n";
}
$in_fq->close;

while (<STDIN>) {
    chomp;
    if (exists($info{$_})) {
        print($_."\n".$info{$_});
    }else{
        warn("Sorry, we can't find $_.\n");
    }
}

__END__