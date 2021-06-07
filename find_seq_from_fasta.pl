#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use Getopt::Long;

Getopt::Long::GetOptions(
    'help|h'  => sub { Getopt::Long::HelpMessage(0) },
    'seq|s=s' => \my $in_seq,
    'in|i=s'  => \my $in_list,
    'fa|f=s'  => \my $in_fa,
    'stdin'   => \my $stdin,
) or Getopt::Long::HelpMessage(1);

my %fasta;
my $chr_name;
if ( defined($in_fa) ) {
    open my $FA, "<", $in_fa;
    while (<$FA>) {
        if (/^>(\S+)/) {
            $chr_name = $1;
        }
        else {
            $_ =~ s/\r?\n//;
            $fasta{$chr_name} .= $_;
        }
    }
    close($FA);
}
elsif ( defined($stdin) ) {
    while (<>) {
        if (/^>(\S+)/) {
            $chr_name = $1;
        }
        else {
            $_ =~ s/\r?\n//;
            $fasta{$chr_name} .= $_;
        }
    }
}
else {
    die("==> You should provide the FASTA!!\n");
}

if ( defined($in_list) ) {
    open( my $SEG, "<", $in_list );
    while (<$SEG>) {
        s/\r?\n//;
        my $seq = $_;
        foreach my $chr ( keys(%fasta) ) {
            while ( $fasta{$chr} =~ /$seq/g ) {
                my $p = pos( $fasta{$chr} );
                print "$chr\t$p\n";
            }
        }
    }
    close($SEG);
}
elsif ( defined($in_seq) ) {
    my $seq = $in_seq;
    foreach my $chr ( keys(%fasta) ) {
        while ( $fasta{$chr} =~ /$seq/g ) {
            my $p = pos( $fasta{$chr} );
            print "$chr\t$p\n";
        }
    }
}
else {
    die("==> You should provide the SEQ!!\n");
}
__END__
