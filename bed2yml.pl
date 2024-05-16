#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use AlignDB::IntSpan;

open my $BED, "<", $ARGV[0];

my %yaml;
while (<$BED>) {
    chomp;
    my @tmp = split( /\t/, $_ );
    if ( exists( $yaml{ $tmp[0] } ) ) {
        $yaml{ $tmp[0] }->AlignDB::IntSpan::add_pair( $tmp[1], $tmp[2] );
    }
    else {
        $yaml{ $tmp[0] } = AlignDB::IntSpan->new;
        $yaml{ $tmp[0] }->AlignDB::IntSpan::add_pair( $tmp[1], $tmp[2] );
    }
}
close($BED);

print "---\n";
foreach my $chr ( sort keys(%yaml) ) {
    print "$chr: $yaml{$chr}\n";
}

__END__