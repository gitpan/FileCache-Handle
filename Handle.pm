# Copyright (c) 2005 Joseph Walton
# All rights reserved
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package FileCache::Handle;

# A FileCache, using IO::Handle instances

use strict;

our $VERSION = '0.001';

use IO::Handle;
our @ISA = ('IO::Handle');

use Symbol;
use IO::File;

# The maximum number of files to keep open
my $MAX = 1024;

# The current instances with a live file open
my @real;

sub showReal()
{
	print '[', join(',', map { $_ || '' } @real),"]\n";
}

sub new($)
{
	my $class = shift;
	my $self = $class->SUPER::new();

	tie *$self, $self;

	my $path = shift;

	*$self->{'path'} = $path;
	*$self->{'real'} = undef;
	*$self->{'initial'} = 1;

	$self->open() or die;

	$self;
}

sub TIEHANDLE
{
	return $_[0] if ref($_[0]);

	my $class = shift;

	my $self = bless Symbol::gensym(), $class;

	return $self;
}

sub open
{
	my $self = shift;
	$self;
}

use overload (
	'""' => \&_stringify
);

sub _allocate()
{
	my $self = shift;

	if (!defined(*$self->{'real'})) {
		if (@real >= $MAX) {
			my $d = shift(@real);
			*$d->{'real'}->close();
			*$d->{'real'} = undef;
			*$d->{'initial'} = 0;
		}
		push @real, $self;

		my $f;
		if (*$self->{'initial'}) {
			$f = new IO::File(*$self->{'path'}, '>');
		} else {
			$f = new IO::File(*$self->{'path'}, '>>');
		}
		if (*$self->{'binmode'}) {
			binmode($f, *$self->{'binmode'});
		}
		*$self->{'real'} = $f;
	} else {
		# XXX Should move $self to the head of @real, for LRU behaviour
	}

	return *$self->{'real'};
}

sub print
{
	shift->PRINT(@_);
}

sub PRINT
{
	my $self = shift;

	$self->_allocate()->print(@_);
}

sub BINMODE
{
	my $self = shift;
	my $bm = shift;

	*$self->{'binmode'} = $bm;

	if (defined(*$self->{'real'})) {
		return binmode(*$self->{'real'}, $bm);
	} else {
		return 1;
	}
}

sub _stringify()
{
	my $self = shift;
	return ref($self) . '@' . *$self->{'path'};
}

1;
__END__

=head1 NAME

FileCache::Handle - A FileCache using IO::Handle instances

=head1 SYNOPSIS

  use FileCache::Handle;

  $FileCache::Handle::MAX = 16;

  my @a;
  for (my $i = 0 ; $i < 100 ; $i++) {
    my $o = new FileCache::Handle("/tmp/$i");

    binmode($o, ':utf8');
    push @a, $o;
  }

  for (my $i = 0 ; $i < 3 ; $i++) {
    foreach my $o (@a) {
      print $o "Output ",$o," $i\n";
    }
  }

=head1 DESCRIPTION

FileCache::Handle, like FileCache, avoids OS-imposed limits on the number
of simultaneously open files. Instances behave like file handles and,
behind the scenes, real files are opened and closed as necessary.
FileCache::Handle uses instances of IO::Handle, and so works well with
'use strict'.

=head1 NOTES

The only operations supported are 'print' and 'binmode'. To add more,
create a glue method that delegates the call to the handle returned by
'_allocate()'.

=head1 AUTHOR

Joseph Walton <joe@kafsemo.org>

=head1 COPYRIGHT

Copyright (c) 2005 Joseph Walton
