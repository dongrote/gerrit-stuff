#!/bin/bash

dbname="reviewdb"
gerrituser="gerrit2"
old_project_name="$1"
new_project_name="$2"

. /etc/default/gerritcodereview
if [ $? -ne 0 ] ; then
	echo "No /etc/default/gerritcodereview, bailing."
	exit 1
fi

run_sql_query () {
	query="$1"
	dbase="$2"
	sudo -u $gerrituser psql -c "$query" "$dbase"
	echo "psql -c \"$query\" $dbase"
}

update_changes_old_new () {
	old_project_name="$1"
	new_project_name="$2"
	query="UPDATE changes SET dest_project_name='$new_project_name' WHERE dest_project_name='$old_project_name'"
	run_sql_query "$query" $dbname
}

update_account_project_watches_old_new () {
	old_project_name="$1"
	new_project_name="$2"
	query="UPDATE account_project_watches SET project_name='$new_project_name' WHERE project_name='$old_project_name'"
	run_sql_query "$query" $dbname
}

update_submodule_subscriptions_old_new () {
	old_project_name="$1"
	new_project_name="$2"
	query="UPDATE submodule_subscriptions SET submodule_project_name='$new_project_name' WHERE submodule_project_name='$old_project_name'"
	run_sql_query "$query" $dbname
	query="UPDATE submodule_subscriptions SET super_project_project_name='$new_project_name' WHERE super_project_project_name='$old_project_name'"
	run_sql_query "$query" $dbname
}

update_system_config () {
	old_project_name="$1"
	new_project_name="$2"
	query="UPDATE system_config SET wild_project_name='$new_project_name' WHERE wild_project_name='$old_project_name'"
	run_sql_query "$query" $dbname
}

get_schema_version () {
	query="SELECT version_nbr FROM schema_version"
	sudo -u $gerrituser psql -c "$query" $dbname | grep -E " +[0-9]+" | sed 's/^ *//'
}

schema_mismatch () {
	echo "Error: expected schema version $2, instead found $1"
	exit 1
}

# check that new_project_name doesn't already exist
if [ -e "$GERRIT_SITE/git/$new_project_name.git" ] ; then
	echo "Error, '$new_project_name' already exists."
	exit 1
fi

schema_version_number=$(get_schema_version)
test "$schema_version_number" = "98" || schema_mismatch $schema_version_number 98

sudo /etc/init.d/gerrit stop
if [ $? -ne 0 ] ; then
	echo "Error stopping Gerrit Code Review, exiting."
	exit 1
fi

update_changes_old_new "$old_project_name" "$new_project_name"
update_account_project_watches_old_new "$old_project_name" "$new_project_name"
update_submodule_subscriptions_old_new "$old_project_name" "$new_project_name"
update_system_config "$old_project_name" "$new_project_name"

sudo -u $gerrituser mv "$GERRIT_SITE/git/$old_project_name.git" "$GERRIT_SITE/git/$new_project_name.git"
#echo "sudo -u $gerrituser mv \"$GERRIT_SITE/git/$old_project_name.git\" \"$GERRIT_SITE/git/$new_project_name.git\""

sudo /etc/init.d/gerrit start
if [ $? -ne 0 ] ; then
	echo "Error restarting Gerrit Code Review; ruh roh!"
	exit 1
fi
