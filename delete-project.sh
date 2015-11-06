#!/bin/bash

dbname="reviewdb"
gerrituser="gerrit2"
project="$1"

. /etc/default/gerritcodereview
if [ $? -ne 0 ] ; then
	echo "No /etc/default/gerritcodereview, bailing."
	exit 1
fi

get_project_change_ids () {
	project_name="$1"
	query="SELECT change_id FROM changes WHERE dest_project_name='$project_name'"
	sudo -u $gerrituser psql -c "$query" $dbname | grep -E "[0-9]+" | grep -v row | sed 's/^ *//'
}

delete_change_id_from_table () {
	change_id=$1
	table=$2
	query="DELETE FROM $table WHERE change_id=$change_id"
	sudo -u $gerrituser psql -c "$query" $dbname
}

delete_patch_comments () {
	change_id=$1
	delete_change_id_from_table $change_id patch_comments
}

delete_patch_sets () {
	change_id=$1
	delete_change_id_from_table $change_id patch_sets
}

delete_patch_set_ancestors () {
	change_id=$1
	delete_change_id_from_table $change_id patch_set_ancestors
}

delete_patch_set_approvals () {
	change_id=$1
	delete_change_id_from_table $change_id patch_set_approvals
}

delete_account_patch_reviews () {
	change_id=$1
	delete_change_id_from_table $change_id account_patch_reviews
}

delete_change_messages () {
	change_id=$1
	delete_change_id_from_table $change_id change_messages
}

delete_changes () {
	change_id=$1
	delete_change_id_from_table $change_id changes
}

delete_starred_changes () {
	change_id=$1
	delete_change_id_from_table $change_id starred_changes
}

get_schema_version () {
	query="SELECT version_nbr FROM schema_version"
	sudo -u $gerrituser psql -c "$query" $dbname | grep -E " +[0-9]+" | sed 's/^ *//'
}

schema_mismatch () {
	echo "Error: expected schema version $2, instead found $1"
	exit 1
}

schema_version_number=$(get_schema_version)
test "$schema_version_number" = "98" || schema_mismatch $schema_version_number 98

sudo /etc/init.d/gerrit stop
if [ $? -ne 0 ] ; then
	echo "Error stopping Gerrit Code Review, exiting."
	exit 1
fi

for changeid in $(get_project_change_ids $project)
do
	delete_patch_comments $changeid
	delete_patch_sets $changeid
	delete_patch_set_ancestors $changeid
	delete_patch_set_approvals $changeid
	delete_account_patch_reviews $changeid
	delete_change_messages $changeid
	delete_changes $changeid
	delete_starred_changes $changeid
done

sudo -u $gerrituser rm -rf $GERRIT_SITE/git/$project.git

sudo /etc/init.d/gerrit start
if [ $? -ne 0 ] ; then
	echo "Error restarting Gerrit Code Review; ruh roh!"
	exit 1
fi
