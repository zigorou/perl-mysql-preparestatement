package MySQL::PreparedStatement;

use strict;
use warnings;

use Carp;
use Class::Accessor::Lite (
    new => 0,
    rw => [qw/name statement server_prepare _queries _binds/],
);
use DBI qw(:sql_types);
use List::MoreUtils qw(first_index);
use SQL::Tokenizer qw(tokenize_sql);
use String::Random qw(random_regex);

our $VERSION = '0.01';
our @NON_QUOTE_TYPES = (
    SQL_TINYINT, SQL_BIGINT,
    SQL_NUMERIC .. SQL_DOUBLE,
);

sub prepare {
    my ($class, $statement, $opts) = @_;

    $opts ||= {};
    %$opts = (
        name => random_regex('\w{4,10}'),
        server_prepare => 0,
        ( %$opts ),
        statement => $statement,
        _queries => [],
        _binds => [],
    );

    my $self = bless $opts => $class;

    if ($self->{server_prepare}) {
        $self->_push_query( $self->_make_prepare_query );
    }
    $self;
}

sub bind_param {
    my ($self, $num, $bind_value, $opts) = @_;

    if ($num - 1 < 0) {
        croak sprintf("Invalid array index (num: %s)", $num);
    }

    my $sql_type = (defined $opts) ? 
        ( (ref $opts eq "HASH") ? $opts->{TYPE} : $opts ) : SQL_VARCHAR;

    $self->{_binds}[$num - 1] = {
        value => $bind_value,
        type  => $sql_type,
    };

    1;
}

sub execute {
    my ($self, @binds) = @_;

    my $i = 1;
    for my $bind (@binds) {
        my ($bind_value, $opts) = (defined $bind && ref $bind eq 'HASH') ? 
            ( $bind->{value}, $bind->{type} ) : ( $bind, undef );
        $self->bind_param($i++, $bind_value, $opts);
    }

    if ($self->{server_prepare}) {
        $self->_push_query( $self->_make_set_query );
        $self->_push_query( $self->_make_execute_query );
    }
    else {
        $self->_push_query( $self->_make_binded_query );
    }

    $self->{_binds} = [];

    return 1;
}

sub finish {
    my $self = shift;
    if ($self->{server_prepare}) {
        $self->_push_query( $self->_make_deallocate_prepare_query );
    }
    1;
}

sub as_query {
    my $self = shift;
    return wantarray ? @{$self->{_queries}} : [ @{$self->{_queries}} ];
}

sub _make_binded_query {
    my $self = shift;
    my @tokens = tokenize_sql($self->{statement});
    my @binds = @{$self->_binds};

    my $query = '';

    for my $token (@tokens) {
        if ($token eq '?') {
            my $bind = shift @binds;
            $query .= $self->_quote($bind->{value}, $bind->{type});
        }
        else {
            $query .= $token;
        }
    }

    return $query;
}

sub _make_prepare_query {
    my $self = shift;
    sprintf(
        q|PREPARE %s FROM %s|,
        $self->{name}, 
        $self->_quote($self->{statement}, SQL_VARCHAR)
    );
}

sub _make_set_query {
    my $self = shift;

    my @binds = @{$self->_binds};

    return if (@binds == 0);

    my $query = 'SET ';
    my $i = 1;

    $query .= join ', ' => map {
        sprintf(
            q|@b%d = %s|, 
            $i++, 
            $self->_quote($_->{value}, $_->{type}) 
        )
    } @binds;

    return $query;
}

sub _make_execute_query {
    my $self = shift;

    my $query = sprintf('EXECUTE %s', $self->{name});
    my $bind_num = @{$self->_binds};

    if ($bind_num > 0) {
        $query .= ' USING ' . join ', ' => map { sprintf(q|@b%d|, $_) } (1 .. $bind_num);
    }

    return $query;
}

sub _make_deallocate_prepare_query {
    my $self = shift;
    sprintf(
        q|DEALLOCATE PREPARE %s|,
        $self->{name}, 
    );
}

sub _push_query {
    my ($self, $query) = @_;
    return unless defined $query;
    push(@{$self->_queries}, $query);
}

sub _quote {
    my ($self, $bind_value, $sql_type) = @_;

    if (ref $bind_value eq 'SCALAR') {
        return $$bind_value;
    }

    if ( defined $sql_type && ( first_index { $_ == $sql_type } @NON_QUOTE_TYPES ) > -1) {
        return $bind_value;
    }

    $bind_value =~ s/'/''/g;
    return "'$bind_value'";
}

1;
__END__

=head1 NAME

MySQL::PreparedStatement - Generate server-side prepared statements for MySQL

=head1 SYNOPSIS

Using client-side prepared statement.

  use DBI qw(:sql_types);
  use MySQL::PreparedStatement;

  my $s = MySQL::PreparedStatement->prepare('INSERT INTO test(id, name) VALUES(?, ?)', { name => 'sth1', server_prepare => 0 });

  $s->bind_param(1, 1, SQL_INTEGER);
  $s->bind_param(2, 'foo', SQL_VARCHAR);
  $s->execute;
  $s->finish;

  local $, = ";\n";
  print ( $s->as_query );

  # INSERT INTO test(id, name) VALUES(1, 'foo');

Using server-side prepared statement.

  use DBI qw(:sql_types);
  use MySQL::PreparedStatement;

  my $s = MySQL::PreparedStatement->prepare('INSERT INTO test(id, name) VALUES(?, ?)', { name => 'sth1', server_prepare => 1 });

  $s->bind_param(1, 1, SQL_INTEGER);
  $s->bind_param(2, 'foo', SQL_VARCHAR);
  $s->execute;
  $s->finish;

  local $, = ";\n";
  print ( $s->as_query );

  # PREPARE sth1 FROM 'INSERT INTO test(id, name) VALUES(?, ?)';
  # SET @b1 = 1, @b2 = 'foo';
  # EXECUTE sth1 USING @b1, @b2;
  # DEALLOCATE PREPARE sth1

=head1 DESCRIPTION

MySQL::PreparedStatement is generating server-side prepared statement library.
This module can be used by L<DBI>'s statement handle manipulation.

=head1 METHODS

=head2 prepare($statement, \%opts)

Create new MySQL::PreparedStatement object in order to given statement string.

=head3 arguments

=head4 $statement : Str

=head4 \%opts : Hash

=head3 returns

=head2 bind_param($num, $bind_value, \%opts or $sql_type)

Apply bind parameter.

=head3 arguments

=head4 $num : Int

=head4 $bind_value : Str or Num

=head4 \%opts : HashRef

=head4 $sql_type : Int

=head3 returns

Always return 1 value.

=head2 execute([$bind_value or \%bind, ...])

Generate SET and EXECUTE statements in order to given bind parameters.

=head3 arguments

=head4 $bind_value : Scalar 

=head4 \%bind : HashRef

=head3 returns

Always return 1 value.

=head2 finish()

Generate DEALLOCATE PREPARE statement.

=head3 arguments

None.

=head3 returns

=head2 as_query()

Retrieve generated queries as array or array reference.

=head3 arguments

None.

=head3 returns

=head1 COOKBOOKS

=head2 Using execute() method with bind parameters

  my $s = MySQL::PreparedStatement->prepare('INSERT INTO test(id, name) VALUES(?, ?)', { name => 'sth1', server_prepare => 1 });
  $s->execute({ value => 1, type => SQL_INTEGER }, 'foo');
  $s->finish;
  local $, = ";\n";
  print ($s->as_query);

This code will generate following queries.

  PREPARE sth1 FROM 'INSERT INTO test(id, name) VALUES(?, ?)';
  SET @b1 = 1, @b2 = 'foo';
  EXECUTE sth1 USING @b1, @b2;
  DEALLOCATE PREPARE sth1;

=head2 Reusing prepared statement

  my $s = MySQL::PreparedStatement->prepare('INSERT INTO test(id, name) VALUES(?, ?)', { name => 'sth1', server_prepare => 1 });
  $s->execute({ value => 1, type => SQL_INTEGER }, 'foo');
  $s->execute({ value => 2, type => SQL_INTEGER }, 'bar');
  $s->finish;
  local $, = ";\n";
  print ($s->as_query);

This code will generate following queries.

  PREPARE sth1 FROM 'INSERT INTO test(id, name) VALUES(?, ?)';
  SET @b1 = 1, @b2 = 'foo';
  EXECUTE sth1 USING @b1, @b2;
  SET @b1 = 2, @b2 = 'bar';
  EXECUTE sth1 USING @b1, @b2;
  DEALLOCATE PREPARE sth1;

=head1 AUTHOR

Toru Yamaguchi E<lt>zigorou@cpan.orgE<gt>

=head1 SEE ALSO

=over

=item L<Carp>

=item L<Class::Accessor::Lite>

=item L<DBI>

=item L<List::MoreUtils>

=item L<String::Random>

=back

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
