#!/bin/bash
GERRIT_SITE=/home/gerrit2/review_site
REVIEWDB_BACKUP=/tmp/reviewdb-backup
GERRIT_USER=gerrit2
GERRIT_GROUP=$GERRIT_USER

install () {
	ownership="$3"
	echo -n "Installing $1 into $2 ... "
	cp "$1" "$2"
	if [ $? -ne 0 ]; then
		echo "FAILED"
		return 1
	fi
	test -z "$ownership" || chown "$ownership" "$2"
	echo "OK"
	return 0
}

compile_python_module () {
	path="$1"
	directory=$(dirname "$path")
	modulename=$(basename "$path" .py)	
	test -z "$2" || runas="$2"
	cd "$directory"
	test $? -eq 0 || return 1
	if [ -z "$runas" ] ; then
		PREFIX=""
	else
		PREFIX="sudo -u $runas "
	fi
	$PREFIX python -c "import $modulename"
	retval=$?
	cd - >/dev/null
	return $retval
}

catastrophe () {
	update-rc.d gerrit-ldap-server disable
	rm /etc/default/gerritldapserver
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

yes | apt-get install python-ldaptor
yes | pip install python-pam
for f in $(find /usr/lib/python2.7/dist-packages/ldaptor -name "*.py") ; do
	sed -i 's/log\.debug/log.msg/' $f
done

install GerritLDAPServer.py "$GERRIT_SITE/bin/GerritLDAPServer.py" $GERRIT_USER:$GERRIT_GROUP
if [ $? -ne 0 ] ; then
	catastrophe
fi

compile_python_module "$GERRIT_SITE/bin/GerritLDAPServer.py" $GERRIT_USER
if [ $? -ne 0 ] ; then
	catastrophe
fi

install gerrit-ldap-server.tac "$GERRIT_SITE/bin/gerrit-ldap-server.tac" $GERRIT_USER:$GERRIT_GROUP
if [ $? -ne 0 ] ; then
	catastrophe
fi

install init.d/gerrit-ldap-server /etc/init.d/gerrit-ldap-server
if [ $? -ne 0 ] ; then
	catastrophe
fi

install default/gerritldapserver /etc/default/gerritldapserver
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
