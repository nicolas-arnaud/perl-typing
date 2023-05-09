use strict;
use warnings;

use JSON;

use lib 'lib';


sub choose_layout {
    print "\e[2J\e[H"; # Clear screen and move cursor to top-left corner
    print "Type-pl\n\n";
    print "Select layout display:\n";
    my $layouts_name = {
        "0" => "new",
        "1" => "qwerty",
        "2" => "dvorak",
        "3" => "colemak",
        "4" => "workman",
        "5" => "norman",
        "6" => "colemak-dhm"
    };
    foreach my $key (sort keys %$layouts_name) {
        my $layout_name = $layouts_name->{$key};
        print "$key. $layout_name\n";
    }

    ReadMode('cbreak');
    my $key = Term::ReadKey::ReadKey(0);
    ReadMode(0);

    return $layouts_name->{$key};
}

sub get_layout {
    my $layout_name = shift;
    my $layout;

    if ($layout_name ne "none") {
        open my $layouts_file, "<", "res/layouts.json" or die "Can't open res/layouts.json: $!";
        my $layouts_json = do { local $/; <$layouts_file> };
        close $layouts_file;

        my $layouts_data = decode_json($layouts_json);
        $layout = $layouts_data->{$layout_name};
    }
    return $layout;
}
1;
