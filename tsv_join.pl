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

sub NEW_TBL {
    my ( $TBL, $NAME, $CONT ) = @_;
    @{ ${$TBL}{$NAME} } = @{$CONT};
    return ($TBL);
}

sub ADD_COL {
    my ( $TBL1, $TBL2, $WIDTH1, $WIDTH2, $NAME ) = @_;
    if ( ( exists( ${$TBL1}{$NAME} ) ) and ( exists( ${$TBL2}{$NAME} ) ) ) {
        push( @{ ${$TBL1}{$NAME} }, @{ ${$TBL2}{$NAME} } );
    }
    elsif ( exists( ${$TBL2}{$NAME} ) ) {
        @{ ${$TBL1}{$NAME} }[ 0 .. $WIDTH1 - 1 ] = ("N/A") x $WIDTH1;
        push( @{ ${$TBL1}{$NAME} }, @{ ${$TBL2}{$NAME} } );
    }
    elsif ( exists( ${$TBL1}{$NAME} ) ) {
        @{ ${$TBL1}{$NAME} }[ $WIDTH1 .. $WIDTH1 + $WIDTH2 - 1 ] =
          ("N/A") x $WIDTH2;
    }
    return ($TBL1);
}

while (<$TSV1>) {
    chomp;
    my @tbl  = split /\s+/;
    my $name = $tbl[0];
    $col_num1 = $#tbl;
    my @cont = @tbl[ 1 .. $col_num1 ];
    my $temp = NEW_TBL( \%table1, $name, \@cont );
    %table1 = %{$temp};
}

while (<$TSV2>) {
    chomp;
    my @tbl  = split /\s+/;
    my $name = $tbl[0];
    $col_num2 = $#tbl;
    my @cont = @tbl[ 1 .. $col_num2 ];
    my $temp = NEW_TBL( \%table2, $name, \@cont );
    %table2 = %{$temp};
}

my %count;
foreach my $e ( keys(%table1), keys(%table2) ) {
    $count{$e}++;
}

for my $key ( keys %count ) {
    my $temp = ADD_COL( \%table1, \%table2, $col_num1, $col_num2, $key );
    %table1 = %{$temp};
}

for my $key ( keys %table1 ) {
    print("$key\t@{$table1{$key}}\n");
}

__END__
