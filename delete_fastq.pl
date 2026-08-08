#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";

use Perbool::Command::FastqSelect qw(run);

exit run( 'delete', @ARGV );
