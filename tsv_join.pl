#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

open( my $TSV_ROOT, "<", $ARGV[0] );
my @tsv_root = <$TSV_ROOT>;
close($TSV_ROOT);

my ( %table_root, $col_root );
foreach (@tsv_root) {
    chomp;
    my @tbl  = split /\s+/;
    my $name = $tbl[0];
    $col_root = $#tbl;
    $table_root{$name} = join( "\t", @tbl[ 1 .. $col_root ] );
}

foreach my $FILE ( @ARGV[ 1 .. $#ARGV ] ) {
    open( my $TSV_ADD, "<", $FILE );
    my @tsv_add = <$TSV_ADD>;
    close($TSV_ADD);
    my ( $col_add, %table_add );
    foreach (@tsv_add) {
        chomp;
        my @tbl  = split /\s+/;
        my $name = $tbl[0];
        $col_add = $#tbl;
        $table_add{$name} = join( "\t", @tbl[ 1 .. $col_add ] );
    }

    my %count;
    foreach my $e ( keys(%table_root), keys(%table_add) ) {
        $count{$e}++;
    }

    for my $key ( keys %count ) {
        if (    ( exists( $table_root{$key} ) )
            and ( exists( $table_add{$key} ) ) )
        {
            $table_root{$key} .= "\t" . $table_add{$key};
        }
        elsif ( exists( $table_add{$key} ) ) {
            $table_root{$key} = join( "\t", ("NA") x $col_root );
            $table_root{$key} .= "\t" . $table_add{$key};
        }
        elsif ( exists( $table_root{$key} ) ) {
            $table_root{$key} .= "\t" . join( "\t", ("NA") x $col_add );
        }
    }
    $col_root = $col_root + $col_add;
}

for my $key ( keys %table_root ) {
    print("$key\t$table_root{$key}\n");
}

__END__
