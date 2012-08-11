use strict;
use warnings;

use Test::More;
use DBI qw(:sql_types);
use MySQL::PreparedStatement;

my $s = MySQL::PreparedStatement->prepare('SELECT 1', { name => "test" });

is($s->_quote(q|Don't|), q|'Don''t'|, 'string value without sql_type');
is($s->_quote(13), q|'13'|, 'integer value without sql_type');
is($s->_quote(13, SQL_INTEGER), q|13|, 'integer value with SQL_INTEGER sql_type');
is($s->_quote(\'NOW()'), q|NOW()|, 'scalar reference');

done_testing;

