package Perbool::IntervalSet;

use strict;
use warnings;

sub new {
    my $class = shift;
    return bless { spans => [] }, $class;
}

sub add_range {
    my ( $self, $start, $end ) = @_;
    _assert_integer( $start, 'Range start' );
    _assert_integer( $end,   'Range end' );
    die "Range start must not exceed range end: $start-$end\n"
      if $start > $end;

    my @merged;
    my $inserted = 0;
    for my $span ( @{ $self->{spans} } ) {
        if ( $span->[1] + 1 < $start ) {
            push @merged, [ @{$span} ];
        }
        elsif ( $end + 1 < $span->[0] ) {
            push @merged, [ $start, $end ] unless $inserted++;
            push @merged, [ @{$span} ];
        }
        else {
            $start = $span->[0] if $span->[0] < $start;
            $end   = $span->[1] if $span->[1] > $end;
        }
    }
    push @merged, [ $start, $end ] unless $inserted;
    $self->{spans} = \@merged;
    return $self;
}

sub add_bed_range {
    my ( $self, $start, $end ) = @_;
    _assert_integer( $start, 'BED start' );
    _assert_integer( $end,   'BED end' );
    die "BED start must be zero or greater: $start\n" if $start < 0;
    die "BED end must be greater than BED start: $start-$end\n"
      if $end <= $start;
    return $self->add_range( $start + 1, $end );
}

sub cardinality {
    my $self = shift;
    my $count = 0;
    for my $span ( @{ $self->{spans} } ) {
        $count += $span->[1] - $span->[0] + 1;
    }
    return $count;
}

sub at {
    my ( $self, $index ) = @_;
    _assert_integer( $index, 'Interval index' );
    my $count = $self->cardinality;
    return if $index == 0 || abs($index) > $count;

    my $remaining = abs($index);
    my @spans = $index > 0
      ? @{ $self->{spans} }
      : reverse @{ $self->{spans} };
    for my $span (@spans) {
        my $length = $span->[1] - $span->[0] + 1;
        if ( $remaining <= $length ) {
            return $index > 0
              ? $span->[0] + $remaining - 1
              : $span->[1] - $remaining + 1;
        }
        $remaining -= $length;
    }
    return;
}

sub as_string {
    my $self = shift;
    return '-' unless @{ $self->{spans} };
    return join ',', map {
        $_->[0] == $_->[1] ? $_->[0] : $_->[0] . '-' . $_->[1]
    } @{ $self->{spans} };
}

sub _assert_integer {
    my ( $value, $label ) = @_;
    die "$label must be an integer\n"
      unless defined $value && $value =~ /\A-?\d+\z/;
}

1;
