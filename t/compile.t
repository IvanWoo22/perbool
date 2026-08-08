use strict;
use warnings;

use File::Find qw(find);
use Test::More;

my @scripts;
find(
    sub {
        return unless -f $_ && /[.]pl\z/;
        push @scripts, $File::Find::name;
    },
    '.',
);
push @scripts, './bin/perbool' if -f './bin/perbool';

@scripts = sort @scripts;
plan tests => scalar @scripts;

for my $script (@scripts) {
    my $status = system $^X, '-c', $script;
    is( $status, 0, "$script compiles" );
}
