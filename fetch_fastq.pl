#!/usr/bin/perl
use strict;
use warnings;

##########################
# TODO: 2019/9/4 7:59 PM Add Get Option
##########################

open FETCH, "<", $ARGV[0];
open FQ, "<", $ARGV[1];

my %info;
while (<FQ>) {
    chomp;
    chomp(my ($seq,$t,$qua) = <FQ>);
    $info{$_} = $seq."\n".$t."\n".$qua."\n";
}
close(FQ);

while (<FETCH>) {
    chomp;
    if (exists($info{$_})) {
        print($_."\n".$info{$_});
    }else{
        warn("Sorry, we can't find $_.\n");
    }
}
close(FETCH);

__END__