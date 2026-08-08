package Perbool::IO;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use IO::Zlib;

our @EXPORT_OK = qw(open_text_reader open_text_writer);

sub open_text_reader {
    my $path = shift;
    return *STDIN{IO} if $path eq '-';

    if ( $path =~ /[.]gz\z/i ) {
        my $fh = IO::Zlib->new( $path, 'rb' )
          or die "Cannot open $path: $!\n";
        return $fh;
    }

    open my $fh, '<', $path;
    return $fh;
}

sub open_text_writer {
    my $path = shift;
    return *STDOUT{IO} if $path eq '-';

    if ( $path =~ /[.]gz\z/i ) {
        my $fh = IO::Zlib->new( $path, 'wb9' )
          or die "Cannot open $path: $!\n";
        return $fh;
    }

    open my $fh, '>', $path;
    return $fh;
}

1;
