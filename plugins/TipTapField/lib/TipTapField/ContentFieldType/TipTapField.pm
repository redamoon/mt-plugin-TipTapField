package TipTapField::ContentFieldType::TipTapField;
use strict;
use warnings;

sub data_load_handler {
    my ( $app, $field_data ) = @_;
    my $id = $field_data->{id};

    my @bodies = $app->multi_param(
        'tiptap-field-' . $field_data->{id} . '-body');
    my @previews = $app->multi_param(
        'tiptap-field-' . $field_data->{id} . '-preview');

    my @val;
    for (my $i = 0; $i < scalar @bodies; $i++ ) {
      push @val,
          {
          body => @bodies[$i],
          preview => @previews[$i]
          };
    }

    return \@val;
}

sub field_html_params {
    my ( $app, $field_data ) = @_;

    my $data = $field_data->{value};
    if ( !defined $data ) {
      push @$data,
        {
          body => '',
          preview => ''
        };
    }
    my $required
        = $field_data->{options}{required} ? 'data-mt-required="1"' : '';

    { tiptap_data => $data,
      required         => $required,
      field_label      => $field_data->{options}{label},
      body_label       => $field_data->{options}{body_label},
      preview_label    => $field_data->{options}{preview_label},
    };
}

sub field_value_handler {
    my ( $ctx, $args, $cond, $field_data, $value ) = @_;
    my $part = lc $args->{part} || 'preview';

    return if ( $part ne 'body' and $part ne 'preview' );

    return $value->{$part};
}

sub tag_handler {
    my ( $ctx, $args, $cond, $field_data, $value ) = @_;
    my $tok     = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my $vars    = $ctx->{__stash}{vars} ||= {};
    my $out     = '';
    my $i       = 1;
    my $glue    = $args->{glue};

    for my $v ( @{$value} ) {
        local $vars->{__first__}   = $i == 1;
        local $vars->{__last__}    = $i == scalar @{$value};
        local $vars->{__odd__}     = ( $i % 2 ) == 1;
        local $vars->{__even__}    = ( $i % 2 ) == 0;
        local $vars->{__counter__} = $i;
        local $vars->{__value__}   = $v;

        defined(
            my $res = $builder->build(
                $ctx, $tok,
                {   %{$cond},
                    ContentFieldHeader => $i == 1,
                    ContentFieldFooter => $i == scalar @$value,
                }
            )
        ) or return $ctx->error( $builder->errstr );

        if ( $res ne '' ) {
            $out .= $glue
                if defined $glue && $i > 1 && length($out) && length($res);
            $out .= $res;
            $i++;
        }
    }

    $out;
}

sub feed_value_handler {
    my ( $app, $field_data, $values ) = @_;

    return '' unless @$values;

    my $contents = '';
    for my $v (@$values) {
      my $encoded_v = MT::Util::encode_html( $v->{preview} );
      my $encoded_t = MT::Util::encode_html( $v->{body} );
      $contents .= "<dt>$encoded_t</dt><dd>$encoded_v</dd>";
    }
    return "<dl>$contents</dl>";
}

sub preview_handler {
  my ( $app, $field_data, $values ) = @_;

  unless ( ref $values eq 'ARRAY' ) {
    $values = [$values];
  }
  return '' unless @$values;

  my $contents = '';
  for my $v (@$values) {
    my $encoded_v = MT::Util::encode_html( $v->{preview} );
    my $encoded_t = MT::Util::encode_html( $v->{body} );
    $contents .= "<dt>$encoded_t</dt><dd>$encoded_v</dd>";
  }
  return "<dl>$contents</dl>";
}

sub replace_handler {
    my ($search_regex, $replace_string, $field_data,
      $values,       $content_data
    ) = @_;
    return 0 unless defined $values;

    $values = [$values] unless ref $values eq 'ARRAY';

    my $replaced = 0;
    for (@$values) {
      $replaced += $_->{body} =~ s!$search_regex!$replace_string!g;
      $replaced += $_->{preview} =~ s!$search_regex!$replace_string!g;
    }

    $replaced > 0;
}

sub search_handler {
    my ( $search_regex, $field_data, $values, $content_data ) = @_;
    return 0 unless defined $values;

    $values = [$values] unless ref $values eq 'ARRAY';

    (   grep {
      defined $_
        ? ( $_->{body} =~ /$search_regex/ )
        || $_->{preview} =~ /$search_regex/
        : 0
    } @$values
    ) ? 1 : 0;
}

1;
