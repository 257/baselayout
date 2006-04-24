# Copyright (c) 2004-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

# Contributed by Roy Marples (uberlord@gentoo.org)

# void dhcpcd_depend(void)
#
# Sets up the dependancies for the module
dhcpcd_depend() {
	after interface
	provide dhcp
	functions interface_exists interface_get_address
}

# void dhcpcd_expose(void)
#
# Expose variables that can be configured
dhcpcd_expose() {
	variables dhcpcd dhcp
}

# bool dhcpcd_check_installed(void)
#
# Returns 1 if dhcpcd is installed, otherwise 0
dhcpcd_check_installed() {
	if [[ -x /sbin/dhcpcd ]]; then
		if dhcpcd -h 2>&1 | grep -q "etcDir" ; then
			return 0
		else
			${1:-false} && eerror "We require dhcpcd-2.0.0 or newer"
			return 1
		fi
	fi

	${1:-false} && eerror "For DHCP (dhcpcd) support, emerge net-misc/dhcpcd"
	return 1
}

# bool dhcpcd_stop(char *iface)
#
# Stop DHCP on an interface by calling dhcpcd -z $iface
#
# Returns 0 (true) when a DHCP address dropped
# otherwise return 1
dhcpcd_stop() {
	local iface=$1 signal pidfile="/var/run/dhcpcd-$1.pid" d

	[[ ! -f ${pidfile} ]] && return 0

	ebegin "Stopping dhcpcd on ${iface}"
	
	local ifvar="$(bash_variable "${iface}")"
	d="dhcp_${ifvar}"
	d=" ${!d} "
	[[ ${d} == "  " ]] && d=" ${dhcp} "

	if [[ ${d} == *" release "* ]] ; then
		/sbin/dhcpcd -k "${iface}"
	else
		start-stop-daemon --stop --exec /sbin/dhcpcd --pidfile "${pidfile}"
	fi
	eend $?
}

# bool dhcpcd_start(char *iface)
#
# Start DHCP on an interface by calling dhcpcd $iface $options
#
# Returns 0 (true) when a DHCP address is obtained, otherwise 1
dhcpcd_start() {
	local iface="$1" opts pidfile="/var/run/dhcpcd-$1.pid"
	local ifvar="$(bash_variable "${iface}")" metric d

	interface_exists "${iface}" true || return 1

	# Get our options
	opts="dhcpcd_${ifvar}"
	opts="${!opts}"

	# Map some generic options to dhcpcd
	d="dhcp_${ifvar}"
	d=" ${!d} "
	[[ ${d} == "  " ]] && d=" ${dhcp} "
	[[ ${d} == *" nodns "* ]] && opts="${opts} -R"
	[[ ${d} == *" nontp "* ]] && opts="${opts} -N"
	[[ ${d} == *" nonis "* ]] && opts="${opts} -Y"
	[[ ${d} == *" nogateway "* ]] && opts="${opts} -G"

	# We transmit the hostname by default
	if [[ " ${d} " != *" nosendhost "* && " ${opts} " != *" -h "* ]]; then
		local hname="$(hostname)"
		[[ -n ${hname} && ${hname} != "(none)" && ${hname} != "localhost" ]] \
			&& opts="-h \"${hname}\" ${opts}"
	fi

	# Stop dhcpcd from bringing the interface down when we exit
	opts="${opts} -o"

	# Add our route metric
	metric="metric_${ifvar}"
	[[ -n ${!metric} && ${!metric} != "0" ]] && opts="${opts} -m ${!metric}"

	# Bring up DHCP for this interface (or alias)
	ebegin "Running dhcpcd"

	eval /sbin/dhcpcd "${opts}" "${iface}"
	eend $? || return 1

	# DHCP succeeded, show address retrieved
	local addr="$( interface_get_address "${iface}" )"
	einfo "${iface} received address ${addr}"

	return 0
}

# vim: set ts=4 :