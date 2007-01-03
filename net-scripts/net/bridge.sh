# Copyright 2004-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Contributed by Roy Marples (uberlord@gentoo.org)

# Fix any potential localisation problems
# Note that LC_ALL trumps LC_anything_else according to locale(7)
brctl() {
	LC_ALL=C /sbin/brctl "$@"
}
# void bridge_depend(void)
#
# Sets up the dependancies for the module
bridge_depend() {
	before interface macnet
	functions interface_down interface_del_addresses interface_set_flag
}

# void bridge_expose(void)
#
# Expose variables that can be configured
bridge_expose() {
	variables bridge bridge_add brctl
}

# bool bridge_check_installed(void)
#
# Returns 1 if bridge is installed, otherwise 0
bridge_check_installed() {
	[[ -x /sbin/brctl ]] && return 0
	${1:-false} && eerror "For bridge support, emerge net-misc/bridge-utils"
	return 1
}

# char* bridge_get_ports(char *interface)
#
# Returns the interfaces added to the given bridge
bridge_get_ports() {
	brctl show 2>/dev/null \
		| sed -n -e '/^'"$1"'[[:space:]]/,/^\S/ { /^\('"$1"'[[:space:]]\|\t\)/s/^.*\t//p }'
}

# char* bridge_get_bridge(char *interface)
#
# Returns the bridge interface of the given interface
bridge_get_bridge() {
	local myiface="$1"
	local bridge= idx= stp= iface= x=
	while read bridge idx stp iface x ; do
		if [[ -z ${iface} ]] ; then
			iface="${stp}"
			stp="${idx}"
			idx="${bridge}"
		fi
		if [[ ${iface} == "${myiface}" ]] ; then
			echo "${bridge}"
			return 0
		fi
	done < <(brctl show 2>/dev/null)
}

# bool bridge_exists(char *interface)
#
# Returns 0 if the bridge exists, otherwise 1
bridge_exists() {
	brctl show 2>/dev/null | grep -q "^$1[[:space:]]"
}

# bool bridge_create(char *interface)
#
# Creates the bridge - no ports are added here though
# Returns 0 on success otherwise 1
bridge_create() {
	local iface="$1" ifvar=$(bash_variable "$1") x= i= opts=

	ebegin "Creating bridge ${iface}"
	x=$(brctl addbr "${iface}" 2>&1)
	if [[ -n ${x} ]] ; then
		if [[ ${x//Package not installed/} != "${x}" ]] ; then
			eend 1 "Bridging (802.1d) support is not present in this kernel"
		else
			eend 1 "${x}"
		fi
		return 1
	fi

	opts="brctl_${ifvar}[@]"
	for i in "${!opts}" ; do
		x="${i/ / ${iface} }"
		[[ ${x} == "${i}" ]] && x="${x} ${iface}"
		x=$(brctl ${x} 2>&1 1>/dev/null)
		[[ -n ${x} ]] && ewarn "${x}"
	done
	eend 0
}

# bool bridge_add_port(char *interface, char *port)
#
# Adds the port to the bridge
bridge_add_port() {
	local iface="$1" port="$2" e=

	interface_set_flag "${port}" promisc true
	interface_up "${port}"
	e=$(brctl addif "${iface}" "${port}" 2>&1)
	if [[ -n ${e} ]] ; then
		interface_set_flag "${port}" promisc false
		echo "${e}" >&2
		return 1
	fi
	return 0
}

# bool bridge_delete_port(char *interface, char *port)
#
# Deletes a port from a bridge
bridge_delete_port() {
	interface_set_flag "$2" promisc false
	brctl delif "$1" "$2"
}

# bool bridge_start(char *iface)
#
# set up bridge
# This can also be called by non-bridges so that the bridge can be created
# dynamically
bridge_pre_start() {
	local iface="$1" ports= briface= i= ifvar=$(bash_variable "$1") opts=
	ports="bridge_${ifvar}[@]"
	briface="bridge_add_${ifvar}"
	opts="brctl_${ifvar}[@]"

	[[ -z ${!ports} && -z ${!briface} && -z ${!opts} ]] && return 0

	# Destroy the bridge if it exists
	[[ -n ${!ports} ]] && bridge_stop "${iface}"

	# Allow ourselves to add to the bridge
	if [[ -z ${!ports} && -n ${!briface} ]] ; then
		ports="${iface}"
		iface="${!briface}"
	else
		ports="${!ports}"
		# We are the bridge, so set our base metric to 1000.
		metric=1000
	fi

	# Create the bridge if needed
	bridge_exists "${iface}" || bridge_create "${iface}"

	if [[ -n ${ports} ]] ; then
		einfo "Adding ports to ${iface}"
		eindent

		for i in ${ports} ; do
			interface_exists "${i}" true || return 1 
		done

		for i in ${ports} ; do
			ebegin "${i}"
			bridge_add_port "${iface}" "${i}"
			eend $? || return 1
		done
		eoutdent
	fi

	return 0
}

# bool bridge_stop(char *iface)
#
# Removes the device
# returns 0
bridge_stop() {
	local iface="$1" ports= i= deletebridge=false extra=""

	if bridge_exists "${iface}" ; then
		ebegin "Destroying bridge ${iface}"
		interface_down "${iface}"
		ports=$(bridge_get_ports "${iface}")
		deletebridge=true
		eindent
	else
		# Work out if we're added to a bridge for removal or not
		ports="${iface}"
		iface=$(bridge_get_bridge "${iface}")
		[[ -z ${iface} ]] && return 0
		extra=" from ${iface}"
	fi

	for i in ${ports} ; do
		ebegin "Removing port ${i}${extra}"
		bridge_delete_port "${iface}" "${i}"
		eend $?
	done

	if ${deletebridge} ; then
		eoutdent
		brctl delbr "${iface}" &>/dev/null
		eend 0
	fi
	return 0
}

# vim: set ts=4 :
