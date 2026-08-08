use strict;
use warnings;

use File::Find qw(find);
use Test::More;

my @sources;
find(
    sub {
        if ( -d $_ && /\A(?:[.]git|RBC|local|blib|_build|cover_db)\z/ ) {
            $File::Find::prune = 1;
            return;
        }
        return unless -f $_ && /[.](?:pl|pm)\z/;
        push @sources, $File::Find::name;
    },
    '.',
);
push @sources, './bin/perbool' if -f './bin/perbool';

@sources = sort @sources;
plan tests => scalar @sources;

for my $source (@sources) {
    my $status = system $^X, '-Ilib', '-c', $source;
    is( $status, 0, "$source compiles" );
}
