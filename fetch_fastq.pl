#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use PerlIO::gzip;

##########################
# TODO: 2019/9/4 7:59 PM Add Get Option
##########################

my %target_name;
while (<STDIN>) {
    chomp;
    $target_name{$_} = 0;
}

open(my $in_fh,"<:gzip",$ARGV[0]);

while (<$in_fh>) {
    my $qname = $_;
    my ( $sequence, $t, $quality ) = <$in_fh>;
    $qname =~ /^@(\S+)/;
    unless ( exists $target_name{$1} ) {
        print "$qname$sequence$t$quality";
    }
}
$in_fh->close;

__END__
