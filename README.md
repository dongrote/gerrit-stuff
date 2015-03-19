# gerrit-stuff
Scripts made for dealing with gerrit
  - backup_gerrit: backup a gerrit git repository and database, and package it up into a convenient tarball with a restore script
  - upgrade_gerrit_2.7-rc1_to_2.10.sh: pretty self-explanatory, perform the system upgrade from gerrit-2.7-rc1 to gerrit-2.10
  - gerrit-ldap-server.tac: A fake LDAP server that uses local user credentials for authenticating users in the gerrit web interface
  - fakeldap/fix-db.sh: A convenience script for fixing up the database to transition from OpenID Google authentication to LDAP_BIND authentication
