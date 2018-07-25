#!/bin/bash

ynh_check_global_uwsgi_config () {
	uwsgi --version || ynh_die "You need to add uwsgi (and appropriate plugin) as a dependency"

	# make sure the folder for sockets exists and set authorizations
	mkdir -p /var/run/uwsgi/
	chown root:www-data /var/run/uwsgi/
	chmod -R 775 /var/run/uwsgi/

	# make sure the folder for logs exists and set authorizations
	mkdir -p /var/log/$app/
	chown root:www-data /var/log/$app/
	chmod -R 775 /var/log/$app/
}

# Create a dedicated uwsgi ini file to use with generic uwsgi service
# It will install generic uwsgi.socket and
#
# This will use a template in ../conf/uwsgi.ini
# and will replace the following keywords with
# global variables that should be defined before calling
# this helper :
#
#   __APP__       by  $app
#   __PATH__      by  $path_url
#   __FINALPATH__ by  $final_path
#
# usage: ynh_add_systemd_config
#
# to interact with your service: `systemctl <action> uwsgi-app@app`
ynh_add_uwsgi_service () {
	ynh_check_global_uwsgi_config

	# www-data group is needed since it is this nginx who will start the service
	usermod --append --groups www-data "$app" || ynh_die "It wasn't possible to add user $app to group www-data"

	finaluwsgiini="/etc/uwsgi/apps-available/$app.ini"
	ynh_backup_if_checksum_is_different "$finaluwsgiini"
	cp ../conf/uwsgi.ini "$finaluwsgiini"

	# To avoid a break by set -u, use a void substitution ${var:-}. If the variable is not set, it's simply set with an empty variable.
	# Substitute in a nginx config file only if the variable is not empty
	if test -n "${final_path:-}"; then
		ynh_replace_string "__FINALPATH__" "$final_path" "$finaluwsgiini"
	fi
	if test -n "${path_url:-}"; then
		ynh_replace_string "__PATH__" "$path_url" "$finaluwsgiini"
	fi
	if test -n "${app:-}"; then
		ynh_replace_string "__APP__" "$app" "$finaluwsgiini"
	fi
	ynh_store_file_checksum "$finaluwsgiini"

	chown $app:www-data "$finaluwsgiini"

	finalservice="/etc/systemd/system/$app.service"
	ynh_backup_if_checksum_is_different "$finalservice"
	cp ../conf/systemd.service "$finalservice"

	# To avoid a break by set -u, use a void substitution ${var:-}. If the variable is not set, it's simply set with an empty variable.
	# Substitute in a nginx config file only if the variable is not empty
	if test -n "${final_path:-}"; then
		ynh_replace_string "__FINALPATH__" "$final_path" "$finalservice"
	fi
	if test -n "${path_url:-}"; then
		ynh_replace_string "__PATH__" "$path_url" "$finalservice"
	fi
	if test -n "${app:-}"; then
		ynh_replace_string "__APP__" "$app" "$finalservice"
	fi
	
	ynh_store_file_checksum "$finalservice"

	chown $app:www-data "$finalservice"

	systemctl daemon-reload
	systemctl enable "$app"

	# Add as a service
	yunohost service add "$app" --log "/var/log/$app/service.log"
}

# Remove the dedicated uwsgi ini file
#
# usage: ynh_remove_systemd_config
ynh_remove_uwsgi_service () {
	finaluwsgiini="/etc/uwsgi/apps-available/$app.ini"
	if [ -e "$finaluwsgiini" ]; then
		systemctl stop "$app"
		systemctl disable "$app"
		yunohost service remove "$app"

		ynh_secure_remove "$finaluwsgiini"
		ynh_secure_remove "/var/log/$app/service.log"
	fi
}
