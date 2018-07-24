########################################################################
# Bug #569387: innobackupex ignores --databases
#              Testcase covers using --databases option with InnoDB
#              database (list is specified in file which option
#              points to)
########################################################################

. inc/common.sh

start_server --innodb-file-per-table

cat <<EOF | run_cmd $MYSQL $MYSQL_ARGS

	CREATE DATABASE test1;

	CREATE TABLE test1.a (a INT PRIMARY KEY) engine=InnoDB;
	CREATE TABLE test1.b (b INT PRIMARY KEY) engine=InnoDB;
	CREATE TABLE test1.c (c INT PRIMARY KEY) engine=InnoDB;

	CREATE TABLE test.a (a INT PRIMARY KEY) engine=InnoDB;
	CREATE TABLE test.b (b INT PRIMARY KEY) engine=InnoDB;
	CREATE TABLE test.c (c INT PRIMARY KEY) engine=InnoDB;

EOF

# Take a backup
# Backup the whole test and b,c from test1
cat >$topdir/databases_file <<EOF
mysql
performance_schema
test
test1.b
test1.c
EOF
xtrabackup --backup --databases-file=$topdir/databases_file --target-dir=$topdir/backup
xtrabackup --prepare --target-dir=$topdir/backup
vlog "Backup taken"

stop_server

# Restore partial backup
# Remove database
rm -rf $mysql_datadir/*
vlog "Original database removed"

# Restore database from backup
xtrabackup --copy-back --target-dir=$topdir/backup
vlog "database restored from backup"

start_server

OUT=`run_cmd $MYSQL $MYSQL_ARGS -e "USE test; SHOW TABLES; USE test1; SHOW TABLES;" | tr -d '\n'`

if [ $OUT != "Tables_in_testabcTables_in_test1abc" ] ; then
	die "Backed up tables set doesn't match filter"
fi

run_cmd $MYSQL $MYSQL_ARGS -e "USE test; SELECT * FROM a;"
run_cmd_expect_failure $MYSQL $MYSQL_ARGS -e "USE test1; SELECT * FROM a;"
run_cmd $MYSQL $MYSQL_ARGS -e "USE test1; DROP TABLE a;"
