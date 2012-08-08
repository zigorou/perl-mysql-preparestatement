use strict;
use warnings;

use Test::More;
use DBI qw(:sql_types);
use MySQL::PreparedStatement;

sub make_deallocate_prepare_query {
    my (@binds) = @_;
    my $s = MySQL::PreparedStatement->prepare( 'SELECT 1 FROM dual', { name => 'aaa' } );
    $s->_make_deallocate_prepare_query;
}

is(make_deallocate_prepare_query(), q|DEALLOCATE PREPARE aaa|, 'query');

done_testing;
