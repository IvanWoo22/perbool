use strict;
use warnings;

open(my $in1,"<",$ARGV[0]);
open(my $in2,"<",$ARGV[1]);

my %compare;
while(<$in1>){
    chomp;
    $compare{$_}=1;
}

while(<$in2>){
    chomp;
    if(exists($compare{$_})){
        print("$_\n");
    }
}

__END__