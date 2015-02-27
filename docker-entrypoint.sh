#!/bin/bash
set -e

if [ "$1" = "/usr/bin/supervisord" ]; then

	# clone inital config if not exist
	if [ -z "$(ls -A "$FREESWITCH_CONF")" ]; then
		git clone "$FREESWITCH_INIT_REPO" "$FREESWITCH_CONF"
	fi
	chown -R freeswitch:freeswitch $FREESWITCH_CONF

	[ ! -d $FUSIONPBX_DB ] && mkdir -p /var/lib/fusionpbx/db
	[ ! -d /var/lib/fusionpbx/sounds ] && mkdir -p /var/lib/fusionpbx/sounds
	[ ! -d /usr/share/freeswitch/sounds/music ] && mkdir -p /usr/share/freeswitch/sounds/music && \
		ln -s /var/lib/fusionpbx/sounds/music /usr/share/freeswitch/sounds/music/fusionpbx && \
		ln -s /var/lib/fusionpbx/sounds/custom /usr/share/freeswitch/sounds/

        find "/var/lib/fusionpbx" -type d -exec chmod 775 {} +
        find "/var/lib/fusionpbx" -type f -exec chmod 664 {} +
        find "/var/lib/fusionpbx/db" -type d -exec chmod 777 {} +
        find "/var/lib/fusionpbx/db" -type f -exec chmod 666 {} +
        chown -R www-data:www-data /var/lib/fusionpbx/sounds
        chown -R www-data:www-data /var/lib/fusionpbx/sounds

        if [ -z "$(ls -A "$FUSIONPBX_DB")" ]; then
                /usr/sbin/php5-fpm &
                /usr/sbin/nginx &
                sleep 5
                curl -k -s -d "db_path=$FUSIONPBX_DB&db_name=fusionpbx.db&install_default_country=$FUSIONPBX_DEFAULT_COUNTRY&install_template_name=enhanced&admin_username=admin&admin_password=fusionpbx&db_type=sqlite&install_step=3" https://localhost/resources/install.php >/dev/null
                /usr/sbin/nginx -s stop
                killall php5-fpm
        fi

fi      

exec $@

