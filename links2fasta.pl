#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use Getopt::Long;

Getopt::Long::GetOptions(
    'help|h' => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s' => \my $in_list,
    'fa|f=s' => \my $in_fa,
    'stdin'  => \my $stdin,
) or Getopt::Long::HelpMessage(1);

sub SEQ_REV_COMP {
    my $SEQ = reverse shift;
    $SEQ =~ tr/Uu/Tt/;
    return ( $SEQ =~ tr/AGCTagct/TCGAtcga/r );
}

sub SEQ_TR_TU {
    my $SEQ = shift;
    return ( $SEQ =~ tr/Uu/Tt/r );
}

sub DECODE_LOCATION {
    my $header = shift;
    my $location_re = qr{
        (?:(?<name>[\w_]+)[.])?
        (?<chr>[\w-]+)
        (?:[(](?<strand>.+)[)])?
        :
        (?<start>\d+)
        [_-]?
        (?<end>\d+)?
    }xi;

    return unless $header =~ $location_re;

    my $strand = $+{strand};
    if ( defined $strand ) {
        $strand = '+' if $strand eq '1';
        $strand = '-' if $strand eq '-1';
    }

    return {
        chr    => $+{chr},
        strand => $strand,
        start  => $+{start},
        end    => defined $+{end} ? $+{end} : $+{start},
    };
}

my %fasta;
my $title_name;
open my $FA, "<", $in_fa;
while (<$FA>) {
    if (/^>(\S+)/) {
        $title_name = $1;
    }
    else {
        $_ =~ s/\r?\n//;
        $fasta{$title_name} .= $_;
    }
}
close($FA);

if ( defined($in_list) ) {
    open( my $SEG, "<", $in_list );
    while (<$SEG>) {
        s/\r?\n//;
        my $seq = fetch_seq($_);
        print $seq;
    }
    close($SEG);
}
elsif ( defined($stdin) ) {
    while (<>) {
        s/\r?\n//;
        my $seq = fetch_seq($_);
        print $seq;
    }
}
else {
    die("==> You should provide the FASTA!!\n");
}

sub fetch_seq {
    my $line        = shift;
    my $out_content = "";
    for my $range ( split /\t/, $line ) {
        my $info = DECODE_LOCATION($range);
        next unless defined $info;
        if ( exists( $fasta{ $info->{chr} } ) ) {
            my $length = abs( $info->{end} - $info->{start} ) + 1;
            my $seq =
              substr( $fasta{ $info->{chr} }, $info->{start} - 1, $length );
            if ( defined $info->{strand} and $info->{strand} eq "-" ) {
                $seq = SEQ_REV_COMP($seq);
            }
            else {
                $seq = SEQ_TR_TU($seq);
            }

            $out_content .= ">$range\n";
            my @lines = $seq =~ /.{1,70}/g;
            foreach my $line_out (@lines) {
                $out_content .= "$line_out\n";
            }
        }
        else {
            warn("Sorry, there is no such a segment: $range\n");
        }
    }
    return ($out_content);
}

__END__
