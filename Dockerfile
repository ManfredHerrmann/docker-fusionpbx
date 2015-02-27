FROM debian:wheezy

#######################################################################################
# based on FusionPbx-Debian-Optional-Pkgs-or-Source-Install.sh r7778

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r freeswitch && useradd -r -g freeswitch freeswitch

# install basics
RUN \
	apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get -y install git curl procps net-tools supervisor

# install all required packages
RUN sed -e '/contrib.*non-free/! s/\(.*\)/\1 contrib non-free/' \
	-i /etc/apt/sources.list && \
	echo "deb http://repo.fusionpbx.com/freeswitch/release/debian/ wheezy main" >/etc/apt/sources.list.d/freeswitch.list && \
	echo "deb http://repo.fusionpbx.com/fusionpbx/release/debian/ wheezy main" >/etc/apt/sources.list.d/fusionpbx.list && \
	curl -s http://files.freeswitch.org/repo/deb/debian/freeswitch_archive_g0.pub | apt-key add - && \
	apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get --force-yes -y install unixodbc uuid memcached libtiff5 libtiff-tools time bison htop screen libpq5 lame \
	freeswitch freeswitch-init freeswitch-meta-codecs freeswitch-mod-commands freeswitch-mod-curl \
	freeswitch-mod-db freeswitch-mod-distributor freeswitch-mod-dptools freeswitch-mod-enum freeswitch-mod-esf freeswitch-mod-esl \
	freeswitch-mod-expr freeswitch-mod-fsv freeswitch-mod-hash freeswitch-mod-memcache freeswitch-mod-portaudio freeswitch-mod-portaudio-stream \
	freeswitch-mod-random freeswitch-mod-spandsp freeswitch-mod-spy freeswitch-mod-translate freeswitch-mod-valet-parking freeswitch-mod-flite \
	freeswitch-mod-pocketsphinx freeswitch-mod-tts-commandline freeswitch-mod-dialplan-xml freeswitch-mod-loopback freeswitch-mod-sofia \
	freeswitch-mod-event-multicast freeswitch-mod-event-socket freeswitch-mod-event-test freeswitch-mod-local-stream freeswitch-mod-native-file \
	freeswitch-mod-sndfile freeswitch-mod-tone-stream freeswitch-mod-lua freeswitch-mod-console freeswitch-mod-logfile freeswitch-mod-syslog \
	freeswitch-mod-say-en freeswitch-mod-posix-timer freeswitch-mod-timerfd freeswitch-mod-v8 freeswitch-mod-xml-cdr freeswitch-mod-xml-curl \
	freeswitch-mod-xml-rpc freeswitch-conf-vanilla \
	freeswitch-mod-shout \
	$(apt-cache search "freeswitch-(mod-say|lang|sounds)-" | sed -e 's/^\([^ ]*\)\s.*/\1/' -e '/-dbg$/d' -e '/-all$/d') \
	sqlite3 ssl-cert nginx php5-cli php5-common php-apc php5-gd \
	php-db php5-fpm php5-memcache php5-sqlite php5-imap php5-mcrypt php5-curl \
	fusionpbx-core fusionpbx-app-calls fusionpbx-app-calls-active fusionpbx-app-call-block \
	fusionpbx-app-contacts fusionpbx-app-destinations fusionpbx-app-dialplan fusionpbx-app-dialplan-inbound \
	fusionpbx-app-dialplan-outbound fusionpbx-app-extensions fusionpbx-app-follow-me fusionpbx-app-gateways \
	fusionpbx-app-ivr-menu fusionpbx-app-login fusionpbx-app-log-viewer fusionpbx-app-modules fusionpbx-app-music-on-hold \
	fusionpbx-app-recordings fusionpbx-app-registrations fusionpbx-app-ring-groups fusionpbx-app-settings \
	fusionpbx-app-sip-profiles fusionpbx-app-sip-status fusionpbx-app-system fusionpbx-app-time-conditions \
	fusionpbx-app-xml-cdr fusionpbx-app-vars fusionpbx-app-voicemails fusionpbx-app-voicemail-greetings \
	fusionpbx-conf fusionpbx-scripts fusionpbx-sqldb fusionpbx-theme-enhanced fusionpbx-music-default

# define configuration environment variables
ENV FREESWITCH_CONF /etc/freeswitch
#ENV FREESWITCH_CONF /etc/fusionpbx/switch/conf
ENV FREESWITCH_DATA /var/lib/freeswitch
ENV FREESWITCH_INIT_REPO https://github.com/spali/freeswitch_conf_minimal.git
ENV FUSIONPBX_WWW_ROOT /var/www
ENV FUSIONPBX_DATA /var/lib/fusionpbx
ENV FUSIONPBX_DB /var/lib/fusionpbx/db
ENV FUSIONPBX_DEFAULT_COUNTRY CH
ENV FUSIONPBX_REPO http://fusionpbx.googlecode.com/svn/trunk/
ENV FUSIONPBX_REVISION HEAD
ENV NGINX_CERTS /etc/nginx/certs

ENV UPLOAD_SIZE 25M

# edit php5-fpm configuration
RUN sed -e "s#^\(\s*\)[;]\{0,1\}\(\s*upload_max_filesize\s\)[^;\S]*#\1\2= ${UPLOAD_SIZE}#" \
	-e "s#^\(\s*\)[;]\{0,1\}\(\s*post_max_size\s\)[^;\S]*#\1\2= ${UPLOAD_SIZE}#" \
	-i /etc/php5/fpm/php.ini
RUN sed -e "s#^\(\s*\)[;]\{0,1\}\(\s*daemonize\s\)[^;\S]*#\1\2= no#" \
	-i /etc/php5/fpm/php-fpm.conf

# edit nginx configuration
COPY nginx_server /etc/nginx/sites-available/fusionpbx
RUN rm /etc/nginx/sites-enabled/default && \
        ln -s /etc/nginx/sites-available/fusionpbx /etc/nginx/sites-enabled/fusionpbx

RUN sed	-e "s#^\(\s*\)[#]\{0,1\}\(\s*worker_processes\s\)[^;\S]*#\1\22#" \
	-e "s#^\(\s*\)[#]\{0,1\}\(\s*multi_accept\s\)[^;\S]*#\1\2on#" \
	-e "s#\(\(\s*\)default_type\s*application/octet-stream\s*;\)#\1\n\n\2open_file_cache max=1000 inactive=20s;\n\2open_file_cache_valid 30s;\n\2open_file_cache_min_uses 2;\n\2open_file_cache_errors off;\n\n\2fastcgi_cache_path /var/cache/nginx levels=1:2 keys_zone=microcache:15M max_size=1000m inactive=60m;\n\n#" \
	-e "s#\(\(\s*\)gzip\s*on\s*;\)#\1\n\2gzip_static on;#" \
	-e '1,/^\s*$/ s/^\s*$/daemon off;\n/' \
	-i /etc/nginx/nginx.conf

RUN adduser freeswitch www-data && \
	adduser freeswitch dialout && \
	adduser www-data freeswitch && \
	adduser www-data audio && \
	adduser www-data dialout

# seems not to be possible in docker without priviledged container
#RUN echo "tmpfs	/tmp	tmpfs	defaults	0	0\n tmpfs	/var/lib/freeswitch/db	tmpfs	defaults	0	0\n tmpfs	/var/tmp	tmpfs	defaults	0	0\n" >>/etc/fstab

#######################################################################################
COPY docker-entrypoint.sh /
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord"]
#######################################################################################
# Define mountable directories.
VOLUME ["$FREESWITCH_CONF", "$FREESWITCH_DATA", "$FUSIONPBX_DATA", "$NGINX_CERTS", "/var/log"]
# expose ports
EXPOSE 80 443 5060 8021 16384  16385  16386  16387  16388  16389  16390  16391  16392  16393
#######################################################################################

