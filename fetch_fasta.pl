#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;

#---------------#
# GetOpt section
#---------------#

=head1 NAME

fetch_fasta.pl -- Get all sequences with the same searched string in a FastA file.

=head1 SYNOPSIS

    perl fetch_fasta.pl <-s string> [options]
        Options:
            --help\-h   Brief help message
            --string\-s The sequences we want to fetch
            --file\-f   The FastA file with path
            --stdin     Get FastA from STDIN. It will not been not valid with a provided '--file'

=cut

Getopt::Long::GetOptions(
    'help|h'     => sub { Getopt::Long::HelpMessage(0) },
    'string|s=s' => \my $char,
    'file|f=s'   => \my $in_fa,
    'stdin'      => \my $stdin,
) or Getopt::Long::HelpMessage(1);

my @info;
if ( defined($in_fa) ) {
    open FA, "<", $in_fa or die("$in_fa: $!");
    @info = <FA>;
    close FA;
}
elsif ( defined($stdin) ) {
    @info = <>;
}
else {
    die("You should provide FastA!");
}

my $i = 0;
while ( $i <= $#info ) {
    if ( $info[$i] =~ /$char/ ) {
        print( $info[$i] );
        my $j = 1;
        until ( $info[ $i + $j ] =~ /^>/ ) {
            print( $info[ $i + $j ] );
            $j++;
        }
        $i += $j;
    }
    else {
        $i++;
    }
}

__END__
