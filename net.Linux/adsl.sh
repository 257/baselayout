# Copyright (c) 2004-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Contributed by Roy Marples (uberlord@gentoo.org)

# void adsl_depend(void)
#
# Sets up the dependancies for the module
adsl_depend() {
	before dhcp
}

# bool adsl_check_installed(void)
#
# Returns 1 if rp-pppoe is installed, otherwise 0
adsl_check_installed() {
	[[ -x /usr/sbin/adsl-start || -x /usr/sbin/pppoe-start ]] && return 0
	${1:-false} && eerror $"For ADSL support, emerge net-dialup/rp-pppoe"
	return 1
}

# bool adsl_setup_vars(char *iface)
#
# Checks to see if the ADSL script has been created or not
adsl_setup_vars() {
	local iface="$1" startstop="$2" cfgexe=

	if [[ -x /usr/sbin/pppoe-start ]]; then
		exe="/usr/sbin/pppoe-${startstop}"
		cfgexe=pppoe-setup
	else
		exe="/usr/sbin/adsl-${startstop}"
		cfgexe=adsl-setup
	fi

	# Decide which configuration to use.  Hopefully there is an
	# interface-specific one
	cfgfile="/etc/ppp/pppoe-${iface}.conf"
	[[ -f ${cfgfile} ]] || cfgfile="/etc/ppp/pppoe.conf"

	if [[ ! -f ${cfgfile} ]]; then
		eerror $"no pppoe.conf file found!"
		eerror $"Please run" "${cfgexe}" $"to create one"
		return 1
	fi

	return 0
}

# bool adsl_start(char *iface)
#
# Start ADSL on an interface by calling adsl-start
#
# Returns 0 (true) when successful, non-zero otherwise
adsl_start() {
	local iface="$1" exe= cfgfile= user= ifvar=$(bash_variable "$1")

	adsl_setup_vars "${iface}" start || return 1

	# Might or might not be set in conf.d/net
	user="adsl_user_${ifvar}"

	# Start ADSL with the cfgfile, but override ETH and PIDFILE
	einfo $"Starting ADSL for" "${iface}"
	${exe} <(cat "${cfgfile}"; \
		echo "ETH=${iface}"; \
		echo "PIDFILE=/var/run/rp-pppoe-${iface}.pid"; \
		[[ -n ${!user} ]] && echo "USER=${!user}") \
		>/dev/null
	eend $?
}

# bool adsl_stop(char *iface)
#
# Returns 0 when there is no ADSL to stop or we stop ADSL successfully
# Otherwise 1
adsl_stop() {
	local iface="$1" exe= cfgfile=

	adsl_check_installed || return 1
	[[ ! -f "/var/run/rp-pppoe-${iface}.pid" ]] && return 0

	adsl_setup_vars "${iface}" stop || return 1

	einfo $"Stopping ADSL for" "${iface}"
	${exe} <(cat "${cfgfile}"; \
		echo "ETH=${iface}"; echo "PIDFILE=/var/run/rp-pppoe-${iface}.pid") \
		>/dev/null
	eend $?

	return 0
}

# vim: set ts=4 :