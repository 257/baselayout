# Copyright (c) 2004-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Contributed by Roy Marples (uberlord@gentoo.org)
# Many thanks to all the people in the Gentoo forums for their ideas and
# motivation for me to make this and keep on improving it

# Load our config if it exists
[[ -f "$(add_suffix "/etc/conf.d/wireless" )" ]] \
	&& source "$(add_suffix "/etc/conf.d/wireless" )"

# void essidnet_depend(void)
#
# Sets up the dependancies for the module
essidnet_depend() {
	before interface system
	after wireless
	installed wireless
	functions wireless_exists wireless_get_essid wireless_get_ap_mac_address
}

# bool essidnet_start(char *iface)
#
# All interfaces and module scripts can depend on the variables function
# which returns a space seperated list of user configuration variables
# We can override each variable here from a given ESSID or the MAC
# of the AP connected to. MAC configuration takes precedence
# Always returns 0
essidnet_pre_start() {
	local iface="$1"

	wireless_exists "${iface}" || return 0

	local mac=$(wireless_get_ap_mac_address "${iface}")
	local ESSID=$(wireless_get_essid "${iface}")
	local essid=$(bash_variable "${ESSID}")
	mac="${mac//:/}"

	vebegin $"Configuring" "${iface}" $"for ESSID" \
		"\"${ESSID//\\\\/\\\\}\"" 2>/dev/null
	configure_variables "${iface}" "${essid}" "${mac}"

	# Backwards compat for old gateway var
	x="gateway_${essid}"
	[[ -n ${!x} ]] && gateway="${iface}/${!x}"

	veend 0 2>/dev/null
	return 0
}

# vim: set ts=4 :