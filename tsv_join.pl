#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

my $tsv_root_file = shift @ARGV;
my (%table_root, $col_root);

open( my $TSV_ROOT, "<", $tsv_root_file );
while ( my $line = <$TSV_ROOT> ) {
    chomp $line;
    my @tbl      = split /\s+/, $line;
    my $name     = $tbl[0];
    $col_root = $#tbl;
    $table_root{$name} = join( "\t", @tbl[ 1 .. $col_root ] );
}
close($TSV_ROOT);

foreach my $file (@ARGV) {
    open( my $TSV_ADD, "<", $file );
    my %table_add;
    my $col_add;

    while ( my $line = <$TSV_ADD> ) {
        chomp $line;
        my @tbl  = split /\s+/, $line;
        my $name = $tbl[0];
        $col_add = $#tbl;
        $table_add{$name} = join( "\t", @tbl[ 1 .. $col_add ] );
    }
    close($TSV_ADD);

    my %count;
    @count{ keys %table_root, keys %table_add } = ();

    foreach my $key ( keys %count ) {
        if ( exists $table_root{$key} && exists $table_add{$key} ) {
            $table_root{$key} .= "\t$table_add{$key}";
        }
        elsif ( exists $table_add{$key} ) {
            $table_root{$key} = "NA\t" x $col_root;
            $table_root{$key} .= $table_add{$key};
        }
        elsif ( exists $table_root{$key} ) {
            $table_root{$key} .= "\tNA" x $col_add;
        }
    }

    $col_root += $col_add;
}

foreach my $key ( sort keys %table_root ) {
    print("$key\t$table_root{$key}\n");
}

__END__