#!/bin/bash
GERRIT_SITE=/home/gerrit2/review_site
REVIEWDB_BACKUP=/tmp/reviewdb-backup

install () {
	echo -n "Installing $1 into $2 ... "
	cp "$1" "$2"
	if [ $? -ne 0 ]; then
		echo "FAILED"
		return 1
	fi
	echo "OK"
	return 0
}

catastrophe () {
	update-rc.d gerrit-ldap-server disable
	rm /etc/defaults/gerritldapserver
	rm /etc/init.d/gerrit-ldap-server
	rm "$GERRIT_SITE/bin/GerritLDAPServer.py"
	rm "$GERRIT_SITE/bin/gerrit-ldap-server.tac"
	exit 1
}

migratedb () {
	DBNAME="reviewdb"
	for row in $(sudo -u gerrit2 psql -c "SELECT email_address FROM account_external_ids WHERE external_id LIKE 'http%'" $DBNAME)
	do
		echo $row | grep "@" >/dev/null
		if [ $? -eq 0 ]; then
			username=$(echo $row | cut -f1 -d@)
			update_query="UPDATE account_external_ids SET external_id='gerrit:$username' WHERE email_address='$row' AND external_id LIKE 'http%'"
			sudo -u gerrit2 psql -c "$update_query" $DBNAME
			if [ $? -ne 0 ] ; then
				return 1
			fi
		fi
	done
	return 0
}

restoredb () {
	sudo -u postgres dropdb reviewdb
	sudo -u postgres createdb reviewdb
	sudo -u postgres psql reviewdb < $REVIEWDB_BACKUP
}

update_gerrit_config () {
	GERRIT_CONFIG="$GERRIT_SITE/etc/gerrit.config"

	sed -i 's/type = OPENID/type = LDAP_BIND/' $GERRIT_CONFIG

	cat <<EOF >>$GERRIT_CONFIG
[ldap]
	server = ldap://localhost:38942
	accountBase = ou=people,dc=nodomain
	groupBase = ou=groups,dc=nodomain
EOF
}

if [ ! -d "$GERRIT_SITE" ] ; then
	echo "$GERRIT_SITE doesn't exist."
	exit 1
fi

install GerritLDAPServer.py "$GERRIT_SITE/bin/"
if [ $? -ne 0 ] ; then
	catastrophe
fi

install gerrit-ldap-server.tac "$GERRIT_SITE/bin/"
if [ $? -ne 0 ] ; then
	catastrophe
fi


install init.d/gerrit-ldap-server /etc/init.d/
if [ $? -ne 0 ] ; then
	catastrophe
fi

install defaults/gerritldapserver /etc/defaults/
if [ $? -ne 0 ] ; then
	catastrophe
fi

update-rc.d gerrit-ldap-server defaults
if [ $? -ne 0 ] ; then
	catastrophe
fi

/etc/init.d/gerrit-ldap-server start
if [ $? -ne 0 ] ; then
	catastrophe
fi

# take down gerrit, update the gerrit config, transition the database over
# to LDAP from Google

/etc/init.d/gerrit stop
if [ $? -ne 0 ] ; then
	catastrophe
fi

# back up the database, we're about to destroy some data
sudo -u gerrit2 pg_dump reviewdb > $REVIEWDB_BACKUP
if [ $? -ne 0 ] ; then
	echo "Error dumping database to a file"
	/etc/init.d/gerrit start
	catastrophe
fi

# replace google entries with LDAP ones
migratedb
if [ $? -ne 0 ] ; then
	echo "Error migrating database to LDAP"
	restoredb
	rm $REVIEWDB_BACKUP
	catastrophe
fi
rm $REVIEWDB_BACKUP

update_gerrit_config

# bring gerrit back up
/etc/init.d/gerrit start
