#!/usr/bin/perl
# It's run after the command line:
#     awk '$3=="exon"||$3=="three_prime_UTR"||$3=="five_prime_UTR" \
#         {print $1 "\t" $4 "\t" $5 "\t" $7 "\t" $9}' \
#         FILE_NAME.gff3

use strict;
use warnings FATAL => 'all';

use AlignDB::IntSpan;

my ( %trans_range, %trans_chr, %trans_dir );

while (<STDIN>) {
    chomp;
    my ( $chr, $start, $end, $dir, $info ) = split( /\t/, $_ );
    $info =~ /Parent=transcript:([A-Z,a-z,0-9]+)/;
    if ( exists( $trans_chr{$1} ) ) {
        $trans_range{$1}->AlignDB::IntSpan::add_range( $start, $end );
    }
    else {
        $trans_chr{$1}   = $chr;
        $trans_dir{$1}   = $dir;
        $trans_range{$1} = AlignDB::IntSpan->new;
        $trans_range{$1}->AlignDB::IntSpan::add_range( $start, $end );
    }
}

my $index = $ARGV[0];
my $site  = $ARGV[1];
my $island;
if ( $trans_dir{$index} eq "+" ) {
    $island = $trans_range{$index}->AlignDB::IntSpan::at($site);
}
else {
    $island = $trans_range{$index}->AlignDB::IntSpan::at( -$site );
}
my $abs_site = $trans_chr{$index} . "\t" . $island;
print("$abs_site\n");

__END__
