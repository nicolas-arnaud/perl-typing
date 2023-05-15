#!/usr/bin/perl
# Version: 1.0
# Description: A program to test typing speed and accuracy
#

use strict;
use warnings;

use Term::ReadKey;
use Term::ReadLine;
use List::Util qw( min max sum );
use POSIX qw( strftime );

use Time::HiRes qw( time );
use FindBin qw($RealBin);
use lib "$RealBin/lib";

use wordlists;
use layouts;
use menu;
use metronome;

my $layout_name = "none";
my $wordlist_file = "new";
my $bpm = 0;
my $export_file = "none";

my @words;
my $layout = "";

# if argument is given, use it as the $export_file
if (scalar(@ARGV) eq 1) {
    $export_file = $ARGV[0];
}

main();

sub main {
    print "\e[2J\e[H"; # Clear screen and move cursor to top-left corner
    print "# TYPERL\n\n";
    print " Start test\n";
    print " Select layout ($layout_name)\n";
    print " Select words list ($wordlist_file)\n";
    print " Create words list\n";
    print " Set metronome ($bpm)\n";
    print " Exit\n";

    print "\e[3;0H➡️";
    my $key = menu::menu(0, 5);
    if ($key eq 0) {
        $layout = layouts::get($layout_name);
        @words = wordlists::get($wordlist_file);
        start();
    } elsif ($key eq 1) {
        $layout_name = layouts::choose();
        main();
    } elsif ($key eq 2) {
        $wordlist_file = wordlists::choose();
        main();
    } elsif ($key eq 3) {
        $wordlist_file = wordlists::random_creation();
        main();
    } elsif ($key eq 4) {
        $bpm = metronome::set();
        main();
    } elsif ($key eq 5 or $key eq "q" or $key eq "\e") {
        exit;
    }
}

sub clamp {
    my ($n, $min, $max) = @_;
    return max($min, min($max, $n));
}

sub start {
    my %char_times;
    my %incorrect_chars;
    my $start_time = 0;
    my $char_time = 0;
    my $prev_time = $start_time;
    my $total_time = 0;
    my $total_chars = 0;
    my $correct_chars = 0;
    my $fixed_chars = 0;


    my $metronome_pid = metronome::start($bpm, $RealBin);

    print "\e[2J\e[H";
    if ($layout_name ne "none") {
        print "\e[90m$layout\e[0m\n";
    }

    print "*" x 80 . "\n";
    print "*              Press 'esc' anytime to exit and 'tab' to restart.               *\n";
    print "*" x 80 . "\n";

    my @lines;
    my $n = 0;

    for (my $i = 0; $i < scalar(@words); $i++) {
        if ($i % 10 eq 9 or $i eq scalar(@words) - 1) {
            $lines[$n] .= $words[$i] . "\n";
            $n++;
        } else {
            $lines[$n] .= $words[$i] . " ";
            if (length($lines[$n]) + length($words[$i]) > 80) {
                $lines[$n] =~ s/ $/\\n/;
                $n++;
            }
        }
    }

    print "\e[s"; # Save cursor position
    foreach my $line (@lines) {
        print "$line";
    }
    print "\e[u"; # Restore cursor position

    my $char_input = '';
    my $prev_char = '';
    my $cpm = 0;

    for (my $n = 0; $n < scalar(@lines); $n++) {
        my $line = $lines[$n];
        my $char = '';

        for (my $i = 0; $i < length($line); $i++) {
            $char = substr($line, $i, 1);
            if ($layout_name ne "none") {
                layouts::update($layout, $prev_char, $char, "\e[1;32m");
            }

            $char_input = readChar();

            if ($start_time eq 0) {
                $start_time = time;
                $prev_time = $start_time;
            }

            if ($char_input eq "\e") {
                metronome::stop($metronome_pid);
                # move to the line after the last line
                print "\e[" . (scalar(@lines) - $n) . "B";
                $n = scalar(@lines);
                last;
            } elsif ($char_input eq "\t") {
                metronome::stop($metronome_pid);
                start();
            } elsif ($char_input eq "^H" or $char_input eq "\x7f") {
                $fixed_chars++;
                if ($i eq 0) {
                    if ($n eq 0) {
                        redo;
                    }
                    $n--;
                    $line = $lines[$n];
                    $i = length($line) - 1;
                    print "\e[1A\e[" . $i . "C";
                } else {
                    $i--;
                    print "\e[D";
                    print substr($line, $i, 1);
                    print "\e[D";
                }
                redo;
            } elsif ($char_input eq "\n" and $char ne "\n") {
                redo;
            }

            if (not exists $incorrect_chars{$char}) {
                $incorrect_chars{$char} = 0;
            }
            $total_chars++;
            $char_time = time - $prev_time;
            $total_time = time - $start_time;

            if ($char eq $char_input) {
                if (exists $char_times{$char}) {
                    push @{$char_times{$char}}, $char_time;
                } else {
                    $char_times{$char} = [$char_time];
                }
                if ($char eq "\n") {
                    $char = "↩️\n";
                }
                if ($fixed_chars eq 0) {
                    $cpm = 60 * $total_chars / $total_time;
                    if ($bpm ne 0) {
                        my $ratio = $cpm / ($bpm * 3/2);
                        my $green = clamp(int(255 * $ratio), 0, 255);
                        my $red = clamp(int(255 * (1 - $ratio)), 0, 255);
                        printf "\e[38;2;%d;%d;0m%s\e[0m", $red, $green, $char;
                    } else {
                        print "\e[32m$char\e[0m";
                    }

                } else {
                    print "\e[93m$char\e[0m";
                    $fixed_chars--;
                }
                $correct_chars++;
            } else {
                if ($fixed_chars gt 0) {
                    $fixed_chars--;
                }
                if ($char_input eq " ") {
                    print "\e[31m█\e[0m";
                } else {
                    print "\e[31m$char_input\e[0m";

                }
                if ($char eq "\n") {
                    print " \e[1E\e[1G";
                }
                $incorrect_chars{$char}++;
            }

            $prev_time = time;
            $prev_char = $char;
        }
    }
    
    my $errors = $total_chars - $correct_chars;
    my $accuracy = 100 * ($correct_chars / $total_chars);

    my $wpm = 60 * (scalar(@words) / (time - $start_time));

    print  "\n┌" . "─" x 32 . "┐\n";
    # table : |Time|CPM|WPM|Errors|Accuracy|
    # align values per column
    printf "│%-5s│%-4s│%-5s│%-6s│%-8s│\n",
        "Time", "CPM", "WPM", "Errors", "Accuracy";
    printf "├─────┼────┼─────┼──────┼────────┤\n";
    printf "│%-5s│%-4s│%-5s│%-6s│%-8s│\n",
        sprintf("%.0f", $total_time),
        sprintf("%.0f", $cpm), sprintf("%.0f", $wpm), $errors, sprintf("%.2f", $accuracy) . "%";
    printf "├─────┴────┴─────┴──────┴────────┴─────────────────────────────────────────────┐\n";

    $n = 0;
    my $min_cpm = 2000;
    my $max_cpm = 0;
    export($wpm,$accuracy);
    foreach my $char (sort keys %char_times) {
        my $char_avg_time = sprintf("%.2f", average(@{$char_times{$char}}));

        my $char_cpm = 0;
        if ($char_avg_time ne '0.00') {
            $char_cpm = 60 / $char_avg_time;
        }
        if ($char_cpm < $min_cpm) {
            $min_cpm = $char_cpm;
        }
        if ($char_cpm > $max_cpm) {
            $max_cpm = $char_cpm;
        }
        $n++;

    }

    metronome::stop($metronome_pid);

    # characters table: |Char|CPM|Correct|Total|Accuracy|
    printf "│%-5s│%-4s│%-7s│%-5s│█",
        "Char", "CPM", "Correct", "% Acc";
    printf "│%-5s│%-4s│%-7s│%-5s│█",
        "Char", "CPM", "Correct", "% Acc";
    printf "│%-5s│%-4s│%-7s│%-5s│\n",
        "Char", "CPM", "Correct", "% Acc";

    $n = 0;
    foreach my $char (sort keys %char_times) {
        my $correct = scalar(@{$char_times{$char}});
        my $total = $correct + $incorrect_chars{$char};
        my $char_avg_time = sprintf("%.2f", average(@{$char_times{$char}}));
        my $char_accuracy = sprintf("%.2f", 100 * (1 - ($incorrect_chars{$char} / $total)));

            my $char_cpm = 0;
        if ($char_avg_time ne '0.00') {
            $char_cpm = 60 / $char_avg_time;
        }
        my $color = get_color($cpm, $min_cpm, $max_cpm, $char_cpm, $char_accuracy);
        print $color;
        if  ($layout_name ne "none") {
            layouts::update($layout, $char, $char, $color);
        }

        if ($char eq "\n") {
            $char = "↩️    ";
        } elsif ($char eq " ") {
            $char = "␣    ";
        }

        printf "│%-5s│%-4s│%-7s│%-5s│", 
            sprintf("%-5s", $char),
            sprintf(
                "%.0f", $char_cpm),
            $correct . "/" . $total,
            sprintf("%.1f", $char_accuracy);

        print "\e[0m";

        if ($n % 3 == 2) {
            print "\n";
        } else {
            print "█";
        }
        $n++;
    }
    while ($n % 3 != 0) {
        printf "│%-5s│%-4s│%-7s│%-5s│", " ", " ", " ", " ";
        if ($n % 3 == 2) {
            print "\n";
        } else {
            print "█";
        }
        $n++;
    }
    printf "└─────┴────┴───────┴─────┴┴┴─────┴────┴───────┴─────┴┴┴─────┴────┴───────┴─────┘\n";
    

    print "Press 'tab' to restart or 'esc' to return to main menu.\n";
    while (1) {
        my $key = readChar();

        if ($key eq "\t") {
            start();
        } elsif ($key eq "\e") {
            main();
        }
        last;
    }
}

# Save wpm and accuracy to datas.txt file
# If file doesn't exist, create it and write to first line : time, wpm, accuracy
# If file exists, append to the end of the file : $time, $wpm, $accuracy
# wpm and accuracy are parameters and time is current time
sub export {
    if ($export_file eq "none") {
        return;
    }
    my ($wpm, $accuracy) = @_;
    my $time = strftime("%Y-%m-%d %H:%M:%S", localtime);
    my $data = "$time; $wpm; " . $accuracy / 100 . "\n";
    if (-e $export_file) {
        open(my $fh, '>>', $export_file) or die "Could not open file '$export_file' $!";
        print $fh $data;
        close $fh;
    } else {
        open(my $fh, '>', $export_file) or die "Could not open file '$export_file' $!";
        print $fh "time; wpm; accuracy\n";
        print $fh $data;
        close $fh;
    }
}

# Function to calculate the average of a list of numbers
sub average {
    my $total = 0;
    foreach my $number (@_) {
        $total += $number;
    }
    return $total / scalar(@_);
}

# Function
sub readChar {
    ReadMode('cbreak');
    my $key = Term::ReadKey::ReadKey(0);
    ReadMode(0);
    return $key;
}

sub get_color {
    my ($cpm, $min_cpm, $max_cpm, $key_cpm, $key_acc) = @_;

    $max_cpm = min($max_cpm, $cpm * 2);

    # max > avg > min : green > yellow > red
    # green : 255, 255, 0
    # red : 0, 255, 255

    my $green = min(($key_cpm - $min_cpm) / ($cpm - $min_cpm), 1);
    my $red = 1 - max(($key_cpm - $cpm) / ($max_cpm - $cpm), 0);
    my $green_percent = int($green * (max($key_acc, 90) - 90) * 10);
    my $red_percent = int($red * $key_acc);
    #my $red_percent = int((1 - $cpm_ratio) * 100 );
    # Calculate the color value based on the given parameters

    # Ensure the color values are within the valid range of 0-255
    $green_percent = ($green_percent < 0) ? 0 : ($green_percent > 100) ? 255 : int($green_percent * 2.55);
    $red_percent = ($red_percent < 0) ? 0 : ($red_percent > 100) ? 255 : int($red_percent * 2.55);
    
    #my $red_percent = 255 - int($green_percent / 2);

    # Return the color value
    return "\x1b[38;2;${red_percent};${green_percent};0m";
}
