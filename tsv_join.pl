#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

open( my $TSV1, "<", $ARGV[0] );
open( my $TSV2, "<", $ARGV[1] );

my %table1;
my %table2;
my $col_num1;
my $col_num2;

my @tsv1 = <$TSV1>;
foreach (@tsv1) {
    chomp;
    my @tbl  = split /\s+/;
    my $name = $tbl[0];
    $col_num1 = $#tbl;
    $table1{$name} = join( "\t", @tbl[ 1 .. $col_num1 ] );
}

my @tsv2 = <$TSV2>;
foreach (@tsv2) {
    chomp;
    my @tbl  = split /\s+/;
    my $name = $tbl[0];
    $col_num2 = $#tbl;
    $table2{$name} = join( "\t", @tbl[ 1 .. $col_num2 ] );
}

my %count;
foreach my $e ( keys(%table1), keys(%table2) ) {
    $count{$e}++;
}

for my $key ( keys %count ) {
    if ( ( exists( $table1{$key} ) ) and ( exists( $table2{$key} ) ) ) {
        $table1{$key} .= "\t" . $table2{$key};
    }
    elsif ( exists( $table2{$key} ) ) {
        $table1{$key} = join( "\t", ("N/A") x $col_num1 );
        $table1{$key} .= "\t" . $table2{$key};
    }
    elsif ( exists( $table1{$key} ) ) {
        $table1{$key} .= "\t" . join( "\t", ("N/A") x $col_num2 );
    }
}

for my $key ( keys %table1 ) {
    print("$key\t$table1{$key}\n");
}

__END__
