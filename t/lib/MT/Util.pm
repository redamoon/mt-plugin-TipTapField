package MT::Util;

# Minimal stub to provide a basic encode_html for testing without MT.
# Mimics the pass-through behavior needed for tests.
sub encode_html {
    my ($str) = @_;
    return $str; # Pass-through for testing purposes
}

1; # Required for Perl modules
