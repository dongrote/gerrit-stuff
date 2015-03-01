#!/bin/bash

GERRIT_DIR=/home/gerrit2/review_site

sudo /etc/init.d/gerrit stop
if [ $? -ne 0 ]; then
		echo "Error stopping gerrit"
		exit 1
fi

sudo apt-get update
if [ $? -ne 0 ]; then
		echo "Error updating apt-get"
		sudo /etc/init.d/gerrit start
		exit 1
fi

yes | sudo apt-get install openjdk-7-jre-headless
if [ $? -ne 0 ]; then
		echo "Error installing openjdk-7-jre-headless"
		sudo /etc/init.d/gerrit start
		exit 1
fi

yes 2 | sudo update-alternatives --config java
if [ $? -ne 0 ]; then
		echo "Error switching to java 7"
		sudo /etc/init.d/gerrit start
		exit 1
fi

gerrit_work_script_path="$(pwd)/gerrit2-work.sh"
cat <<EOF  >$gerrit_work_script_path
#!/bin/bash
GERRIT_DIR=/home/gerrit2/review_site
mv \$GERRIT_DIR/bin/gerrit.war \$GERRIT_DIR/bin/gerrit-2.7-rc1.war
if [ \$? -ne 0 ]; then
		echo "Error renaming gerrit.war file"
		exit 1
fi

wget http://gerrit-releases.storage.googleapis.com/gerrit-2.8.war -O \$GERRIT_DIR/bin/gerrit-2.8.war
if [ \$? -ne 0 ]; then
		echo "Error downloading gerrit-2.8.war"
		exit 1
fi
wget http://gerrit-releases.storage.googleapis.com/gerrit-2.10.war -O \$GERRIT_DIR/bin/gerrit-2.10.war
if [ \$? -ne 0 ]; then
		echo "Error downloading gerrit-2.10.war"
		exit 1
fi
pushd \$GERRIT_DIR/bin
if [ \$? -ne 0 ]; then
		echo "Error changing to \$GERRIT_DIR/bin directory"
		exit 1
fi

### upgrade to 2.8
ln -s gerrit-2.8.war gerrit.war
if [ \$? -ne 0 ]; then
		echo "Error creating gerrit.war symlink"
		exit 1
fi

java -jar gerrit.war init --batch -d \$GERRIT_DIR
if [ \$? -ne 0 ]; then
		echo "Error upgrading to gerrit 2.8"
		exit 1
fi

rm gerrit.war
if [ \$? -ne 0 ]; then
		echo "Error removing gerrit.war symlink"
		exit 1
fi

### upgrade to 2.10
ln -s gerrit-2.10.war gerrit.war
if [ \$? -ne 0 ]; then
		echo "Error creating gerrit.war symlink"
		exit 1
fi

java -jar gerrit.war init --batch -d \$GERRIT_DIR 
if [ \$? -ne 0 ]; then
		echo "Error upgrading to gerrit 2.10"
		exit 1
fi

### update \$GERRIT_DIR/etc/gerrit.config to point to java-7-openjdk-amd64
sed -i 's/java-6/java-7/' \$GERRIT_DIR/etc/gerrit.config
if [ \$? -ne 0 ]; then
		echo "Error modifying gerrit.config"
		exit 1
fi

cd ..
java -jar bin/gerrit.war reindex
if [ \$? -ne 0 ]; then
		echo "Error reindexing gerrit"
		exit 1
fi

popd
cat <<__EOF >sql-script
DROP TABLE tracking_ids;
ALTER TABLE account_groups DROP COLUMN group_type;
ALTER TABLE accounts DROP COLUMN show_user_in_review;
ALTER TABLE patch_set_approvals DROP COLUMN change_open;
ALTER TABLE patch_set_approvals DROP COLUMN change_sort_key;
__EOF
psql reviewdb < sql-script
if [ \$? -ne 0 ]; then
		echo "Error removing unused elements from database"
		exit 1
fi

rm sql-script
exit 0
EOF


sudo su -l -c "bash $gerrit_work_script_path" gerrit2
ret=$?
rm $gerrit_work_script_path
if [ $ret -ne 0 ]; then
		echo "Error in gerrit2 script"
		exit 1
fi

## update apache virtual host config
vhost_config="/etc/apache2/sites-available/gerrit"
sudo sed -i 's/ProxyPass/AllowEncodedSlashes On\n\tProxyPass/' $vhost_config
if [ $? -ne 0 ]; then
		echo "Error updating gerrit virtual host config"
		exit 1
fi

sudo /etc/init.d/gerrit start
if [ $? -ne 0 ]; then
		echo "Error starting gerrit"
		exit 1
fi

sudo /etc/init.d/apache2 restart
if [ $? -ne 0 ]; then
		echo "Error restarting apache2"
		exit 1
fi

exit 0
