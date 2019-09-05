#!/usr/bin/perl
use strict;
use warnings;

##########################
# TODO: 2019/9/4 7:59 PM Add Get Option
##########################

my $char = $ARGV[0];
open FA, "<", $ARGV[1];
my @info = <FA>;
close FA;

my $i = 0;
while ($i <= $#info) {
    if ($info[$i] =~ /$char/) {
        print($info[$i]);
        my $j = 1;
        until ($info[$i+$j] =~ /^>/) {
            print($info[$i+$j]);
            $j ++ ;
        }
        $i += $j;
    }else{
        $i ++;
    }
}

__END__
