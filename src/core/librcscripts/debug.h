/*
 * debug.h
 *
 * Simle debugging/logging macro's and functions.
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

#ifndef _DEBUG_H
#define _DEBUG_H

#include <errno.h>
#include <stdio.h>

#include "rcscripts.h"

#define save_errno()	int old_errno = errno;
#define restore_errno() errno = old_errno;
#define saved_errno	old_errno

void
debug_message (const char *file, const char *func, int line,
	       const char *format, ...);

#define DBG_MSG(_format, _arg...) \
 do { \
   debug_message (__FILE__, __FUNCTION__, __LINE__, _format, ## _arg); \
 } while (0)

#define FATAL_ERROR() \
 do { \
   save_errno (); \
   fprintf(stderr, "ERROR: file '%s', function '%s', line %i.\n", \
	   __FILE__, __FUNCTION__, __LINE__); \
   restore_errno (); \
   if (0 != errno) \
     { \
       perror("ERROR"); \
     } \
   exit(EXIT_FAILURE); \
 } while (0)

#define NEG_FATAL_ERROR(_x) \
 do { \
   if (-1 == _x) \
     { \
       FATAL_ERROR(); \
     } \
 } while (0)

#define NULL_FATAL_ERROR(_x) \
 do { \
   if (NULL == _x) \
     { \
       FATAL_ERROR(); \
     } \
 } while (0)

inline bool __check_ptr (const void *ptr, const char *file, const char *func,
			 size_t line);
inline bool __check_str (const char *str, const char *file, const char *func,
			 size_t line);
inline bool __check_strv (char **str, const char *file, const char *func,
			  size_t line);
inline bool __check_fd (int fd, const char *file, const char *func,
			size_t line);
inline bool __check_fp (FILE * fp, const char *file, const char *func,
			size_t line);

#define check_ptr(_ptr) \
 __check_ptr (_ptr, __FILE__, __FUNCTION__, __LINE__)
#define check_str(_str) \
 __check_str (_str, __FILE__, __FUNCTION__, __LINE__)
#define check_strv(_str) \
 __check_strv (_str, __FILE__, __FUNCTION__, __LINE__)
#define check_fd(_fd) \
 __check_fd (_fd, __FILE__, __FUNCTION__, __LINE__)
#define check_fp(_fp) \
 __check_fp (_fp, __FILE__, __FUNCTION__, __LINE__)

inline void *__xcalloc (size_t nmemb, size_t size, const char *file,
			const char *func, size_t line);
inline void *__xmalloc (size_t size, const char *file, const char *func,
			size_t line);
inline void *__xrealloc (void *ptr, size_t size, const char *file,
			 const char *func, size_t line);

#define xcalloc(_nmemb, _size) \
 __xcalloc (_nmemb, _size, __FILE__, __FUNCTION__, __LINE__)
#define xmalloc(_size) \
 __xmalloc (_size, __FILE__, __FUNCTION__, __LINE__)
#define xrealloc(_ptr, _size) \
 __xrealloc (_ptr, _size, __FILE__, __FUNCTION__, __LINE__)

inline char *__xstrndup (const char *str, size_t size, const char *file,
			 const char *func, size_t line);

#define xstrndup(_str, _size) \
 __xstrndup (_str, _size, __FILE__, __FUNCTION__, __LINE__)

#endif /* _DEBUG_H */