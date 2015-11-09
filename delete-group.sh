#!/bin/bash

dbname="reviewdb"
gerrituser="gerrit2"
groupname="$1"

. /etc/default/gerritcodereview
if [ $? -ne 0 ] ; then
	echo "No /etc/default/gerritcodereview, bailing."
	exit 1
fi

get_group_id () {
	groupname="$1"
	query="SELECT group_id FROM account_group_names WHERE name='$groupname'"
	sudo -u $gerrituser psql -c "$query" $dbname | grep -E "[0-9]+" | grep -v row | sed 's/^ *//'
}

delete_group_id_from_table () {
	group_id=$1
	table=$2
	query="DELETE FROM $table WHERE group_id=$group_id"
	sudo -u $gerrituser psql -c "$query" $dbname
}

get_schema_version () {
	query="SELECT version_nbr FROM schema_version"
	sudo -u $gerrituser psql -c "$query" $dbname | grep -E " +[0-9]+" | sed 's/^ *//'
}

schema_mismatch () {
	echo "Error: expected schema version $2, instead found $1"
	exit 1
}

start_gerrit () {
	sudo /etc/init.d/gerrit start
	return $?
}

stop_gerrit () {
	sudo /etc/init.d/gerrit stop
	return $?
}

schema_version_number=$(get_schema_version)
test "$schema_version_number" = "98" || schema_mismatch $schema_version_number 98

stop_gerrit
if [ $? -ne 0 ] ; then
	echo "Error stopping Gerrit Code Review, exiting."
	exit 1
fi

table_names="
account_group_members
account_group_members_audit
account_group_names
"

group_id=$(get_group_id $groupname)
if [ "x$group_id" == "x" ] ; then
	echo "Group name \"$groupname\" not found in database"
	exit 1
fi

echo "$groupname group id $group_id"
for tablename in $table_names
do
	delete_group_id_from_table $group_id $tablename
done

start_gerrit
if [ $? -ne 0 ] ; then
	echo "Error restarting Gerrit Code Review; ruh roh!"
	exit 1
fi
