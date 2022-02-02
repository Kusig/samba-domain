#!/usr/bin/env bash

set -e
echo "Running $0 $1"

appSetup () {
  echo "Runnig samba setup"
	# Set variables
	DOMAIN=${DOMAIN:-SAMDOM.LOCAL}
	DOMAINPASS=${DOMAINPASS:-youshouldsetapassword}
	JOIN=${JOIN:-false}
	JOINSITE=${JOINSITE:-NONE}
	MULTISITE=${MULTISITE:-false}
	NOCOMPLEXITY=${NOCOMPLEXITY:-false}
	INSECURELDAP=${INSECURELDAP:-false}
	DNSFORWARDER=${DNSFORWARDER:-NONE}
	HOSTIP=${HOSTIP:-NONE}
	LDOMAIN=${DOMAIN,,}
	UDOMAIN=${DOMAIN^^}
	URDOMAIN=${UDOMAIN%%.*}
	SAMBAPARAMS=${SAMBAPARAMETERS}
	INTERFACES=${SAMBAINTERFACES:-NONE}
	JOINDNSBACKEND=${SAMBAJOINDNSBACKEND:-SAMBA_INTERNAL}
	JOINOPTIONS=${SAMBAJOINOPTIONS}
	INITCONFIG=${INITIALCONFIG:-NONE}
	USERPWD=${USERPASSWORD:-NONE}
	echo "Starting with Samba setup params=${SAMBAPARAMS}"
  echo "Starting with Samba interfaces=${INTERFACES}"
  echo "Starting with Samba join dns-backend=${JOINDNSBACKEND}"
  echo "Starting with Samba join options=${JOINOPTIONS}"
  echo "Starting with InitialConfig file=${INITCONFIG}"

	# If multi-site, we need to connect to the VPN before joining the domain
	if [[ ${MULTISITE,,} == "true" ]]; then
		/usr/sbin/openvpn --config /docker.ovpn &
		VPNPID=$!
		echo "Sleeping 30s to ensure VPN connects ($VPNPID)";
		sleep 30
	fi

  # Set host ip option
  if [[ "$HOSTIP" != "NONE" ]]; then
	  	HOSTIP_OPTION="--host-ip=$HOSTIP"
    else
		  HOSTIP_OPTION=""
  fi
	echo "HostIP param=${HOSTIP_OPTION}"

	# Set up samba
	mv /etc/krb5.conf /etc/krb5.conf.orig
	echo "[libdefaults]" > /etc/krb5.conf
	echo "    dns_lookup_realm = false" >> /etc/krb5.conf
	echo "    dns_lookup_kdc = true" >> /etc/krb5.conf
	echo "    default_realm = ${UDOMAIN}" >> /etc/krb5.conf

	# If the finished file isn't there, this is brand new, we're not just moving to a new container
	if [[ ! -f /etc/samba/external/smb.conf ]]; then
	  echo "No configuration detected, setup from scratch"
		mv /etc/samba/smb.conf /etc/samba/smb.conf.orig

    # Load initial configuration if configured
    if [[ "$INITCONFIG" != "NONE" ]]; then
      echo "Using initial configuration file ${INITCONFIG}"
	  	cp "/etc/samba/external/${INITCONFIG}" /etc/samba/smb.conf
    fi

		if [[ ${JOIN,,} == "true" ]]; then
			if [[ ${JOINSITE} == "NONE" ]]; then
		    echo samba-tool domain join ${LDOMAIN} DC -U"${URDOMAIN}\administrator" --password="${DOMAINPASS}" --dns-backend="${JOINDNSBACKEND}" ${JOINOPTIONS}
				samba-tool domain join ${LDOMAIN} DC -U"${URDOMAIN}\administrator" --password="${DOMAINPASS}" --dns-backend="${JOINDNSBACKEND}" ${JOINOPTIONS}
			else
				samba-tool domain join ${LDOMAIN} DC -U"${URDOMAIN}\administrator" --password="${DOMAINPASS}" --site=${JOINSITE} --dns-backend="${JOINDNSBACKEND}" ${JOINOPTIONS}
			fi
		else
			samba-tool domain provision --use-rfc2307 --domain=${URDOMAIN} --realm=${UDOMAIN} --server-role=dc --dns-backend=SAMBA_INTERNAL --adminpass=${DOMAINPASS} ${HOSTIP_OPTION}
			if [[ ${NOCOMPLEXITY,,} == "true" ]]; then
				samba-tool domain passwordsettings set --complexity=off
				samba-tool domain passwordsettings set --history-length=0
				samba-tool domain passwordsettings set --min-pwd-age=0
				samba-tool domain passwordsettings set --max-pwd-age=0
			fi
		fi

		sed -i "/\[global\]/a \
			\\\tidmap_ldb:use rfc2307 = yes\\n\
			wins support = yes\\n\
			template shell = /bin/bash\\n\
			winbind nss info = rfc2307\\n\
			idmap config ${URDOMAIN}: range = 10000-20000\\n\
			idmap config ${URDOMAIN}: backend = ad\
			" /etc/samba/smb.conf
		if [[ $DNSFORWARDER != "NONE" ]]; then
			sed -i "/\[global\]/a \
				\\\tdns forwarder = ${DNSFORWARDER}\
				" /etc/samba/smb.conf
		fi
		if [[ ${INSECURELDAP,,} == "true" ]]; then
			sed -i "/\[global\]/a \
				\\\tldap server require strong auth = no\
				" /etc/samba/smb.conf
		fi
		if [[ $INTERFACES != "NONE" ]]; then
			sed -i "/\[global\]/a \
				\\\tinterfaces = ${INTERFACES}\\n\
				bind interfaces only = yes\
				" /etc/samba/smb.conf
		fi

		# Once we are set up, we'll make the marker file so that we know to use it if we ever spin this up again
		cp /etc/samba/smb.conf /etc/samba/external/smb.conf
	else
	  echo "Existing configuration detected"
		cp /etc/samba/external/smb.conf /etc/samba/smb.conf
	fi
        
	# Set up supervisor
	echo "[supervisord]" > /etc/supervisor/conf.d/supervisord.conf
	echo "nodaemon=true" >> /etc/supervisor/conf.d/supervisord.conf
	echo "user=root" >> /etc/supervisor/conf.d/supervisord.conf
	echo "" >> /etc/supervisor/conf.d/supervisord.conf
	echo "[program:samba]" >> /etc/supervisor/conf.d/supervisord.conf
	echo "command=/usr/sbin/samba --foreground --no-process-group ${SAMBAPARAMS}" >> /etc/supervisor/conf.d/supervisord.conf
	echo "" >> /etc/supervisor/conf.d/supervisord.conf
	echo "[program:webmin]" >> /etc/supervisor/conf.d/supervisord.conf
	echo "command=/usr/bin/perl /usr/share/webmin/miniserv.pl /etc/webmin/miniserv.conf" >> /etc/supervisor/conf.d/supervisord.conf
	if [[ ${MULTISITE,,} == "true" ]]; then
		if [[ -n $VPNPID ]]; then
			kill $VPNPID
		fi
		echo "" >> /etc/supervisor/conf.d/supervisord.conf
		echo "[program:openvpn]" >> /etc/supervisor/conf.d/supervisord.conf
		echo "command=/usr/sbin/openvpn --config /docker.ovpn" >> /etc/supervisor/conf.d/supervisord.conf
	fi

  NOW=$(date)
	echo "Samba container initialisation completed on ${NOW}" > /etc/samba/external/init.txt
	echo "DOMAIN=${DOMAIN}" >> /etc/samba/external/init.txt
	echo "PARMETERS=${SAMBAPARAMETERS}" >> /etc/samba/external/init.txt
  echo "HOSTIP=${HOSTIP}" >> /etc/samba/external/init.txt
  echo "INTERFACES=${INTERFACES}" >> /etc/samba/external/init.txt

	appStart

}

appStart () {
  echo "Runnig samba start"

  if [[ "$USERPWD" != "NONE" ]]; then
  	echo "MasterPassword changed"
    echo "root:${USERPWD}" | chpasswd
  fi

	/usr/bin/supervisord
}

case "$1" in
	start)
		if [[ -f /etc/samba/external/smb.conf ]]; then
		  echo "Copy samba conf"
			cp /etc/samba/external/smb.conf /etc/samba/smb.conf
			appStart
		else
			echo "Config file is missing."
		fi
		;;
	setup)
		# If the supervisor conf isn't there, we're spinning up a new container
		if [[ -f /etc/supervisor/conf.d/supervisord.conf ]]; then
		  echo "Setup already completed"
			appStart
		else
		  echo "Setup needed"
			appSetup
		fi
		;;
esac

exit 0
