use strict;
use warnings;

use JSON;
use List::Util qw( max );

use lib 'lib';

sub choose_layout {
    print "\e[2J\e[H"; # Clear screen and move cursor to top-left corner
    open my $layouts_file, "<", "res/layouts.json" or die "Can't open res/layouts.json: $!";
    my $layouts_json = do { local $/; <$layouts_file> };
    close $layouts_file;

    my $layouts_data = decode_json($layouts_json);

    # Choose layout type which are the root keys of the json file (3rows, 4rows, etc.)
    print "\e[2J\e[H"; # Clear screen and move cursor to top-left corner
    print "LAYOUT FAMILY SELECTION:\n\n";

    my @layout_families = keys %{$layouts_data};
    my $n = 1;
    foreach my $layout_family (@layout_families) {
        print "$n. $layout_family\n";
        $n++;
    }

    ReadMode('cbreak');
    my $key = Term::ReadKey::ReadKey(0);

    my $layout_family = $layout_families[scalar $key-1];

    if ($layout_family eq "none") {
        return "none";
    }


    print "\e[2J\e[H"; # Clear screen and move cursor to top-left corner
    print "LAYOUT SELECTION:\n";

    my @layout_names = keys %{$layouts_data->{$layout_family}};
    $n = 1;
    foreach my $layout_name (@layout_names) {
        print "$n. $layout_name\n";
        $n++;
    }

    $key = Term::ReadKey::ReadKey(0);
    ReadMode(0);

    my $layout_name = $layout_names[scalar $key-1];
    return join "", $layout_family, "/", $layout_name;
}

sub get_layout {
    my $layout_info = $_[0];
    my ($layout_family, $layout_name) = split /\//, $layout_info;
    my $layout;

    if ($layout_name ne "none") {
        open my $layouts_file, "<", "res/layouts.json" or die "Can't open res/layouts.json: $!";
        my $layouts_json = do { local $/; <$layouts_file> };
        close $layouts_file;

        my $layouts_data = decode_json($layouts_json);
        my $layers = $layouts_data->{$layout_family}->{$layout_name};

        # Join the layers into a single string
        # by removing newlines and adding a space for each not last layer
        # to separate the layers. Each layer must stay alligned vertically.

        my @lines;

        foreach my $layer (@$layers) {
            my $n = 0;
            my $spaces_amount = max(map { length($_) } split /\n/, $layer) + 5;
            my @lines_tmp = split /\n/, $layer;
            foreach my $line (@lines_tmp) {
                $lines[$n] .= $line . " " x ($spaces_amount - length($line));
                $n++;
            }
        }
        foreach my $line (@lines) {
            $layout .= $line . "\n";
        }

    }
    return $layout;
}

sub update_layer {
    my ($layout, $char, $prev) = @_;

    print "\e[s"; # Save the current cursor position

    my ($row, $col) = find_key_pos($prev, $layout);
    if ($row < 0) {
        # Character not found
        return;
    }

    print "\e[${row};${col}H";
    # Display the character in black
    print "\e[90m$prev\e[0m";

    # Move the cursor to the position of the character in the layout
    ($row, $col) = find_key_pos($char, $layout);
    print "\e[${row};${col}H";
    # Display the character in bold green
    print "\e[1;32m$char\e[0m";

    print "\e[u";# Move the cursor back to the saved position
}

sub find_key_pos {
    # take to lower character
    my $char = $_[0];
    my $layout = $_[1];

    my @lines = split /\n/, $layout;
    my $row = 1;
    my $col = 0;
    

    foreach my $line (@lines) {
        $col = index($line, $char);
        if ($col >= 0) {
            last;
        }
        $row++;
    }

    if ($col < 0) {
        # Character not found
        return (undef, undef);
    } else {
        return ($row, $col+1); # Add 1 to column to account for 0-based indexing
    }
}
1;
