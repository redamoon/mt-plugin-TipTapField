use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Test::MockModule;
use FindBin;
# Assuming the script is run from the repo root
use lib "$FindBin::Bin/../plugins/TipTapField/lib";

# Check if MT::Util can be loaded to potentially use its real encode_html
# If not, the simple pass-through mock will be used.
my $can_load_mt_util = eval { require MT::Util; 1 };

use TipTapField::ContentFieldType::TipTapField;

# Mock MT::Util globally for simplicity, decide based on whether it loaded
my $mt_util_mock = Test::MockModule->new('MT::Util');
if ($can_load_mt_util) {
    # If MT::Util is available, use its real encode_html for more accurate tests
    # (though it might not be fully functional without a full MT env)
    $mt_util_mock->mock('encode_html', sub { MT::Util::encode_html(@_) });
} else {
    # Fallback: Simple mock that just returns the input if MT::Util is not found
    $mt_util_mock->mock('encode_html', sub { shift });
}


subtest 'data_load_handler tests' => sub {
    my $mock_app = Test::MockObject->new();
    $mock_app->mock('multi_param', sub {
        my ($self, $param_name) = @_;
        # Simulate receiving multiple values for body and preview
        return ('body1', 'body2') if $param_name eq 'tiptap-field-123-body';
        return ('preview1', 'preview2') if $param_name eq 'tiptap-field-123-preview';
        return ();
    });

    my $field_data = { id => 123 };
    my $expected = [
        { body => 'body1', preview => 'preview1' },
        { body => 'body2', preview => 'preview2' },
    ];

    my $result = TipTapField::ContentFieldType::TipTapField::data_load_handler($mock_app, $field_data);
    is_deeply($result, $expected, 'data_load_handler returns correct structure for multiple values');

    # Test case: Single value
    my $mock_app_single = Test::MockObject->new();
     $mock_app_single->mock('multi_param', sub {
        my ($self, $param_name) = @_;
        return ('body_single') if $param_name eq 'tiptap-field-456-body';
        return ('preview_single') if $param_name eq 'tiptap-field-456-preview';
        return ();
    });
    my $field_data_single = { id => 456 };
    my $expected_single = [ { body => 'body_single', preview => 'preview_single' } ];
    my $result_single = TipTapField::ContentFieldType::TipTapField::data_load_handler($mock_app_single, $field_data_single);
    is_deeply($result_single, $expected_single, 'data_load_handler handles single value');

    # Test case: No values
    my $mock_app_none = Test::MockObject->new();
    $mock_app_none->mock('multi_param', sub { return () });
    my $field_data_none = { id => 789 };
    my $expected_none = [];
    my $result_none = TipTapField::ContentFieldType::TipTapField::data_load_handler($mock_app_none, $field_data_none);
    is_deeply($result_none, $expected_none, 'data_load_handler handles no values');
};


subtest 'field_html_params tests' => sub {
    # Test case 1: Value provided, not required
    my $field_data1 = {
        id => 1,
        value => [{ body => 'b1', preview => 'p1' }],
        options => { required => 0, label => 'Field', body_label => 'Body', preview_label => 'Preview' }
    };
    my $expected1 = {
        tiptap_data => [{ body => 'b1', preview => 'p1' }],
        required => '',
        field_label => 'Field',
        body_label => 'Body',
        preview_label => 'Preview',
    };
    my $result1 = TipTapField::ContentFieldType::TipTapField::field_html_params(undef, $field_data1); # $app not used
    is_deeply($result1, $expected1, 'field_html_params with value, not required');

    # Test case 2: Value undefined, required
    my $field_data2 = {
        id => 2,
        value => undef,
        options => { required => 1, label => 'Field2', body_label => 'Body2', preview_label => 'Preview2' }
    };
    my $expected2 = {
        tiptap_data => [{ body => '', preview => '' }],
        required => 'data-mt-required="1"',
        field_label => 'Field2',
        body_label => 'Body2',
        preview_label => 'Preview2',
    };
    my $result2 = TipTapField::ContentFieldType::TipTapField::field_html_params(undef, $field_data2);
    is_deeply($result2, $expected2, 'field_html_params without value, required');

    # Test case 3: Empty value array, not required
    my $field_data3 = {
        id => 3,
        value => [],
        options => { required => 0, label => 'Field3', body_label => 'Body3', preview_label => 'Preview3' }
    };
    # The code currently pushes a default empty hash if value is undef, but not if it's an empty array ref.
    # Let's test the current behavior. If the desired behavior is different, the code needs changing.
    my $expected3 = {
        tiptap_data => [],
        required => '',
        field_label => 'Field3',
        body_label => 'Body3',
        preview_label => 'Preview3',
    };
    my $result3 = TipTapField::ContentFieldType::TipTapField::field_html_params(undef, $field_data3);
    is_deeply($result3, $expected3, 'field_html_params with empty array value, not required');
};


subtest 'field_value_handler tests' => sub {
    my $value = { body => 'test body', preview => 'test preview' };
    my $result_body = TipTapField::ContentFieldType::TipTapField::field_value_handler(undef, { part => 'body' }, undef, undef, $value);
    is($result_body, 'test body', 'field_value_handler returns body');

    my $result_preview = TipTapField::ContentFieldType::TipTapField::field_value_handler(undef, { part => 'preview' }, undef, undef, $value);
    is($result_preview, 'test preview', 'field_value_handler returns preview');

    my $result_default = TipTapField::ContentFieldType::TipTapField::field_value_handler(undef, {}, undef, undef, $value);
    is($result_default, 'test preview', 'field_value_handler returns preview by default when part is missing');

    my $result_undef_part = TipTapField::ContentFieldType::TipTapField::field_value_handler(undef, { part => undef }, undef, undef, $value);
    is($result_undef_part, 'test preview', 'field_value_handler returns preview by default when part is undef');

    my $result_invalid = TipTapField::ContentFieldType::TipTapField::field_value_handler(undef, { part => 'invalid' }, undef, undef, $value);
    is($result_invalid, undef, 'field_value_handler returns undef for invalid part');

    my $result_case = TipTapField::ContentFieldType::TipTapField::field_value_handler(undef, { part => 'BODY' }, undef, undef, $value);
    is($result_case, 'test body', 'field_value_handler handles uppercase part');
};


subtest 'tag_handler tests' => sub {
    my $mock_builder = Test::MockObject->new();
    $mock_builder->mock('build', sub {
        my ($self, $ctx, $tokens, $cond) = @_;
        # Simple mock: return the value from __value__ based on counter
        my $val = $ctx->stash('vars')->{__value__};
        my $counter = $ctx->stash('vars')->{__counter__};
        # Simulate checking ContentFieldHeader/Footer
        my $header = $cond->{ContentFieldHeader} ? "H" : "";
        my $footer = $cond->{ContentFieldFooter} ? "F" : "";
        return "Built: " . $val->{body} . " ($counter)$header$footer";
     });
    $mock_builder->mock('errstr', sub { "Builder error" });

    my $mock_ctx = Test::MockObject->new();
    my %stash = ( builder => $mock_builder, tokens => {}, vars => {} );
    $mock_ctx->mock('stash', sub {
        my ($self, $key) = @_;
        # Need to handle nested vars access correctly
        if ($key eq 'vars') {
            $stash{vars} //= {};
            return $stash{vars};
        }
        return $stash{$key} if exists $stash{$key};
        return undef;
    });
     # Add a way to access the internal stash for testing setup
    $mock_ctx->mock('_get_stash_ref', sub { \%stash });
    # Mock error method
    $mock_ctx->mock('error', sub { die "CTX ERROR: $_[1]" });


    my $value = [ { body => 'b1' }, { body => 'b2' } ];
    my $args_no_glue = {};
    my $args_glue = { glue => '--' };
    my $cond = {}; # Empty condition hash

    # Reset vars for each call
    $mock_ctx->_get_stash_ref->{vars} = {};
    my $result_no_glue = TipTapField::ContentFieldType::TipTapField::tag_handler($mock_ctx, $args_no_glue, $cond, undef, $value);
    is($result_no_glue, 'Built: b1 (1)HBuilt: b2 (2)F', 'tag_handler without glue');

    $mock_ctx->_get_stash_ref->{vars} = {};
    my $result_glue = TipTapField::ContentFieldType::TipTapField::tag_handler($mock_ctx, $args_glue, $cond, undef, $value);
    is($result_glue, 'Built: b1 (1)H--Built: b2 (2)F', 'tag_handler with glue');

    # Test single value
    my $value_single = [ { body => 'single' } ];
    $mock_ctx->_get_stash_ref->{vars} = {};
    my $result_single = TipTapField::ContentFieldType::TipTapField::tag_handler($mock_ctx, $args_no_glue, $cond, undef, $value_single);
    is($result_single, 'Built: single (1)HF', 'tag_handler with single value');

    # Test empty value
    my $value_empty = [];
    $mock_ctx->_get_stash_ref->{vars} = {};
    my $result_empty = TipTapField::ContentFieldType::TipTapField::tag_handler($mock_ctx, $args_no_glue, $cond, undef, $value_empty);
    is($result_empty, '', 'tag_handler with empty value array');

    # Test error case
    $mock_builder->mock('build', sub { undef }); # Simulate build error
    eval { TipTapField::ContentFieldType::TipTapField::tag_handler($mock_ctx, $args_no_glue, $cond, undef, $value) };
    like($@, qr/CTX ERROR: Builder error/, 'tag_handler handles builder error');
    $mock_builder->unmock('build'); # Restore mock
};


subtest 'feed_value_handler tests' => sub {
    my $values = [ { body => '<b>Body</b>', preview => '<p>Preview</p>' } ];
    # Determine expected based on whether MT::Util::encode_html was loaded and mocked realistically
    my $expected;
    if ($can_load_mt_util) {
         # Assumes MT::Util::encode_html works as expected
        $expected = '<dl><dt>&lt;b&gt;Body&lt;/b&gt;</dt><dd>&lt;p&gt;Preview&lt;/p&gt;</dd></dl>';
    } else {
        # Assumes pass-through mock
        $expected = '<dl><dt><b>Body</b></dt><dd><p>Preview</p></dd></dl>';
    }
    my $result = TipTapField::ContentFieldType::TipTapField::feed_value_handler(undef, undef, $values);
    is($result, $expected, 'feed_value_handler generates correct HTML');

    # Test multiple values
    my $values_multi = [ { body => 'B1', preview => 'P1' }, { body => 'B2', preview => 'P2' } ];
    my $expected_multi;
     if ($can_load_mt_util) {
        $expected_multi = '<dl><dt>B1</dt><dd>P1</dd><dt>B2</dt><dd>P2</dd></dl>';
     } else {
        $expected_multi = '<dl><dt>B1</dt><dd>P1</dd><dt>B2</dt><dd>P2</dd></dl>'; # No encoding needed here
     }
    my $result_multi = TipTapField::ContentFieldType::TipTapField::feed_value_handler(undef, undef, $values_multi);
    is($result_multi, $expected_multi, 'feed_value_handler handles multiple values');

    # Test empty values
    my $values_empty = [];
    my $result_empty = TipTapField::ContentFieldType::TipTapField::feed_value_handler(undef, undef, $values_empty);
    is($result_empty, '', 'feed_value_handler returns empty string for empty array');

    # Test undef values
    my $values_undef;
    my $result_undef = TipTapField::ContentFieldType::TipTapField::feed_value_handler(undef, undef, $values_undef);
    is($result_undef, '', 'feed_value_handler returns empty string for undef');
};


subtest 'preview_handler tests' => sub {
    my $values = [ { body => 'Body1', preview => 'Preview1' }, { body => 'Body2', preview => 'Preview2' } ];
    my $expected;
    if ($can_load_mt_util) {
        $expected = '<dl><dt>Body1</dt><dd>Preview1</dd><dt>Body2</dt><dd>Preview2</dd></dl>'; # No encoding needed
    } else {
        $expected = '<dl><dt>Body1</dt><dd>Preview1</dd><dt>Body2</dt><dd>Preview2</dd></dl>';
    }
    my $result = TipTapField::ContentFieldType::TipTapField::preview_handler(undef, undef, $values);
    is($result, $expected, 'preview_handler generates correct HTML for multiple values');

    # Test single hash ref value (not array ref)
    my $single_value = { body => 'SingleB', preview => 'SingleP' };
    my $expected_single;
    if ($can_load_mt_util) {
        $expected_single = '<dl><dt>SingleB</dt><dd>SingleP</dd></dl>';
    } else {
        $expected_single = '<dl><dt>SingleB</dt><dd>SingleP</dd></dl>';
    }
    my $result_single = TipTapField::ContentFieldType::TipTapField::preview_handler(undef, undef, $single_value);
    is($result_single, $expected_single, 'preview_handler handles single hash ref value');

    # Test empty values
    my $values_empty = [];
    my $result_empty = TipTapField::ContentFieldType::TipTapField::preview_handler(undef, undef, $values_empty);
    is($result_empty, '', 'preview_handler returns empty string for empty array');

    # Test undef values
    my $values_undef;
    my $result_undef = TipTapField::ContentFieldType::TipTapField::preview_handler(undef, undef, $values_undef);
    is($result_undef, '', 'preview_handler returns empty string for undef');
};


subtest 'replace_handler tests' => sub {
    my $values = [ { body => 'hello world', preview => 'world preview' } ];
    my $search = qr/world/;
    my $replace = 'planet';
    my $replaced = TipTapField::ContentFieldType::TipTapField::replace_handler($search, $replace, undef, $values, undef);
    ok($replaced, 'replace_handler returns true when replacement occurs');
    my $expected_values = [ { body => 'hello planet', preview => 'planet preview' } ];
    is_deeply($values, $expected_values, 'replace_handler modifies values correctly');

    # Test no match
    my $values_no_match = [ { body => 'hello there', preview => 'general kenobi' } ];
    my $replaced_no_match = TipTapField::ContentFieldType::TipTapField::replace_handler($search, $replace, undef, $values_no_match, undef);
    ok(!$replaced_no_match, 'replace_handler returns false when no replacement occurs');
    my $expected_no_match = [ { body => 'hello there', preview => 'general kenobi' } ];
    is_deeply($values_no_match, $expected_no_match, 'replace_handler does not modify values on no match');

    # Test replacement in only one field
    my $values_one_field = [ { body => 'hello world', preview => 'no match here' } ];
    my $replaced_one_field = TipTapField::ContentFieldType::TipTapField::replace_handler($search, $replace, undef, $values_one_field, undef);
    ok($replaced_one_field, 'replace_handler returns true when replacement occurs in only one field');
    my $expected_one_field = [ { body => 'hello planet', preview => 'no match here' } ];
    is_deeply($values_one_field, $expected_one_field, 'replace_handler modifies only matching field');

    # Test multiple replacements in one value hash
    my $values_multi_replace = [ { body => 'world world', preview => 'world' } ];
    my $replaced_multi = TipTapField::ContentFieldType::TipTapField::replace_handler($search, $replace, undef, $values_multi_replace, undef);
    ok($replaced_multi, 'replace_handler returns true for multiple replacements');
    my $expected_multi_replace = [ { body => 'planet planet', preview => 'planet' } ];
    is_deeply($values_multi_replace, $expected_multi_replace, 'replace_handler handles multiple replacements within value');

    # Test single hash ref value
    my $single_value = { body => 'world', preview => 'world' };
    my $replaced_single = TipTapField::ContentFieldType::TipTapField::replace_handler($search, $replace, undef, $single_value, undef);
    ok($replaced_single, 'replace_handler handles single hash ref value');
    my $expected_single = { body => 'planet', preview => 'planet' };
    is_deeply($single_value, $expected_single, 'replace_handler modifies single hash ref value');
};


subtest 'search_handler tests' => sub {
    my $values = [ { body => 'find me', preview => 'or find me here' }, { body => 'nothing', preview => 'interesting' } ];
    my $search_found_body = qr/find me$/; # Match only body
    my $found_body = TipTapField::ContentFieldType::TipTapField::search_handler($search_found_body, undef, $values, undef);
    ok($found_body, 'search_handler returns true when match found in body');

    my $search_found_preview = qr/me here/;
    my $found_preview = TipTapField::ContentFieldType::TipTapField::search_handler($search_found_preview, undef, $values, undef);
    ok($found_preview, 'search_handler returns true when match found in preview');

    my $search_not_found = qr/banana/;
    my $not_found = TipTapField::ContentFieldType::TipTapField::search_handler($search_not_found, undef, $values, undef);
    ok(!$not_found, 'search_handler returns false when no match found');

    # Test single hash ref value
    my $single_value = { body => 'find this', preview => 'not this' };
    my $search_single = qr/find this/;
    my $found_single = TipTapField::ContentFieldType::TipTapField::search_handler($search_single, undef, $single_value, undef);
    ok($found_single, 'search_handler handles single hash ref value (match)');

    my $search_single_no = qr/banana/;
    my $not_found_single = TipTapField::ContentFieldType::TipTapField::search_handler($search_single_no, undef, $single_value, undef);
    ok(!$not_found_single, 'search_handler handles single hash ref value (no match)');

    # Test undef value in array
    my $values_with_undef = [ { body => 'find me', preview => 'here' }, undef, { body => 'nothing', preview => 'interesting' } ];
    my $found_with_undef = TipTapField::ContentFieldType::TipTapField::search_handler($search_found_body, undef, $values_with_undef, undef);
    ok($found_with_undef, 'search_handler handles undef elements in array');
};

# Finalize the test file
done_testing();
