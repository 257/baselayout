# Copyright 1999-2003 Gentoo Technologies, Inc.
# Distributed under the terms of the GNU General Public License v2
# Author:  Martin Schlemmer <azarah@gentoo.org>
# $Header$

BEGIN {

	extension("/lib/rcscripts/filefuncs.so", "dlload")

	# Get our environment variables
	SVCDIR = ENVIRON["SVCDIR"]
	if (SVCDIR == "") {
		eerror("Could not get SVCDIR!")
		exit 1
	}

	pipe = "ls -1 /etc/env.d/."
	while ((pipe | getline tmpstring) > 0)
		scripts = scripts " /etc/env.d/" tmpstring
	close(pipe)

	split(scripts, TMPENVFILES)

	# Make sure that its a file we are working with,
	# and do not process scripts, source or backup files.
	# NOTE:  do not use 'for (x in TMPENVFILES)', as gawk
	#        have this notion that it should mess with the
	#        order it list things then ....
	for (x = 1;;x++) {
	
		if (x in TMPENVFILES) {
		
			if ((isfile(TMPENVFILES[x])) &&
			    (TMPENVFILES[x] !~ /((\.(sh|c|bak))|\~)$/)) {

				ENVCOUNT++

				ENVFILES[ENVCOUNT] = TMPENVFILES[x]
			}
		} else
			break
	}

	if (ENVCOUNT == 0) {

		eerror("No files to process!")
		exit 1
	}

	ENVCACHE = SVCDIR "/envcache"
	SHPROFILE = "/etc/profile.env"
	CSHPROFILE = "/etc/csh.env"

	# SPECIALS are treated differently.  For each env.d file, the variables are
	# appended seperated with a ':'.  If not in specials, for each env.d file,
	# the variable are just set to the new value.
	tmpspecials="KDEDIRS:PATH:CLASSPATH:LDPATH:MANPATH:INFODIR:INFOPATH:ROOTPATH:CONFIG_PROTECT:CONFIG_PROTECT_MASK:PRELINK_PATH:PRELINK_PATH_MASK"
	split(tmpspecials, SPECIALS, ":")

	unlink(ENVCACHE)

	for (count = 1;count <= ENVCOUNT;count++) {
		
		while ((getline < (ENVFILES[count])) > 0) {

			# Filter out comments
			if ($0 !~ /^[[:space:]]*#/) {

				split($0, envnode, "=")

				if (envnode[2] == "")
					continue

				if ($0 == "")
					continue

				# LDPATH should not be in environment
				if (envnode[1] == "LDPATH")
					continue

				# In bash there should be no space between the variable name and
				# the '=' ...
				if (envnode[1] ~ /[^[:space:]]*[[:space:]]+$/)
					continue

				# strip variable name and '=' from data
				sub("^[[:space:]]*" envnode[1] "[[:space:]]*=", "")
				# Strip all '"' and '\''
				gsub(/\"/, "")
				gsub(/\'/, "")

				if (envnode[1] in ENVTREE) {

					DOSPECIAL = 0

					for (x in SPECIALS) {

						# Is this a special variable ?
						if (envnode[1] == SPECIALS[x])
							DOSPECIAL = 1
					}

					if (DOSPECIAL) {
						split(ENVTREE[envnode[1]], tmpstr, ":")

						# Check that we do not add dups ...
						NODUPS = 1
						for (x in tmpstr)
							if (tmpstr[x] == $0)
								NODUPS = 0
						
						if (NODUPS)
							# Once again, "CONFIG_PROTECT" and "CONFIG_PROTECT_MASK"
							# are handled differently ...
							if ((envnode[1] == "CONFIG_PROTECT") || (envnode[1] == "CONFIG_PROTECT_MASK"))
								ENVTREE[envnode[1]] = ENVTREE[envnode[1]] " " $0
							else
								ENVTREE[envnode[1]] = ENVTREE[envnode[1]] ":" $0
					} else
						ENVTREE[envnode[1]] = $0
				} else
					ENVTREE[envnode[1]] = $0
			}
		}

		close(ENVFILES[count])
	}

	for (x in ENVTREE)
		print "export " x "=\"" ENVTREE[x] "\"" >> (ENVCACHE)

	for (x in ENVTREE) {
	
		# Print this a second time to make sure all variables
		# are expanded ..
		print "export " x "=\"" ENVTREE[x] "\"" >> (ENVCACHE)
		print "echo \"" x "=${" x "}\"" >> (ENVCACHE)
	}

	close (ENVCACHE)

	unlink(SHPROFILE)
	unlink(CSHPROFILE)

	# Add warning header for SHPROFILE
	print "# THIS FILE IS AUTOMATICALLY GENERATED BY env-update." > (SHPROFILE)
	print "# DO NOT EDIT THIS FILE. CHANGES TO STARTUP PROFILES" >> (SHPROFILE)
	print "# GO INTO /etc/profile NOT /etc/profile.env" >> (SHPROFILE)
	print "" >> (SHPROFILE)
	
	# Add warning header for CSHPROFILE
	print "# THIS FILE IS AUTOMATICALLY GENERATED BY env-update." > (CSHPROFILE)
	print "# DO NOT EDIT THIS FILE. CHANGES TO STARTUP PROFILES" >> (CSHPROFILE)
	print "# GO INTO /etc/csh.cshrc NOT /etc/csh.env" >> (CSHPROFILE)
	print "" >> (CSHPROFILE)


	pipe = "bash " ENVCACHE
	while ((pipe | getline) > 0) {

		sub(/=/, "='")
		sub(/$/, "'")

		print "export " $0 >> (SHPROFILE)

		sub(/=/, " ")

		print "setenv " $0 >> (CSHPROFILE)
	}
	
	close(pipe)
	close(SHPROFILE)
	close(CSHPROFILE)
}


# vim:ts=4
