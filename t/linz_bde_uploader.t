#!/usr/bin/perl
################################################################################
#
# $Id$
#
# Copyright 2011 Crown copyright (c)
# Land Information New Zealand and the New Zealand Government.
# All rights reserved
#
# This program is released under the terms of the new BSD license. See the
# LICENSE file for more information.
#
################################################################################

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Cmd;
use File::Temp qw/ tempdir /;
use File::Copy qw/ copy /;
use DBI;

my $script = "./blib/script/linz_bde_uploader";
my $confdir = "conf";
my $sqldir = "sql";

my $tmpdir = tempdir( '/tmp/linz_bde_uploader.t-data-XXXX', CLEANUP => 1);
my $logfname = ${tmpdir}.'/log';
#print "XXX ${tmpdir}\n";

my $testdbname = "linz_bde_uploader_test_$$";

# Create test database

my $dbh = DBI->connect("dbi:Pg:dbname=template1", "") or
    die "Cannot connect to template1, please set PG env variables";

$dbh->do("create database ${testdbname}") or
    die "Cannot create test database ${testdbname}";

$dbh = DBI->connect("dbi:Pg:dbname=${testdbname}", "") or
    die "Cannot connect to ${testdbname}";

END {
  my $dbh = DBI->connect("dbi:Pg:dbname=template1", "");
  $dbh->do("drop database if exists ${testdbname}") if $dbh;
}

my $test = Test::Cmd->new( prog => $script, workdir => '' );
$test->run();

like( $test->stderr, qr/at least .* -full, -incremental, -purge, or -remove-zombie/,
  'complain on stderr when no args');
like( $test->stderr, qr/Syntax/,
  'prints syntax on stderr when no args');
like( $test->stderr, qr/linz_bde_uploader.pl \[options..\] \[tables..\]/,
  'prints synopsis on stderr when no args');
is( $test->stdout, '', 'empty stdout on no args' );
is( $? >> 8, 1, 'exit status, with no args' );

$test->run( args => '-full' );
like( $test->stderr, qr/Cannot open configuration file/, 'stderr, called with -full');
is( $test->stdout, '', 'stdout, called with -full');
is( $? >> 8, 1, 'exit status, with -full' );

# Provide an empty configuration
open(my $cfg_fh, ">", "${tmpdir}/cfg1")
  or die "Can't write ${tmpdir}/cfg1: $!";
close($cfg_fh);

# Empty configuration
$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
like( $test->stderr,
  qr/Configuration item "log_settings" is missing/,
  'stderr, empty config' );
is( $test->stdout, '', 'stdout, empty config' );
is( $? >> 8, 1, 'exit status, empty config' );

# Add log_settings configuration
open($cfg_fh, ">>", "${tmpdir}/cfg1")
  or die "Can't append to ${tmpdir}/cfg1: $!";
print $cfg_fh <<"EOF";
log_settings <<END_OF_LOG_SETTINGS
log4perl.logger = DEBUG, File
log4perl.appender.File = Log::Log4perl::Appender::File
log4perl.appender.File.filename = ${logfname}
log4perl.appender.File.layout = Log::Log4perl::Layout::SimpleLayout
END_OF_LOG_SETTINGS
EOF
close($cfg_fh);

# bde_tables_config is now required now..

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, no bde_tables_config' );
is( $test->stdout, '', 'stdout, no bde_tables_config' );
is( $? >> 8, 1, 'exit status, no bde_tables_config' );
open(my $log_fh, "<", "${logfname}") or die "Cannot open ${logfname}";
my @logged = <$log_fh>;
is( @logged, 3,
  'logged 3 lines, no bde_tables_config' ); # WARNING: might depend on verbosity
my $log = join '', @logged;
like( $log,
  qr/ERROR.*item "bde_tables_config".*missing.*Duration of job/ms,
  'logfile - no bde_tables_config');

# Add bde_tables_config

open($cfg_fh, ">>", "${tmpdir}/cfg1")
  or die "Can't append to ${tmpdir}/cfg1: $!";
print $cfg_fh "bde_tables_config {_configdir}/tables.conf\n";
close($cfg_fh);

# We're now missing tables.conf...
$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, no tables.conf' );
is( $test->stdout, '', 'stdout, no tables.conf' );
is( $? >> 8, 1, 'exit status, no tables.conf' );
@logged = <$log_fh>;
is( @logged, 2,
  'logged 2 lines, no tables.conf' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/FATAL.*tables.conf.*No such file/ms,
  'logfile - no bde_tables_config');

# Let's write a test tables configuration next

open($cfg_fh, ">", "${tmpdir}/tables.conf")
  or die "Can't write ${tmpdir}/tables.conf: $!";
print $cfg_fh <<"EOF";
TABLE crs_test key=id row_tol=0.20,0.80 files test
EOF
close($cfg_fh);

# db_connection is now required now..

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, no db_connection' );
is( $test->stdout, '', 'stdout, no db_connection' );
is( $? >> 8, 1, 'exit status, no db_connection' );
@logged = <$log_fh>;
is( @logged, 3,
  'logged 3 lines, no db_connection' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/ERROR.*item "db_connection".*missing.*Duration of job/ms,
  'logfile - no db_connection');

# Add db_connection

open($cfg_fh, ">>", "${tmpdir}/cfg1")
  or die "Can't append to ${tmpdir}/cfg1: $!";
print $cfg_fh "db_connection dbname=nonexistent\n";
close($cfg_fh);

# db_user is now required now..

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, no db_user' );
is( $test->stdout, '', 'stdout, no db_user' );
is( $? >> 8, 1, 'exit status, no db_user' );
@logged = <$log_fh>;
is( @logged, 3,
  'logged 3 lines, no db_user' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/ERROR.*item "db_user".*missing.*Duration of job/ms,
  'logfile - no db_user');

# Add db_user

open($cfg_fh, ">>", "${tmpdir}/cfg1")
  or die "Can't append to ${tmpdir}/cfg1: $!";
print $cfg_fh "db_user \n";
close($cfg_fh);

# db_pwd is now required now..

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, no db_pwd' );
is( $test->stdout, '', 'stdout, no db_pwd' );
is( $? >> 8, 1, 'exit status, no db_pwd' );
@logged = <$log_fh>;
is( @logged, 3,
  'logged 3 lines, no db_pwd' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/ERROR.*item "db_pwd".*missing.*Duration of job/ms,
  'logfile - no db_pwd');

# Add db_pwd

open($cfg_fh, ">>", "${tmpdir}/cfg1")
  or die "Can't append to ${tmpdir}/cfg1: $!";
print $cfg_fh "db_pwd \n";
close($cfg_fh);

# db_connect_sql is now required now..

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, no db_connect_sql' );
is( $test->stdout, '', 'stdout, no db_connect_sql' );
is( $? >> 8, 1, 'exit status, no db_connect_sql' );
@logged = <$log_fh>;
is( @logged, 3,
  'logged 3 lines, no db_connect_sql' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/ERROR.*item "db_connect_sql".*missing.*Duration of job/ms,
  'logfile - no db_connect_sql');

# Add db_connect_sql

open($cfg_fh, ">>", "${tmpdir}/cfg1")
  or die "Can't append to ${tmpdir}/cfg1: $!";
print $cfg_fh "db_connect_sql \n";
close($cfg_fh);

# db_upload_complete_sql is now required now..

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, no db_upload_complete_sql' );
is( $test->stdout, '', 'stdout, no db_upload_complete_sql' );
is( $? >> 8, 1, 'exit status, no db_upload_complete_sql' );
@logged = <$log_fh>;
is( @logged, 3,
  'logged 3 lines, no db_upload_complete_sql' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/ERROR.*item "db_upload_complete_sql".*missing.*Duration of job/ms,
  'logfile - no db_upload_complete_sql');

# Add db_upload_complete_sql

open($cfg_fh, ">>", "${tmpdir}/cfg1")
  or die "Can't append to ${tmpdir}/cfg1: $!";
print $cfg_fh "db_upload_complete_sql \n";
close($cfg_fh);

# dataset_load_start_sql is now required now..

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, no dataset_load_start_sql' );
is( $test->stdout, '', 'stdout, no dataset_load_start_sql' );
is( $? >> 8, 1, 'exit status, no dataset_load_start_sql' );
@logged = <$log_fh>;
is( @logged, 3,
  'logged 3 lines, no dataset_load_start_sql' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/ERROR.*item "dataset_load_start_sql".*missing.*Duration of job/ms,
  'logfile - no dataset_load_start_sql');

# Add dataset_load_start_sql

open($cfg_fh, ">>", "${tmpdir}/cfg1")
  or die "Can't append to ${tmpdir}/cfg1: $!";
print $cfg_fh "dataset_load_start_sql \n";
close($cfg_fh);

# dataset_load_end_sql is now required now..

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, no dataset_load_end_sql' );
is( $test->stdout, '', 'stdout, no dataset_load_end_sql' );
is( $? >> 8, 1, 'exit status, no dataset_load_end_sql' );
@logged = <$log_fh>;
is( @logged, 3,
  'logged 3 lines, no dataset_load_end_sql' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/ERROR.*item "dataset_load_end_sql".*missing.*Duration of job/ms,
  'logfile - no dataset_load_end_sql');

# Add dataset_load_end_sql

open($cfg_fh, ">>", "${tmpdir}/cfg1")
  or die "Can't append to ${tmpdir}/cfg1: $!";
print $cfg_fh "dataset_load_end_sql \n";
close($cfg_fh);

# db_schema is now required now..

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, no db_schema' );
is( $test->stdout, '', 'stdout, no db_schema' );
is( $? >> 8, 1, 'exit status, no db_schema' );
@logged = <$log_fh>;
is( @logged, 3,
  'logged 3 lines, no db_schema' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/ERROR.*item "db_schema".*missing.*Duration of job/ms,
  'logfile - no db_schema');

# Add db_schema

open($cfg_fh, ">>", "${tmpdir}/cfg1")
  or die "Can't append to ${tmpdir}/cfg1: $!";
print $cfg_fh "db_schema bde_control\n";
close($cfg_fh);

# bde_schema is now required now..

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, no bde_schema' );
is( $test->stdout, '', 'stdout, no bde_schema' );
is( $? >> 8, 1, 'exit status, no bde_schema' );
@logged = <$log_fh>;
is( @logged, 3,
  'logged 3 lines, no bde_schema' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/ERROR.*item "bde_schema".*missing.*Duration of job/ms,
  'logfile - no bde_schema');

# Add bde_schema

open($cfg_fh, ">>", "${tmpdir}/cfg1")
  or die "Can't append to ${tmpdir}/cfg1: $!";
print $cfg_fh "bde_schema bde\n";
close($cfg_fh);

# Attempts to connect to non-existing database

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, nonexistent db');
is( $test->stdout, '', 'stdout, nonexistent db');
is( $? >> 8, 1, 'exit status, with nonexistent db' );
@logged = <$log_fh>;
is( @logged, 3,
  'logged 3 lines, nonexistent db' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/ERROR.*FATAL.*database "nonexistent" does not exist.*Duration of job/ms,
  'logfile - nonexistent db');

# Dry run connects anyway

$test->run( args => "-full -dry-run -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, nonexistent db, dry-run');
like( $test->stdout,
  qr/FATAL.*database "nonexistent" does not exist.*Duration of job/ms,
  'logfile - nonexistent db, dry-run');
is( $? >> 8, 1, 'exit status, nonexistent db, dry-run');
@logged = <$log_fh>;
is( @logged, 0,
  'logged 0 lines, nonexistent db, dry-run' ); # WARNING: might depend on verbosity

# A configuration with .test suffix will be read by default to
# override the main configuration
# Set database connection to the test database
open($cfg_fh, ">", "${tmpdir}/cfg1.test")
  or die "Can't append to ${tmpdir}/cfg1.test: $!";
print $cfg_fh <<"EOF";
db_connection dbname=${testdbname}
EOF
close($cfg_fh);

# Run with ability to connect to database

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, empty db');
is( $test->stdout, '', 'stdout, empty db');
is( $? >> 8, 1, 'exit status, empty db');
@logged = <$log_fh>;
is( @logged, 7,
  'logged 7 lines, empty db' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/ERROR.*function bde_checkschema.*not exist.*Duration of job/ms,
  'logfile - empty db');

# Prepare the database now
# TODO: make this simpler, see
# https://github.com/linz/linz_bde_uploader/issues/82

my $PSQLOPTS = "--set ON_ERROR_STOP=1";

# Install table_version extension
$dbh->do("CREATE EXTENSION IF NOT EXISTS table_version") or die
  "Could not create extension table_version";

# Install dbpatch extension
$dbh->do("CREATE SCHEMA IF NOT EXISTS _patches") or die
  "Could not create schema _patches";
$dbh->do("CREATE EXTENSION IF NOT EXISTS dbpatch SCHEMA _patches") or die
  "Could not create extension dbpatch";

# Install postgis extension
$dbh->do("CREATE EXTENSION IF NOT EXISTS postgis") or die
  "Could not create extension postgis";

# Install linz-dbe-schema

my $bdeschema_sqldir;
if ( $ENV{'BDESCHEMA_SQLDIR'} )
{
  $bdeschema_sqldir = $ENV{'BDESCHEMA_SQLDIR'};
  die "Cannot ivalid BDESCHEMA_SQLDIR $bdeschema_sqldir: not such directory"
    unless -d $bdeschema_sqldir;
}
else
{
  my @trydirs = ( '/usr/share/linz-bde-schema/sql',
                  '/usr/local/share/linz-bde-schema/sql' );
  foreach my $d (@trydirs) {
    if ( -d $d ) {
      $bdeschema_sqldir = $d;
      last
    }
  }
  die "Cannot find linz-bde-schema sql dir, try setting BDESCHEMA_SQLDIR\n"
      . '(tried: ' .  join(', ', @trydirs) . ')'
      unless $bdeschema_sqldir;
}
my @sqlfiles = <$bdeschema_sqldir/*>;
foreach my $f (@sqlfiles) {
  my $out = `psql --set ON_ERROR_STOP=1 "${testdbname}" -f $f 2>&1`;
  unlike( $out, qr/ERROR/, "sourcing $f gives no error" );
  #print "XXX $f - $out\n";
}

# Install local support functions

@sqlfiles = <$sqldir/*>;
foreach my $f (@sqlfiles) {
  my $out = `psql --set ON_ERROR_STOP=1 "${testdbname}" -f $f 2>&1`;
  unlike( $out, qr/ERROR/, "sourcing $f gives no error" );
  #print "XXX $f - $out\n";
}

# Run with prepared database, it's missing application_name now

$test->run( args => "-full -config-path ${tmpdir}/cfg1" );
is( $test->stderr, '', 'stderr, prepared db');
is( $test->stdout, '', 'stdout, prepared db');
is( $? >> 8, 1, 'exit status, prepared db');
@logged = <$log_fh>;
is( @logged, 3,
  'logged 3 lines, prepared db' ); # WARNING: might depend on verbosity
$log = join '', @logged;
like( $log,
  qr/ERROR - Configuration item "application_name" is missing/ms,
  'logfile - prepared db');

close($log_fh);
done_testing();
