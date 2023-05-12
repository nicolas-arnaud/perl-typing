use strict;
use warnings;

use File::Which;
use File::Which qw(which);
use Time::HiRes qw(usleep);

package metronome;

sub start {
    my $bpm = $_[0];
    my $dir = $_[1];

    if ($bpm eq 0) {
        return;
    }

    my $paplay_path = File::Which::which('paplay');
    my $pid = fork();

    if ($pid == 0) {
        while (1) {
            system $paplay_path, "$dir/res/metronome.oga"; 
            Time::HiRes::usleep(60000000 / $bpm);
        }
        exit;
    }
    return $pid;
}

sub set {
    print "\e[2J\e[H"; # Clear screen and move cursor to top-left corner
    print "# Set metronome\n\n";
    print " BPM: ";
    my $bpm = <STDIN>;
    chomp $bpm;
    return $bpm;
}

sub stop {
    my $pid = $_[0];
    kill 9, $pid;
}
1;
