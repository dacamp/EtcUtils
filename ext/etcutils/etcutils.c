/********************************************************************

 Ruby C Extension for read write access to the Linux user database

 Copyright (C) 2013 David Campbell

 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:

 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.

********************************************************************/
#include <unistd.h>
#include <time.h>
#include "etcutils.h"

VALUE mEtcUtils;
ID id_name, id_passwd, id_uid, id_gid;
static VALUE uid_global;
static VALUE gid_global;
static VALUE assigned_uids;
static VALUE assigned_gids;

/* Start of helper functions */
VALUE next_uid(int argc, VALUE *argv, VALUE self)
{
  VALUE i;
  uid_t req;

  rb_scan_args(argc, argv, "01", &i);
  if (NIL_P(i))
    i = uid_global;

  i   = rb_Integer(i);
  req = NUM2UINT(i);

  if ( req > ((unsigned int)65533) )
    rb_raise(rb_eArgError, "UID must be between 0 and 65533");

  while ( getpwuid(req) || rb_ary_includes(assigned_uids, UINT2NUM(req)) ) req++;
  if (!argc)
    rb_ary_push(assigned_uids, UINT2NUM(req));
  else
    uid_global = UINT2NUM(req);

  return UINT2NUM(req);
}

VALUE next_gid(int argc, VALUE *argv, VALUE self)
{
  VALUE i;
  gid_t req;

  rb_scan_args(argc, argv, "01", &i);
  if (NIL_P(i))
    i = gid_global;

  i   = rb_Integer(i);
  req = NUM2UINT(i);

  if ( req > ((unsigned int)65533) )
    rb_raise(rb_eArgError, "GID must be between 0 and 65533");

  while ( getgrgid(req) || rb_ary_includes(assigned_gids, UINT2NUM(req)) ) req++;
  if (!argc)
    rb_ary_push(assigned_gids, UINT2NUM(req));
  else
    gid_global = UINT2NUM(req);

  return UINT2NUM(req);
}

VALUE iv_get_time(VALUE self, const char *name)
{
  VALUE e;
  time_t t;
  e = rb_iv_get(self, name);

  if (NIL_P(e) || NUM2INT(e) < 0)
    return Qnil;

  t = NUM2INT(e) * 86400;
  return rb_time_new(t, 0);
}

VALUE iv_set_time(VALUE self, VALUE v, const char *name)
{
  struct timeval t;
  long int d;

  RTIME_VAL(t) = rb_time_timeval(v);
  d = ((long)t.tv_sec / 86400);

  if (FIXNUM_P(v) && d == 0 && t.tv_sec == NUM2INT(v))
    d = NUM2INT(v);
  else if (d < 1)
    d = -1;

  return rb_iv_set(self, name, INT2NUM(d));
}

VALUE rb_current_time()
{
  time_t s;
  s = time(NULL);
  return rb_time_new(s, ((time_t)0));
}

void
eu_errno(VALUE str)
{
  /*
  SafeStringValue(str);
  if ( (errno) && ( !(errno == ENOTTY) || !(errno == ENOENT) ) )
    rb_sys_fail( StringValuePtr(str) );
      Errno::ENOTTY: Inappropriate ioctl for device
      https://bugs.ruby-lang.org/issues/6127
      ioctl range error in 1.9.3
      Fixed in 1.9.3-p194 (REVISION r37138)
      Ubuntu System Ruby (via APT) - 1.9.3-p0 (REVISION 33570)
  errno = 0;
  */
}

void ensure_eu_type(VALUE self, VALUE klass)
{
  if (!rb_obj_is_kind_of(self, klass))
    rb_raise(rb_eTypeError, "wrong argument type %s (expected %s)",
	     rb_obj_classname(self), rb_class2name(klass));
}

void ensure_file(VALUE io)
{
  rb_io_check_initialized(RFILE(io)->fptr);
}

void ensure_writes(VALUE io, int t)
{
  ensure_file(io);
  if (!( ((RFILE(io)->fptr)->mode) & t ))
    rb_raise(rb_eIOError, "not opened for writing");
}



/*  Validate (s)group members/admins
void confirm_members(char ** mem)
{
  char *name;

  while(name = *mem++)
    if (!getpwnam(name))
      rb_raise(rb_eArgError,
	       "%s was not found in '%s'", name, PASSWD);
}
*/

void free_char_members(char ** mem, int c)
{
  if (NULL != mem) {
    int i;
    for (i=0; i<c+1 ; i++) free(mem[i]);
    free(mem);
  }
}

char** setup_char_members(VALUE ary)
{
  char ** mem;
  VALUE tmp,last;
  long i,off;
  Check_Type(ary,T_ARRAY);

  mem = malloc((RARRAY_LEN(ary) + 1)*sizeof(char**));
  if (mem == NULL)
    rb_memerror();

  rb_ary_sort_bang(ary);
  last = rb_str_new2("");
  off = 0;

  for (i = 0; i < RARRAY_LEN(ary); i++) {
    tmp = rb_obj_as_string(RARRAY_PTR(ary)[i]);
    if ( (rb_str_cmp(tmp, last)) ) {
      StringValueCStr(tmp);
      mem[i-off] = malloc((RSTRING_LEN(tmp))*sizeof(char*));;

      if (mem[i-off]  == NULL) rb_memerror();
      strcpy(mem[i-off], RSTRING_PTR(tmp));
    } else
      off++;

    last = tmp;
  }
  mem[i-off] = NULL;

  return mem;
}

VALUE setup_safe_str(const char *str)
{
  return rb_tainted_str_new2(str); // this already handles characters >= 0
}

VALUE setup_safe_array(char **arr)
{
  VALUE mem = rb_ary_new();

  while (*arr)
    rb_ary_push(mem, setup_safe_str(*arr++));
  return mem;
}
/* End of helper functions */

/* set/end syscalls */
VALUE eu_setpwent(VALUE self)
{
#ifdef HAVE_SETPWENT
  setpwent();
#endif
  return Qnil;
}

VALUE eu_endpwent(VALUE self)
{
#ifdef HAVE_ENDPWENT
  endpwent();
#endif
  return Qnil;
}

VALUE eu_setspent(VALUE self)
{
#ifdef HAVE_SETSPENT
  setspent();
#endif
  return Qnil;
}

VALUE eu_endspent(VALUE self)
{
#ifdef HAVE_ENDSPENT
  endspent();
#endif
  return Qnil;
}

VALUE eu_setsgent(VALUE self)
{
#ifdef HAVE_SETSGENT
  setsgent();
#endif
  return Qnil;
}

VALUE eu_endsgent(VALUE self)
{
#ifdef HAVE_ENDSGENT
  endsgent();
#endif
  return Qnil;
}

VALUE eu_setgrent(VALUE self)
{
#ifdef HAVE_SETGRENT
  setgrent();
#endif
  return Qnil;
}

VALUE eu_endgrent(VALUE self)
{
#ifdef HAVE_ENDGRENT
  endgrent();
#endif
  return Qnil;
}

/* INPUT Examples:
 * -  CURRENT USERS
 *   - bin:x:2:2:bin:/bin:/bin/bash
 *   - bin:x:::bin:/bin:/bin/bash
 *   - bin:x:::bin:/bin:/bin/sh
 *   - bin:x:::bin:/bin:/bin/sh
 *   - bin:x:::Bin User:/bin:/bin/sh
 *
 * CURRENT USER
 *   iff *one* of uid/gid is empty
 *      - if VAL is NOT equal to VAL in PASSWD
 *         - if VAL is available
 *             -  Populate VAL
 *         - else raise error
 *      - else Populate VAL
 *   if PASSWORD, UID, GID, GECOS, HOMEDIR, SHELL are empty
 *      - populate VALUE from PASSWD
 */
VALUE eu_parsecurrent(VALUE str, VALUE ary)
{
  struct passwd *pwd;
  pwd = getpwnam( StringValuePtr(str) );

  // Password
  str = rb_ary_entry(ary,1);
  if ( ! rb_eql( setup_safe_str(pwd->pw_passwd), str) )
    pwd->pw_passwd = StringValuePtr(str);

  // UID/GID
  if ( ! RSTRING_BLANK_P( (str = rb_ary_entry(ary,2)) ) ) {
    str = rb_Integer( str );
    if ( ! rb_eql( INT2FIX(pwd->pw_uid), str ) )
      pwd->pw_uid = NUM2UIDT(str);
  }

  if ( ! RSTRING_BLANK_P( (str = rb_ary_entry(ary,3)) ) ) {
    str = rb_Integer( str );
    if ( getgrgid(NUM2GIDT(str)) )
      pwd->pw_gid = NUM2GIDT(str);
  }

  // GECOS
  str = rb_ary_entry(ary,4);
  if ( ! rb_eql( setup_safe_str(pwd->pw_gecos), str) )
    pwd->pw_gecos = StringValuePtr(str);

  // Directory
  str = rb_ary_entry(ary,5);
  if ( ! rb_eql( setup_safe_str(pwd->pw_dir), str) )
    pwd->pw_dir = StringValuePtr(str);

  // Shell
  str = rb_ary_entry(ary,6);
  if ( ! rb_eql( setup_safe_str(pwd->pw_shell), str) ) {
    SafeStringValue(str);
    pwd->pw_shell = StringValuePtr(str);
  }

  return setup_passwd(pwd);
}

/* INPUT Examples:
 * - NEW USERS
 *   - newuser:x:1000:1000:New User:/home/newuser:/bin/bash
 *   - newuser:x:::New User:/home/newuser:/bin/bash
 *   - newuser:x:::New User::/bin/bash
 *
 */
VALUE eu_parsenew(VALUE self, VALUE ary)
{
  VALUE uid, gid, tmp, nam;
  struct passwd *pwd;
  struct group  *grp;
  int i = 0;

  pwd = malloc(sizeof *pwd);

  nam = rb_ary_entry(ary,i++);
  pwd->pw_name = StringValuePtr(nam);

  /* Setup password field
   *   if PASSWORD is empty
   *      - if SHADOW
   *          - PASSWORD equals 'x'
   *      - else
   *          - PASSWORD equals '*'
   */
  tmp = rb_ary_entry(ary,i++);
  if (RSTRING_BLANK_P(tmp))
    tmp = PW_DEFAULT_PASS;

  pwd->pw_passwd = StringValuePtr(tmp);

  /* Setup UID field */
  uid = rb_ary_entry(ary,i++);
  gid = rb_ary_entry(ary,i++);

  /* if UID Test availability */
  if (! RSTRING_BLANK_P(uid))
    next_uid(1, &uid, self);

  uid = next_uid(0, 0, self);

  /*   if GID empty
   *     - if USERNAME found in /etc/group
   *        - GID equals struct group->gid
   *     - else next_gid
   *   else if GID < 1000
   *       - assign GID
   *     - else
   *       - next_gid
   */
  if (RSTRING_BLANK_P(gid))
    if ( (grp = getgrnam( StringValuePtr(nam) )) ) // Found a group with the same name
      gid = GIDT2NUM(grp->gr_gid);
    else {
      next_gid(1, &uid, self);
      gid = next_gid(0, 0, self);
    }
  else {
    tmp = rb_Integer(gid);
    if ( (NUM2UINT(tmp) != 0) && ( NUM2UINT(tmp) < ((unsigned int)1000)) )
      gid = tmp;
    else {
      next_gid(1, &tmp, self);
      gid = next_gid(0, 0, self);
    }
  }

  pwd->pw_uid   = NUM2UIDT(uid);
  pwd->pw_gid   = NUM2GIDT(gid);

  /* _launchservicesd:*:239:239::0:0:_launchservicesd:/var/empty:/usr/bin/false */
  /* daemon:x:1:1:daemon:/usr/sbin:/bin/sh */
  #ifdef HAVE_ST_PW_CLASS
  if ( RSTRING_BLANK_P(tmp = rb_ary_entry(ary, i)) )
    tmp = setup_safe_str("");
  pwd->pw_class = StringValuePtr( tmp );

  i++;
  #endif

  #ifdef HAVE_ST_PW_CHANGE
  if ( RSTRING_BLANK_P(tmp = rb_ary_entry(ary,i)) )
    tmp = setup_safe_str("0");

  pwd->pw_change = (time_t)NUM2UIDT((VALUE)rb_Integer( tmp ));
  i++;
  #endif


  #ifdef HAVE_ST_PW_EXPIRE
  if ( RSTRING_BLANK_P(tmp = rb_ary_entry(ary,i)) )
    tmp = setup_safe_str("0");

  pwd->pw_expire = (time_t)NUM2UIDT((VALUE)rb_Integer( tmp ));
  i++;
  #endif

  /*  if GECOS, HOMEDIR, SHELL is empty
   *     - GECOS defaults to USERNAME
   *     - Assign default VALUE (Need to set config VALUES)
   */
  if ( RSTRING_BLANK_P(tmp = rb_ary_entry(ary,i)) )
    tmp = nam;
  pwd->pw_gecos = StringValuePtr( tmp );
  i++;

  if ( RSTRING_BLANK_P(tmp = rb_ary_entry(ary,i)) )
    tmp = rb_str_plus(setup_safe_str("/home/"), nam);
  pwd->pw_dir   = StringValuePtr( tmp );
  i++;


  /* This might be a null, indicating that the system default
   * should be used.
   */
  if (RSTRING_BLANK_P(tmp = rb_ary_entry(ary,i)) )
    tmp = setup_safe_str(DEFAULT_SHELL);
  pwd->pw_shell = StringValuePtr( tmp );

  tmp = setup_passwd(pwd);

  if (pwd)
    free(pwd);
  return tmp;
}
/* End of set/end syscalls */

/* INPUT Examples:
 * -  CURRENT USERS
 *   - bin:x:2:2:bin:/bin:/bin/bash
 *   - bin:x:::bin:/bin:/bin/bash
 *   - bin:x:::bin:/bin:/bin/sh
 *   - bin:x:::bin:/bin:/bin/sh
 *   - bin:x:::Bin User:/bin:/bin/sh
 *
 * - NEW USERS
 *   - newuser:x:1000:1000:New User:/home/newuser:/bin/bash
 *   - newuser:x:::New User:/home/newuser:/bin/bash
 *   - newuser:x:::New User::/bin/bash
 *
 * UNIVERSAL BEHAVIOR
 *   if USERNAME empty
 *      - raise error
 * CURRENT USER
 *   iff one of uid/gid is empty
 *      - if VAL is NOT equal to VAL in PASSWD
 *         - if VAL is available
 *             -  Populate VAL
 *         - else raise error
 *      - else Populate VAL
 *   if PASSWORD, UID, GID, GECOS, HOMEDIR, SHELL are empty
 *      - populate VALUE from PASSWD
 * NEW USER
 *   if UID/GID are empty
 *     - next_uid/next_gid
 *   else
 *     - Test VALUE availability
 *   then
 *     - Populate UID/GID
 *   if GECOS, HOMEDIR, SHELL is empty
 *     - GECOS defaults to USERNAME
 *     - Assign default VALUE (Need to set config VALUES)
 *   if PASSWORD is empty
 *      - raise Error
 *
 */
VALUE eu_sgetpwent(VALUE self, VALUE str)
{
  VALUE ary;

  eu_setpwent(self);
  eu_setgrent(self);

  ary = rb_str_split(str, ":");
  str = rb_ary_entry(ary,0);

  if (RSTRING_BLANK_P(str))
    rb_raise(rb_eArgError,"User name must be present.");

  if (getpwnam( StringValuePtr(str) ))
    return eu_parsecurrent(str, ary);
  else
    return eu_parsenew(self, ary);
}

VALUE eu_sgetspent(VALUE self, VALUE nam)
{
#ifdef SHADOW
  struct spwd *shadow;

  SafeStringValue(nam);
  if ( !(shadow = sgetspent(StringValuePtr(nam))) )
    rb_raise(rb_eArgError,
	     "can't parse %s into EtcUtils::Shadow", StringValuePtr(nam));

  return setup_shadow(shadow);
#else
  return Qnil;
#endif
}

// name:passwd:gid:members
static VALUE eu_grp_cur(VALUE str, VALUE ary)
{
  struct group *grp;
  grp = getgrnam( StringValuePtr(str) );

  // Password
  str = rb_ary_entry(ary,1);
  if ( ! rb_eql( setup_safe_str(grp->gr_passwd), str) )
    grp->gr_passwd = StringValuePtr(str);

  // GID
  if ( ! RSTRING_BLANK_P( (str = rb_ary_entry(ary,2)) ) ) {
    str = rb_Integer( str );
    if ( !getgrgid(NUM2GIDT(str)) )
      grp->gr_gid = NUM2GIDT(str);
  }

  // Group Members
  if ( RSTRING_BLANK_P( (str = rb_ary_entry(ary,3)) ))
    str = rb_str_new2("");

  ary = rb_str_split(str,",");
  if ( ! rb_eql( setup_safe_array(grp->gr_mem), ary) )
    grp->gr_mem = setup_char_members( ary );

  return setup_group(grp);
}

static VALUE eu_grp_new(VALUE self, VALUE ary)
{
  VALUE gid, tmp, nam;
  struct passwd *pwd;
  struct group  *grp;

  grp = malloc(sizeof *grp);

  nam = rb_ary_entry(ary,0);
  grp->gr_name = StringValuePtr(nam);

  /* Setup password field
   *   if PASSWORD is empty
   *      - if SHADOW
   *          - PASSWORD equals 'x'
   *      - else
   *          - PASSWORD equals '*'
   */
  tmp = rb_ary_entry(ary,1);
  if (RSTRING_BLANK_P(tmp))
    tmp = PW_DEFAULT_PASS;

  grp->gr_passwd = StringValuePtr(tmp);

  /* Setup GID field */
  gid = rb_ary_entry(ary,2);

  /*   if GID empty
   *     - if USERNAME found in /etc/group
   *        - GID equals struct group->gid
   *     - else next_gid
   *   else
   *     - if UID value (as GID) found in /etc/group
   *       - next_gid
   *     - else
   *       - Test availability
   */
  if (RSTRING_BLANK_P(gid))
    if ( (pwd = getpwnam( StringValuePtr(nam) )) ) // Found a group with the same name
      gid = GIDT2NUM(pwd->pw_gid);
    else
      gid = next_gid(0, 0, self);
  else {
    if ( getgrgid( (gid_t) gid ) )
      next_gid(1, &gid, self);
    else if ( (tmp = rb_Integer( gid )) )
      next_gid(1, &tmp, self);

    gid = next_gid(0, 0, self);
  }

  grp->gr_gid   = NUM2GIDT(gid);

  if (RSTRING_BLANK_P(tmp = rb_ary_entry(ary,3)))
    tmp = rb_str_new2("");
  grp->gr_mem = setup_char_members( rb_str_split(tmp,",") );

  nam = setup_group(grp);
  free_char_members(grp->gr_mem, (int)RARRAY_LEN(rb_str_split(tmp,",")));

  if (grp)
    free(grp);
  return nam;
}

// name:passwd:gid:members
VALUE eu_sgetgrent(VALUE self, VALUE str)
{
  VALUE ary;

  eu_setpwent(self);
  eu_setgrent(self);

  ary = rb_str_split(str, ":");
  str = rb_ary_entry(ary,0);

  if (RSTRING_BLANK_P(str))
    rb_raise(rb_eArgError,"Group name must be present.");

  if (getgrnam( StringValuePtr(str) ))
    return eu_grp_cur(str, ary);
  else
    return eu_grp_new(self, ary);
}

VALUE eu_sgetsgent(VALUE self, VALUE nam)
{
#ifdef GSHADOW
  struct sgrp *gshadow;

  SafeStringValue(nam);
  if ( !(gshadow = sgetsgent(StringValuePtr(nam))) )
    rb_raise(rb_eArgError,
	     "can't parse %s into EtcUtils::GShadow", StringValuePtr(nam));

  return setup_gshadow(gshadow);
#else
  return Qnil;
#endif
}


/* fget* functions are not available on OSx/BSD based OSes */
#ifdef HAVE_FGETGRENT
static VALUE
eu_fgetgrent(VALUE self, VALUE io)
{
  struct group *grp;

  ensure_file(io);
  if ( (grp = fgetgrent(RFILE_FPTR(io))) == NULL )
    return Qnil;

  return setup_group(grp);
}
#endif

#ifdef HAVE_FGETPWENT
static VALUE
eu_fgetpwent(VALUE self, VALUE io)
{
  struct passwd *pwd;

  ensure_file(io);
  if ( (pwd = fgetpwent(RFILE_FPTR(io))) == NULL )
    return Qnil;

  return setup_passwd(pwd);
}
#endif

#ifdef HAVE_FGETSPENT
static VALUE
eu_fgetspent(VALUE self, VALUE io)
{
  struct spwd *spwd;

  ensure_file(io);
  if ( (spwd = fgetspent(RFILE_FPTR(io))) == NULL )
    return Qnil;

  return setup_shadow(spwd);
}
#endif

#ifdef HAVE_FGETSGENT
static VALUE
eu_fgetsgent(VALUE self, VALUE io)
{
  struct sgrp *sgroup;

  ensure_file(io);
  if ( (sgroup = fgetsgent(RFILE_FPTR(io))) == NULL )
    return Qnil;

  return setup_gshadow(sgroup);
}
#endif

VALUE eu_getpwd(VALUE self, VALUE v)
{
  struct passwd *strt;
  eu_setpwent(self);

  if ( FIXNUM_P(v) )
    strt = getpwuid(NUM2UIDT(v));
  else {
    SafeStringValue(v);
    strt = getpwnam(StringValuePtr(v));
  }

  if (!strt)
    return Qnil;

  return setup_passwd(strt);
}

VALUE eu_getspwd(VALUE self, VALUE v)
{
#ifdef SHADOW
  struct spwd *strt;
  eu_setspent(self);

  if ( FIXNUM_P(v) ) {
    struct passwd *s;
    if ( (s = getpwuid(NUM2UIDT(v))) )
      v = rb_str_new2(s->pw_name);
    else
      return Qnil;
  }

  SafeStringValue(v);
  strt = getspnam(StringValuePtr(v));

  if (!strt)
    return Qnil;

  return setup_shadow(strt);
#else
  return Qnil;
#endif
}

VALUE eu_getsgrp(VALUE self, VALUE v)
{
#ifdef GSHADOW
  struct sgrp *strt;
  eu_setsgent(self);

  if ( FIXNUM_P(v) ) {
    struct group *s;
    if ( (s = getgrgid(NUM2UIDT(v))) )
      v = setup_safe_str(s->gr_name);
  }

  SafeStringValue(v);
  strt = getsgnam(StringValuePtr(v));

  if (!strt)
    return Qnil;

  return setup_gshadow(strt);
#else
  return Qnil;
#endif
}

VALUE eu_getgrp(VALUE self, VALUE v)
{
  struct group *strt;
  eu_setgrent(self);

  if (FIXNUM_P(v))
    strt = getgrgid(NUM2UIDT(v));
  else {
    SafeStringValue(v);
    strt = getgrnam(StringValuePtr(v));
  }

  if (!strt)
    return Qnil;
  return setup_group(strt);
}

static VALUE
eu_putpwent(VALUE mod, VALUE entry, VALUE io)
{
  return user_putpwent(entry,io);
}

#ifdef SHADOW
static VALUE
eu_putspent(VALUE mod, VALUE entry, VALUE io)
{
  return user_putspent(entry,io);
}
#endif

static VALUE
eu_putgrent(VALUE mod, VALUE entry, VALUE io)
{
  return group_putgrent(entry,io);
}

#ifdef GSHADOW
static VALUE
eu_putsgent(VALUE mod, VALUE entry, VALUE io)
{
  return group_putsgent(entry,io);
}
#endif

#ifdef HAVE_LCKPWDF
static VALUE
eu_locked_p(VALUE self)
{
  int i;
  errno = 0;
  i = lckpwdf();
  if (errno)
    rb_raise(rb_eSystemCallError, "Error locking passwd files: %s", strerror(errno));

  if (i)
    return Qtrue;
  else if (!ulckpwdf())
    return Qfalse;
  else
    rb_raise(rb_eIOError,"Unable to determine the locked state of password files");
}
#endif

#ifdef HAVE_LCKPWDF
static VALUE
eu_lckpwdf(VALUE self)
{
  VALUE r;
  if ( !(r = eu_locked_p(self)) ) {
    if ( !(lckpwdf()) )
      r = Qtrue;
  }
  return r;
}
#endif

#ifdef HAVE_ULCKPWDF
static VALUE
eu_ulckpwdf(VALUE self)
{
  VALUE r;
  if ( (r = eu_locked_p(self)) )
    if ( !(ulckpwdf()) )
      r = Qtrue;
  return r;
}

static int in_lock = 0;

static VALUE
lock_ensure(void)
{
  ulckpwdf();
  in_lock = (int)Qfalse;
  return Qnil;
}

static VALUE
eu_lock(VALUE self)
{
  if (eu_lckpwdf(self)) {
    if (rb_block_given_p()) {
      if (in_lock)
	rb_raise(rb_eRuntimeError, "parallel lock iteration");
      rb_ensure(rb_yield, Qnil, lock_ensure, 0);
      return Qnil;
    }
    return Qtrue;
  } else
    rb_raise(rb_eIOError, "unable to create file lock");
}

static VALUE
eu_unlock(VALUE self)
{
  return eu_ulckpwdf(self);
}
#endif

#ifdef SHADOW
static int spwd_block = 0;

static VALUE shadow_iterate(void)
{
  struct spwd *shadow;

  setspent();
  while ( (shadow = getspent()) )
    rb_yield(setup_shadow(shadow));

  return Qnil;
}

static VALUE shadow_ensure(void)
{
  endspent();
  spwd_block = (int)Qfalse;
  return Qnil;
}

static void each_shadow(void)
{
  if (spwd_block)
    rb_raise(rb_eRuntimeError, "parallel shadow iteration");
  spwd_block = (int)Qtrue;
  rb_ensure(shadow_iterate, 0, shadow_ensure, 0);
}

VALUE eu_getspent(VALUE self)
{
  struct spwd *shadow;

  if (rb_block_given_p())
    each_shadow();
  else if ( (shadow = getspent()) )
    return setup_shadow(shadow);
  return Qnil;
}
#endif

#ifdef PASSWD
static int pwd_block = 0;

static VALUE pwd_iterate(void)
{
  struct passwd *pwd;

  setpwent();
  while ( (pwd = getpwent()) )
    rb_yield(setup_passwd(pwd));
  return Qnil;
}

static VALUE pwd_ensure(void)
{
  endpwent();
  pwd_block = (int)Qfalse;
  return Qnil;
}

static void each_passwd(void)
{
  if (pwd_block)
    rb_raise(rb_eRuntimeError, "parallel passwd iteration");
  pwd_block = (int)Qtrue;
  rb_ensure(pwd_iterate, 0, pwd_ensure, 0);
}

VALUE eu_getpwent(VALUE self)
{
  struct passwd *pwd;

  if (rb_block_given_p())
    each_passwd();
  else if ( (pwd = getpwent()) )
    return setup_passwd(pwd);
  return Qnil;
}
#endif

#ifdef GROUP
static int grp_block = 0;

static VALUE grp_iterate(void)
{
  struct group *grp;

  setgrent();
  while ( (grp = getgrent()) ) {
    rb_yield(setup_group(grp));
  }
  return Qnil;
}

static VALUE grp_ensure(void)
{
  endgrent();
  grp_block = (int)Qfalse;
  return Qnil;
}

static void each_group(void)
{
  if (grp_block)
    rb_raise(rb_eRuntimeError, "parallel group iteration");
  grp_block = (int)Qtrue;
  rb_ensure(grp_iterate, 0, grp_ensure, 0);
}

VALUE eu_getgrent(VALUE self)
{
  struct group *grp;

  if (rb_block_given_p())
    each_group();
  else if ( (grp = getgrent()) )
    return setup_group(grp);
  return Qnil;
}
#endif

#ifdef GSHADOW
static int sgrp_block = 0;

static VALUE sgrp_iterate(void)
{
  struct sgrp *sgroup;

  setsgent();
  while ( (sgroup = getsgent()) )
    rb_yield(setup_gshadow(sgroup));
  return Qnil;
}

static VALUE sgrp_ensure(void)
{
#ifdef HAVE_ENDSGENT
  endsgent();
  sgrp_block = (int)Qfalse;
#endif
  return Qnil;
}

static void each_sgrp(void)
{
  if (sgrp_block)
    rb_raise(rb_eRuntimeError, "parallel gshadow iteration");
  sgrp_block = (int)Qtrue;
  rb_ensure(sgrp_iterate, 0, sgrp_ensure, 0);
}

VALUE eu_getsgent(VALUE self)
{
  struct sgrp *sgroup;

  if (rb_block_given_p())
    each_sgrp();
  else if ( (sgroup = getsgent()) )
    return setup_gshadow(sgroup);
  return Qnil;
}
#endif

VALUE eu_to_entry(VALUE self, VALUE(*user_to)(VALUE, VALUE))
{
  size_t ln;
  VALUE line, io;
  char filename[] = "/tmp/etc_utilsXXXXXX";
  int fd = mkstemp(filename);

  if ( fd == -1 )
    rb_raise(rb_eIOError,
	     "Error creating temp file: %s", strerror(errno));

  io = rb_file_open(filename,"w+");

  line = user_to(self, io);
  if (!rb_obj_is_kind_of(line, rb_cString)) {
    rewind(RFILE_FPTR(io));
    line = rb_io_gets(io);
  }

  if ( close(fd) < 0)
    rb_raise(rb_eIOError, "Error closing temp file: %s", strerror(errno));

  rb_io_close(io);

  if ( unlink(filename) < 0 )
    rb_raise(rb_eIOError, "Error unlinking temp file: %s", strerror(errno));

  if (NIL_P(line))
    return Qnil;

  ln = RSTRING_LEN(line);

  if (RSTRING_PTR(line)[ln-1] == '\n')
    rb_str_resize(line, ln-1);

  return line;
}

static VALUE
eu_setXXent(VALUE self)
{
  eu_setpwent(self);
  eu_setgrent(self);
  eu_setspent(self);
  eu_setsgent(self);
  return Qnil;
}

static VALUE
eu_endXXent(VALUE self)
{
  eu_endpwent(self);
  eu_endgrent(self);
  eu_endspent(self);
  eu_endsgent(self);
  return Qnil;
}

static VALUE
eu_getlogin(VALUE self)
{
  struct passwd *pwd;

  pwd = getpwuid(geteuid());
  return setup_passwd(pwd);
}

static VALUE
eu_passwd_p(VALUE self)
{
#ifdef PASSWD
  return Qtrue;
#else
  return Qfalse;
#endif
}

static int
eu_file_readable_p(const char *fname)
{
  if (eaccess(fname, R_OK) < 0) return Qfalse;
  return Qtrue;
}

static VALUE
eu_read_passwd_p(VALUE self)
{
  if (eu_passwd_p(self))
    return eu_file_readable_p(PASSWD);
  return Qfalse;
}

static VALUE
eu_shadow_p(VALUE self)
{
#ifdef SHADOW
  return Qtrue;
#else
  return Qfalse;
#endif
}

static VALUE
eu_read_shadow_p(VALUE self)
{
#ifdef SHADOW
  if (eu_shadow_p(self))
    return eu_file_readable_p(SHADOW);
#endif
  return Qfalse;
}

static VALUE
eu_group_p(VALUE self)
{
#ifdef GROUP
  return Qtrue;
#else
  return Qfalse;
#endif
}

static VALUE
eu_read_group_p(VALUE self)
{
  if (eu_group_p(self))
    return eu_file_readable_p(GROUP);
  return Qfalse;
}

static VALUE
eu_gshadow_p(VALUE self)
{
#ifdef GSHADOW
  return Qtrue;
#else
  return Qfalse;
#endif
}

static VALUE
eu_read_gshadow_p(VALUE self)
{
#ifdef GSHADOW
  if (eu_gshadow_p(self) && eu_file_readable_p(GSHADOW))
    if (getsgent()) {
      setsgent();
      return Qtrue;
    }
#endif
  return Qfalse;
}

static VALUE
eu_lockable_p(VALUE self)
{
#if defined(HAVE_LCKPWDF) ||defined(HAVE_ULCKPWDF)
  return Qtrue;
#else
  return Qfalse;
#endif
}

void Init_etcutils()
{
  mEtcUtils = rb_define_module("EtcUtils");

  assigned_uids = rb_ary_new();
  assigned_gids = rb_ary_new();
  uid_global    = UINT2NUM((uid_t)0);
  gid_global    = UINT2NUM((gid_t)0);

  rb_global_variable(&assigned_uids);
  rb_global_variable(&assigned_gids);
  rb_global_variable(&uid_global);
  rb_global_variable(&gid_global);

  rb_cPasswd  = rb_define_class_under(mEtcUtils,"Passwd",rb_cObject);
  rb_extend_object(rb_cPasswd, rb_mEnumerable);

  rb_cShadow  = rb_define_class_under(mEtcUtils,"Shadow",rb_cObject);
  rb_extend_object(rb_cShadow, rb_mEnumerable);

  rb_cGroup   = rb_define_class_under(mEtcUtils,"Group",rb_cObject);
  rb_extend_object(rb_cGroup, rb_mEnumerable);

  rb_cGshadow = rb_define_class_under(mEtcUtils,"GShadow",rb_cObject);
  rb_extend_object(rb_cGshadow, rb_mEnumerable);
  rb_define_const(mEtcUtils, "Gshadow", rb_cGshadow);

  id_name   = rb_intern("@name");
  id_passwd = rb_intern("@passwd");
  id_uid    = rb_intern("@uid");
  id_gid    = rb_intern("@gid");

  /* EtcUtils Constants */
#ifdef PASSWD
  rb_define_const(mEtcUtils, "PASSWD", setup_safe_str(PASSWD));
#endif
#ifdef SHADOW
  rb_define_const(mEtcUtils, "SHADOW", setup_safe_str(SHADOW));
#endif
#ifdef GROUP
  rb_define_const(mEtcUtils, "GROUP", setup_safe_str(GROUP));
#endif
#ifdef GSHADOW
  rb_define_const(mEtcUtils, "GSHADOW", setup_safe_str(GSHADOW));
#endif
  rb_define_const(mEtcUtils, "SHELL", setup_safe_str(DEFAULT_SHELL));

  /* EtcUtils Reflective Functions */
  rb_define_module_function(mEtcUtils,"me",eu_getlogin,0);
  rb_define_module_function(mEtcUtils,"getlogin",eu_getlogin,0);
  /* EtcUtils Truthy Functions */
  rb_define_module_function(mEtcUtils,"has_passwd?",eu_passwd_p,0);
  rb_define_module_function(mEtcUtils,"read_passwd?",eu_read_passwd_p,0);
  rb_define_module_function(mEtcUtils,"has_shadow?",eu_shadow_p,0);
  rb_define_module_function(mEtcUtils,"read_shadow?",eu_read_shadow_p,0);
  rb_define_module_function(mEtcUtils,"has_group?",eu_group_p,0);
  rb_define_module_function(mEtcUtils,"read_group?",eu_read_group_p,0);
  rb_define_module_function(mEtcUtils,"has_gshadow?",eu_gshadow_p,0);
  rb_define_module_function(mEtcUtils,"read_gshadow?",eu_read_gshadow_p,0);
  rb_define_module_function(mEtcUtils,"can_lockfile?",eu_lockable_p,0);
  /* EtcUtils Module functions */
  rb_define_module_function(mEtcUtils,"next_uid",next_uid,-1);
  rb_define_module_function(mEtcUtils,"next_gid",next_gid,-1);
  rb_define_module_function(mEtcUtils,"next_uid=",next_uid,-1);
  rb_define_module_function(mEtcUtils,"next_gid=",next_gid,-1);
  rb_define_module_function(mEtcUtils,"setXXent",eu_setXXent,0);
  rb_define_module_function(mEtcUtils,"endXXent",eu_endXXent,0);
  /* EtcUtils Lock Functions */
#ifdef HAVE_LCKPWDF
  rb_define_module_function(mEtcUtils,"lckpwdf",eu_lckpwdf,0);
  rb_define_module_function(mEtcUtils,"lock",eu_lock,0);
  rb_define_module_function(mEtcUtils,"locked?",eu_locked_p,0);
#endif
#ifdef HAVE_ULCKPWDF
  rb_define_module_function(mEtcUtils,"ulckpwdf",eu_ulckpwdf,0);
  rb_define_module_function(mEtcUtils,"unlock",eu_unlock,0);
#endif


#ifdef SHADOW
  /* EU::Shadow module helpers */
  rb_define_module_function(mEtcUtils,"getspent",eu_getspent,0);
  rb_define_module_function(mEtcUtils,"find_spwd",eu_getspwd,1);
  rb_define_module_function(mEtcUtils,"setspent",eu_setspent,0);
  rb_define_module_function(mEtcUtils,"endspent",eu_endspent,0);
  rb_define_module_function(mEtcUtils,"sgetspent",eu_sgetspent,1);
  rb_define_module_function(mEtcUtils,"fgetspent",eu_fgetspent,1);
  rb_define_module_function(mEtcUtils,"putspent",eu_putspent,2);
  /* Backward compatibility */
  rb_define_module_function(mEtcUtils, "getspnam",eu_getspwd,1);
#endif

#ifdef PASSWD
  /* EU::Passwd module helpers */
  rb_define_module_function(mEtcUtils,"getpwent",eu_getpwent,0);
  rb_define_module_function(mEtcUtils,"find_pwd",eu_getpwd,1);
  rb_define_module_function(mEtcUtils,"setpwent",eu_setpwent,0);
  rb_define_module_function(mEtcUtils,"endpwent",eu_endpwent,0);
  rb_define_module_function(mEtcUtils,"sgetpwent",eu_sgetpwent,1);
#ifdef HAVE_FGETPWENT
  rb_define_module_function(mEtcUtils,"fgetpwent",eu_fgetpwent,1);
#endif
  rb_define_module_function(mEtcUtils,"putpwent",eu_putpwent,2);
  /* Backward compatibility */
  rb_define_module_function(mEtcUtils,"getpwnam",eu_getpwd,1);
#endif

#ifdef GSHADOW
  /* EU::GShadow module helpers */
  rb_define_module_function(mEtcUtils,"getsgent",eu_getsgent,0);
  rb_define_module_function(mEtcUtils,"find_sgrp",eu_getsgrp,1);
  rb_define_module_function(mEtcUtils,"setsgent",eu_setsgent,0);
  rb_define_module_function(mEtcUtils,"endsgent",eu_endsgent,0);
  rb_define_module_function(mEtcUtils,"sgetsgent",eu_sgetsgent,1);
  rb_define_module_function(mEtcUtils,"fgetsgent",eu_fgetsgent,1);
  rb_define_module_function(mEtcUtils,"putsgent",eu_putsgent,2);
  /* Backward compatibility */
  rb_define_module_function(mEtcUtils,"getsgnam",eu_getsgrp,1);
#endif

#ifdef GROUP
  /* EU::Group module helpers */
  rb_define_module_function(mEtcUtils,"getgrent",eu_getgrent,0);
  rb_define_module_function(mEtcUtils,"find_grp",eu_getgrp,1);
  rb_define_module_function(mEtcUtils,"setgrent",eu_setgrent,0);
  rb_define_module_function(mEtcUtils,"endgrent",eu_endgrent,0);
  rb_define_module_function(mEtcUtils,"sgetgrent",eu_sgetgrent,1);
#ifdef HAVE_FGETGRENT
  rb_define_module_function(mEtcUtils,"fgetgrent",eu_fgetgrent,1);
#endif
  rb_define_module_function(mEtcUtils,"putgrent",eu_putgrent,2);
  /* Backward compatibility */
  rb_define_module_function(mEtcUtils,"getgrnam",eu_getgrp,1);
#endif

  Init_etcutils_user();
  Init_etcutils_group();
}
