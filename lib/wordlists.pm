use strict;
use warnings;

package wordlists;

use Term::ReadKey;
use Term::ReadLine;
use Term::ReadLine::Gnu;

use menu;

use FindBin qw($RealBin);
my $res = "$RealBin/res";

sub choose {
    print "\e[2J\e[H"; # Clear screen and move cursor to top-left corner
    print "# Select word list:\n\n";
    my @lists = glob("$res/lists/*.txt");
    print " New list\n";
    for (my $i = 0; $i < scalar(@lists); $i++) {
        my $list = $lists[$i];
        $list =~ s/$res\/lists\///;
        $list =~ s/\.txt//;
        $lists[$i] = $list;
        print " $list\n";
    }

    print "\e[3;0H>";

    my $i = menu::menu(0, scalar(@lists));
    if ($i eq 0) {
        return "new";
    }
    return $lists[$i - 1];
}

sub get {
    my $wordlist_file = $_[0];
    my @words;
    if ($wordlist_file ne "new") {
        open TEXT, "<", "$res/lists/$wordlist_file.txt" or die "Can't open $wordlist_file: $!";
    } else {
        print "\e[2J\e[H"; # Clear screen and move cursor to top-left corner
        print "# Select word list type:\n\n";
        print " Common words\n";
        print " Randomized\n";
        print "\e[3;0H>";
        my $i = menu::menu(0, 1);

        if ($i eq 0) {
            $wordlist_file = words_creation();
        } else {
            $wordlist_file = random_creation();
        }
        open TEXT, "<", "$res/lists/$wordlist_file.txt" or die "Can't open res/lists/$wordlist_file.txt: $!";
    }
    @words = <TEXT>;
    close TEXT;
    chomp @words;
    @words = grep { $_ ne '' } @words;

    return @words;
}

my $term = Term::ReadLine->new('answer');
my $attribs = $term->Attribs;
$attribs->{stty} = "erase \b";

my $enclosures = [
    "[", "]",
    "{", "}",
    "<", ">",
    "(", ")",
    "|", "|",
    "/", "/",
    "\"", "\"",
    "www.", ".com",
    "http://", ".com",
    "for(", ")",
    "/*", "*/",
    "", "[5]",
    "*", "",
    "\$", ";",
    "if(", "){}"
];

# choose random words from "./1000-most-common-words.txt"
sub words_creation {
    print "\e[2J\e[H"; # Clear screen and move cursor to top-left corner
    print "Random words generator:\n\n";

    print "Enter number of words (50):\n";
    my $words_amount = $term->readline('> ');
    chomp $words_amount;
    if ($words_amount !~ /^[0-9]+$/ || $words_amount < 1) {
        $words_amount = 50;
    }

    open(my $fh, '<', "$res/1000-most-common-words.txt") or die "Could not open file 'res/1000-most-common-words.txt' $!";
    my @words = <$fh>;
    close $fh;

    my $wordlist = "";
    my $word;
    for (my $i = 0; $i < $words_amount; $i++) {
        $word = $words[int(rand(scalar(@words)))];
        $word =~ s/\s//g;
        $wordlist .= $word . "\n";
    }
    open($fh, '>', "$res/lists/tmp.txt") or die "Could not open file 'res/lists/new.txt' $!";
    print $fh $wordlist;
    close $fh;
    return "tmp";

}

sub random_creation {
    print "\e[2J\e[H"; # Clear screen and move cursor to top-left corner
    print "Random words generator:\n\n";

    print "Enter number of words (50):\n";
    my $words_amount = $term->readline('> ');
    chomp $words_amount;
    if ($words_amount !~ /^[0-9]+$/ || $words_amount < 1) {
        print "Invalid input, setting to 50\n";
        $words_amount = 50;
    }

    print "Enter average words length: (5)\n";
    my $avg_word_size = $term->readline('> ');
    chomp $avg_word_size;
    if ($avg_word_size !~ /^[0-9]+$/ || $avg_word_size < 1) {
        print "Invalid input, setting to 5\n";
        $avg_word_size = 5;
    }

    print "Enter charset: (all latin alpha)\n";
    my $charset = $term->readline('> ');
    chomp $charset;
    if ($charset eq "") {
        print "Setting to all latin alpha\n";
        $charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    }

    print "Enter difficulty (0):\n";
    my $difficulty = $term->readline('> ');
    chomp $difficulty;
    if ($difficulty !~ /^[0-9]+$/ || $difficulty < 0 || $difficulty > 10) {
        print "Invalid input, setting to 0\n";
        $difficulty = 0;
    }

    print "Enter file name:\n";
    my $file_name = $term->readline('> ');
    chomp $file_name;
    if ($file_name eq "") {
        print "Invalid input, setting to random\n";
        $file_name = "random";
    }

    # calculate the standard deviation of the distribution
    my $sigma = $avg_word_size / 3;

    # generate a probability distribution for the word sizes
    my %probabilities;
    my $total_probability = 0;
    for (my $size = 1; $size <= $avg_word_size; $size++) {
        my $probability = exp(-(($size - $avg_word_size) ** 2) / (2 * $sigma ** 2));
        $total_probability += $probability;
        $probabilities{$size} = $probability;
    }

    # normalize the probabilities to ensure that they sum to 1
    foreach my $size (keys %probabilities) {
        $probabilities{$size} /= $total_probability;
    }

    # generate words with random sizes and characters from the given set
    my @words;
    my $total_size = 0;
    while ($total_size < $words_amount) {
        my $size = 0;
        my $random = rand();
        my $cumulative_probability = 0;
        foreach my $word_size (sort { $a <=> $b } keys %probabilities) {
            $cumulative_probability += $probabilities{$word_size};
            if ($random < $cumulative_probability) {
                $size = $word_size;
                last;
            }
        }
        my $word = "";
        for (my $i = 0; $i < $size; $i++) {
            my $random_index = int(rand(length($charset)));
            my $random_char = substr($charset, $random_index, 1);
            $word .= $random_char;
        }
        $word = enclose($word, $difficulty);
        push @words, $word;
        $total_size ++; # add 1 for the space between words
    }

    # join the words into a single string with one space in between
    my $random_string = shift @words;


    foreach my $word (@words) {
        $random_string .= rand() < $difficulty / 16 ? random_space() : "\n";
        $random_string .= $word;
    }

    print "$random_string\n";
    # write the string to the file word_lists/$file_name.txt
    open(my $fh, '>', "$res/lists/$file_name.txt") or die "Could not open file 'res/lists/$file_name.txt' $!";
    print $fh $random_string;
    close $fh;
    return $file_name;


}
sub enclose {
    my ($word, $difficulty) = @_;
    if (rand() < $difficulty / 8) {
        my $random_index = int(rand(scalar(@$enclosures/2))) * 2;
        my $s_enclose = $enclosures->[$random_index];
        my $e_enclose = $enclosures->[$random_index + 1];
        return $s_enclose . $word . $e_enclose;
    }
    return $word;
}

sub random_space {
    my $spaces = ["->", "=>", ".", "::"];
    return $spaces->[int(rand(scalar(@$spaces)))];
}
