use strict;
use warnings;

my %list;
while (<STDIN>) {
    chomp;
    if ( exists( $list{$_} ) ) {
        $list{$_}++;
    }
    else {
        $list{$_} = 1;
    }
}

my ($t1,$t5,$t10,$t50,$t100,$tm)=(0,0,0,0,0,0);
foreach my $k (keys(%list)){
    if ( $list{$k}==1){
        $t1++;
    }elsif($list{$k}<=5){
        $t5++;
    }elsif($list{$k}<=10){
        $t10++;
    }elsif($list{$k}<=50){
        $t50++;
    }elsif($list{$k}<=100){
        $t100++;
    }elsif($list{$k}>100){
        $tm++;
    }
}
print("1:\t$t1\n");
print("2-5:\t$t5\n");
print("6-10:\t$t10\n");
print("11-50:\t$t50\n");
print("51-100:\t$t100\n");
print(">100:\t$tm\n");

__END__