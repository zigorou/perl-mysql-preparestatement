package MySQL::PreparedStatement;

use strict;
use warnings;

use Carp;
use Class::Accessor::Lite (
    new => 0,
    rw => [qw/name statement _queries _binds/],
);
use DBI qw(:sql_types);
use List::MoreUtils qw(first_index);
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
        name => random_regex('\w[4,10]'),
        %$opts,
        statement => $statement,
        _queries => [],
        _binds => [],
    );

    my $self = bless $opts => $class;
    $self->_push_query( $self->_make_prepare_query );
    $self;
}

sub bind_param {
    my ($self, $num, $bind_value, $opts) = @_;

    if ($num - 1 < 0) {
        croak sprintf("Invalid array index (num: %s)", $num);
    }

    my $sql_type = (defined $opts) ? 
        ( (ref $opts eq "HASH") ? $opts->{TYPE} : $opts ) : SQL_ALL_TYPES;

    $self->_binds->[$num - 1] = {
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
        $self->bind_param($i, $bind_value, $opts);
    }

    $self->_push_query( $self->_make_set_query );
    $self->_push_query( $self->_make_execute_query );

    $self->{_binds} = [];

    return 1;
}

sub finish {
    my $self = shift;
    $self->_push_query( $self->_make_deallocate_prepare_query );
    1;
}

sub reset {
    my $self = shift;

    $self->{_queries} = [];
    $self->{_binds} = [];

    1;
}

sub as_query {
    my $self = shift;
    return wantarray ? @{$self->{_queries}} : [ @{$self->{_queries}} ];
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

    my $query = 'SET ';
    my $i = 1;

    $query .= join ', ' => map {
        sprintf(
            q|@b%d = %s|, 
            $i++, 
            $self->_quote($_->{value}, $_->{type}) 
        )
    } @{$self->_binds};

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
    push(@{$self->_queries}, $query);
}

sub _quote {
    my ($self, $bind_value, $sql_type) = @_;

    if ( defined $sql_type && ( first_index { $_ == $sql_type } @NON_QUOTE_TYPES ) > -1) {
        return $bind_value;
    }

    $bind_value =~ s/'/''/g;
    return "'$bind_value'";
}

1;
__END__

=head1 NAME

MySQL::PreparedStatement -

=head1 SYNOPSIS

  use MySQL::PreparedStatement;

=head1 DESCRIPTION

MySQL::PreparedStatement is

=head1 AUTHOR

Toru Yamaguchi E<lt>zigorou@cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
