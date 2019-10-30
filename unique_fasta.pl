#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

my %fasta;
my $current_seq = 0;

open( my $fa, "<", $ARGV[0] );
chomp( my $current_id = <$fa> );
while (<$fa>) {
    chomp;
    my $current_line = $_;
    if ( $current_line =~ m/^>/ ) {
        unless ( exists( $fasta{$current_seq} ) ) {
            $fasta{$current_seq} = $current_id;
            print("$fasta{$current_seq}\n$current_seq\n");
        }
        $current_seq = 0;
        $current_id  = $current_line;
    }
    else {
        if ( $current_seq eq 0 ) {
            $current_seq = $current_line;
        }
        else {
            $current_seq .= $current_line;
        }
    }
}
close($fa);
print("$current_id\n$current_seq\n");

__END__
