/*
 * depscan.c
 *
 * Basic frontend for updating the dependency cache.
 *
 * Copyright (C) 2004,2005 Martin Schlemmer <azarah@nosferatu.za.org>
 *
 *
 *      This program is free software; you can redistribute it and/or modify it
 *      under the terms of the GNU General Public License as published by the
 *      Free Software Foundation version 2 of the License.
 *
 *      This program is distributed in the hope that it will be useful, but
 *      WITHOUT ANY WARRANTY; without even the implied warranty of
 *      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *      General Public License for more details.
 *
 *      You should have received a copy of the GNU General Public License along
 *      with this program; if not, write to the Free Software Foundation, Inc.,
 *      675 Mass Ave, Cambridge, MA 02139, USA.
 *
 * $Header$
 */

#include <errno.h>
#ifndef __KLIBC__
# include <locale.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include "rcscripts/rccore.h"

#include "librccore/internal/rccore.h"

char *svcdir_subdirs[] = {
  "softscripts",
  "snapshot",
  "options",
  "started",
  "starting",
  "inactive",
  "stopping",
  NULL
};

char *svcdir_volatile_subdirs[] = {
  "snapshot",
  "broken",
  NULL
};

int create_directory (const char *name);
int create_var_dirs (const char *svcdir);
int delete_var_dirs (const char *svcdir);

int
create_directory (const char *name)
{
  if (!check_arg_str (name))
    return -1;

  /* Check if directory exist, and is not a symlink */
  if (!is_dir (name, 0))
    {
      if (exists (name))
	{
	  /* Remove it if not a directory */
	  if (-1 == unlink (name))
	    {
	      DBG_MSG ("Failed to remove '%s'!\n", name);
	      return -1;
	    }
	}
      /* Now try to create the directory */
      if (-1 == mktree (name, 0755))
	{
	  DBG_MSG ("Failed to create '%s'!\n", name);
	  return -1;
	}
    }

  return 0;
}

int
create_var_dirs (const char *svcdir)
{
  char *tmp_path = NULL;
  int i = 0;

  if (!check_arg_str (svcdir))
    return -1;

  /* Check and create svcdir if needed */
  if (-1 == create_directory (svcdir))
    {
      DBG_MSG ("Failed to create '%s'!\n", svcdir);
      return -1;
    }

  while (NULL != svcdir_subdirs[i])
    {
      tmp_path = rc_strcatpaths (svcdir, svcdir_subdirs[i]);
      if (NULL == tmp_path)
	{
	  DBG_MSG ("Failed to allocate buffer!\n");
	  return -1;
	}

      /* Check and create all the subdirs if needed */
      if (-1 == create_directory (tmp_path))
	{
	  DBG_MSG ("Failed to create '%s'!\n", tmp_path);
	  free (tmp_path);
	  return -1;
	}

      free (tmp_path);
      i++;
    }

  return 0;
}

int
delete_var_dirs (const char *svcdir)
{
  char *tmp_path = NULL;
  int i = 0;

  if (!check_arg_str (svcdir))
    return -1;

  /* Just quit if svcdir do not exist */
  if (!exists (svcdir))
    {
      DBG_MSG ("'%s' does not exist!\n", svcdir);
      return 0;
    }

  while (NULL != svcdir_volatile_subdirs[i])
    {
      tmp_path = rc_strcatpaths (svcdir, svcdir_volatile_subdirs[i]);
      if (NULL == tmp_path)
	{
	  DBG_MSG ("Failed to allocate buffer!\n");
	  return -1;
	}

      /* Skip the directory if it does not exist */
      if (!exists (tmp_path))
	goto _continue;

      /* Check and delete all files and sub directories if needed */
      if (-1 == rmtree (tmp_path))
	{
	  DBG_MSG ("Failed to delete '%s'!\n", tmp_path);
	  free (tmp_path);
	  return -1;
	}

_continue:
      free (tmp_path);
      i++;
    }

  return 0;
}

#if defined(LEGACY_DEPSCAN)

int
main (void)
{
  dyn_buf_t *data;
  FILE *cachefile_fd = NULL;
  char *svcdir = NULL;
  char *cachefile = NULL;
  char *tmp_cachefile = NULL;
  int tmp_cachefile_fd = 0;
  int datasize = 0;

  /* Make sure we do not run into locale issues */
#ifndef __KLIBC__
  setlocale (LC_ALL, "C");
#endif

  if (0 != getuid ())
    {
      EERROR ("Must be root!\n");
      exit (EXIT_FAILURE);
    }

  svcdir = get_cnf_entry (RC_CONFD_FILE_NAME, SVCDIR_CONFIG_ENTRY);
  if (NULL == svcdir)
    {
      EERROR ("Failed to get config entry '%s'!\n", SVCDIR_CONFIG_ENTRY);
      exit (EXIT_FAILURE);
    }

  /* Delete (if needed) volatile directories in svcdir */
  if (-1 == delete_var_dirs (svcdir))
    {
      /* XXX: Not 100% accurate below message ... */
      EERROR ("Failed to delete '%s', %s", svcdir,
	      "or one of its sub directories!\n");
      exit (EXIT_FAILURE);
    }

  /* Create all needed directories in svcdir */
  if (-1 == create_var_dirs (svcdir))
    {
      EERROR ("Failed to create '%s', %s", svcdir,
	      "or one of its sub directories!\n");
      exit (EXIT_FAILURE);
    }

  cachefile = rc_strcatpaths (svcdir, LEGACY_CACHE_FILE_NAME);
  if (NULL == cachefile)
    {
      DBG_MSG ("Failed to allocate buffer!\n");
      exit (EXIT_FAILURE);
    }

  tmp_cachefile = rc_strcatpaths (cachefile, "XXXXXX");
  if (NULL == tmp_cachefile)
    {
      DBG_MSG ("Failed to allocate buffer!\n");
      exit (EXIT_FAILURE);
    }
  /* Replace the "/XXXXXX" with ".XXXXXX"
   * Yes, I am lazy. */
  tmp_cachefile[strlen (tmp_cachefile) - strlen (".XXXXXX")] = '.';

  if (-1 == get_rcscripts ())
    {
      EERROR ("Failed to get rc-scripts list!\n");
      exit (EXIT_FAILURE);
    }

  if (-1 == check_rcscripts_mtime (cachefile))
    {
      EINFO ("Caching service dependencies ...\n");
      DBG_MSG ("Regenerating cache file '%s'.\n", cachefile);

      data = new_dyn_buf ();

      datasize = generate_stage2 (data);
      if (-1 == datasize)
	{
	  EERROR ("Failed to generate stage2!\n");
	  exit (EXIT_FAILURE);
	}

#if 0
      tmp_cachefile_fd = open ("foo", O_CREAT | O_TRUNC | O_RDWR, 0600);
      write (tmp_cachefile_fd, data->data, datasize);
      close (tmp_cachefile_fd);
#endif

      if (-1 == parse_cache (data))
	{
	  EERROR ("Failed to parse stage2 output!\n");
	  free_dyn_buf (data);
	  exit (EXIT_FAILURE);
	}

      free_dyn_buf (data);

      if (-1 == service_resolve_dependencies ())
	{
	  EERROR ("Failed to resolve dependencies!\n");
	  exit (EXIT_FAILURE);
	}

#ifndef __KLIBC__
      tmp_cachefile_fd = mkstemp (tmp_cachefile);
#else
      /* FIXME: Need to add a mkstemp implementation for klibc */
      tmp_cachefile_fd =
       open (tmp_cachefile, O_CREAT | O_TRUNC | O_RDWR, 0600);
#endif
      if (-1 == tmp_cachefile_fd)
	{
	  EERROR ("Could not open temporary file for writing!\n");
	  exit (EXIT_FAILURE);
	}
      
      cachefile_fd = fdopen (tmp_cachefile_fd, "w");
      if (NULL == cachefile_fd)
	{
	  EERROR ("Could not open temporary file for writing!\n");
	  exit (EXIT_FAILURE);
	}

      write_legacy_stage3 (cachefile_fd);
      fclose (cachefile_fd);

      if ((-1 == unlink (cachefile)) && (exists (cachefile)))
	{
	  EERROR ("Could not remove '%s'!\n", cachefile);
	  unlink (tmp_cachefile);
	  exit (EXIT_FAILURE);
	}

      if (-1 == rename (tmp_cachefile, cachefile))
	{
	  EERROR ("Could not move temporary file to '%s'!\n", cachefile);
	  unlink (tmp_cachefile);
	  exit (EXIT_FAILURE);
	}
    }

  exit (EXIT_SUCCESS);
}

#endif
