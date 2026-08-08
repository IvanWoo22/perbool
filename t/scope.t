use strict;
use warnings;

use Test::More;

use lib 'lib';
use Perbool::CLI qw(command_rows);

ok( !-e 'RBC', 'project-specific RBC workflow is absent from the toolkit tree' );
ok( -f 'docs/non-tool-archive.md', 'non-tool archive manifest is present' );

for my $row ( command_rows() ) {
    unlike(
        $row->[2],
        qr{\ARBC/},
        "$row->[0] $row->[1] is not implemented by the archived RBC workflow",
    );
}

done_testing();
