#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use IO::Zlib;

##########################
# TODO: 2019/9/4 7:59 PM Add Get Option
##########################

my $in_fq = IO::Zlib->new( $ARGV[0], "rb" );

my %info;
while (<$in_fq>) {
    chomp;
    $_ =~ s/^@//;
    chomp(my ($seq,$t,$qua) = <$in_fq>);
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