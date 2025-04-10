use strict;
use warnings;
use Test::More;
use FindBin;
# Assuming the script is run from the repo root (e.g., using 'prove -lv t/')
# The plugin's lib directory is relative to the repo root
use lib "$FindBin::Bin/../plugins/TipTapField/lib";

BEGIN {
    use_ok('TipTapField::ContentFieldType::TipTapField');
}

done_testing();
