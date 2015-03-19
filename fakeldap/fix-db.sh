#!/bin/bash

DBNAME="reviewdb"

for row in $(psql -c "SELECT email_address FROM account_external_ids WHERE external_id LIKE 'http%'" $DBNAME)
do
	echo $row | grep "@" >/dev/null
	if [ $? -eq 0 ]; then
		username=$(echo $row | cut -f1 -d@)
		update_query="UPDATE account_external_ids SET external_id='gerrit:$username' WHERE email_address='$row' AND external_id LIKE 'http%'"
		#select_query="SELECT * FROM account_external_ids WHERE email_address='$row' AND external_id LIKE 'http%'"
		#psql -c "$select_query" $DBNAME
		psql -c "$update_query" $DBNAME
	fi
done
psql -c "SELECT * FROM account_external_ids" $DBNAME
