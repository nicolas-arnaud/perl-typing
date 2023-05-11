use strict;
use warnings;

package menu;
use Term::ReadKey;

sub menu {
    my ($min, $max) = @_;
    ReadMode('cbreak');
    my $i = 0;
    while (1) {
        my $key = Term::ReadKey::ReadKey(0);
        if ($key eq "k" and $i > $min) {
            print "\e[2D \e[D\e[A>";
            $i--;
        } elsif ($key eq "j" and $i < $max) {
            print "\e[2D \e[D\e[B>";
            $i++;
        } elsif ($key eq "\n") {
            last;
        }
    }
    ReadMode(0);
    return $i;
}
1;
