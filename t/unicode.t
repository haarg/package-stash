use strict;
use warnings;
use Test::More;

BEGIN { $ENV{PACKAGE_STASH_IMPLEMENTATION} = 'PP' }
use Package::Stash;

my @bits = grep defined, map {
  my $l = my $u = my $e = $_;
  utf8::downgrade($l, 1) or undef $l; # latin1 encoded bytes (utf8 flag off)
  utf8::upgrade($u);                  # unicode character    (utf8 flag on)
  utf8::encode($e);                   # utf8 encoded bytes   (utf8 flag off)
  ((), $u, $e);
} (
  "\xF6",     # ö - within latin1
  "\x{2C6F}", # Ɐ - outside latin1
);

sub stash_entry {
  my $package = shift;
  no strict 'refs';
  my ($key) = grep /^with_.*_char$/, keys %{"${package}::"};
  return $key;
}

sub pretty {
  my $in = shift;
  return $in
    unless defined $in;
  my $utf8 = utf8::is_utf8($in);
  $in =~ s{([^\x00-\x7F])}{
    sprintf ($1 gt "\xFF" ? '\x{%X}' : '\x%X', ord $1)
  }ge;
  return +($utf8 ? 'unicode' : 'native') . qq{ "$in"};
}

sub raw_sub {
  my ($package, $sub) = @_;

  my $code = "package $package;\n";
  if (utf8::is_utf8($sub)) {
    utf8::encode($sub);
    $code .= qq{
      use utf8;
    };
  }
  $code .= qq{
    sub $sub { 1 }
    1;
  };
  eval $code;
  #or die $@;
}

use Devel::Peek;
my $pack = "A000";
for my $bit (@bits) {
  my $package = "Test::Package::".($pack++);

  raw_sub($package, "with_${bit}_char") or next;

  no strict 'refs';
  my @keys = grep { $_ ne 'BEGIN' } sort keys %{$package.'::'};
  Dump(\@keys);
}
done_testing;

__END__

  my $ps = "${package}::PS";
  my $stash = Package::Stash->new($ps);
  my $sub = sub { 1 };
  my $symb = "&with_${bit}_char";
  $stash->add_symbol($symb, $sub);
  is pretty(stash_entry($ps)), pretty(stash_entry($package));
  ok $stash->has_symbol($symb);
  is $stash->get_symbol($symb), $sub;
  is +(grep /^with_.*_char$/, $stash->list_all_symbols)[0], stash_entry($package);
  is +(grep /^with_.*_char$/, $stash->list_all_symbols('CODE'))[0], stash_entry($package);
  is +(grep /^with_.*_char$/, keys %{ $stash->get_all_symbols })[0], stash_entry($package);
  is +(grep /^with_.*_char$/, keys %{ $stash->get_all_symbols('CODE') })[0], stash_entry($package);
  $stash->remove_glob("with_${bit}_char");
  is pretty(stash_entry($ps)), undef;
}

done_testing;

__END__


for my $bit (@bits) {
  $pack++;
  my $package = "Test::Package::${pack}::With::${bit}::Char";

  my $full_glob = eval qq{
    no strict 'refs';
    *{"${package}::full_glob"} = sub { 1 };
    "${package}";
  };

  my $raw = eval qq{
    package ${package};
    sub raw { 1 }
    __PACKAGE__;
  };

  my $ps = $package;
  my $stash = Package::Stash->new($ps);
  my $sub = sub { 1 };
  ok $stash->get_symbol('&full_glob');
  ok $stash->get_symbol('&raw')
    if $raw;
  ok $stash->has_symbol('&full_glob');
  ok $stash->has_symbol('&raw')
    if $raw;

  $stash->add_symbol('&with_a_char', $sub);
  is stash_entry($ps), 'with_a_char';

  is '&'.(grep /^with_.*_char$/, $stash->list_all_symbols)[0], '&with_a_char';
  is '&'.(grep /^with_.*_char$/, $stash->list_all_symbols('CODE'))[0], '&with_a_char';
  is '&'.(grep /^with_.*_char$/, keys %{ $stash->get_all_symbols })[0], '&with_a_char';
  is '&'.(grep /^with_.*_char$/, keys %{ $stash->get_all_symbols('CODE') })[0], '&with_a_char';
  $stash->remove_symbol("&with_a_char");
  is stash_entry($ps), undef;
}



done_testing;
