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

#include "etcutils.h"
VALUE mEtcUtils;
ID id_name, id_passwd, id_uid, id_gid;
uid_t uid_global = 0;
gid_t gid_global = 0;


/* Start of helper functions */
VALUE next_uid(int argc, VALUE *argv, VALUE self)
{
  uid_t req;
  VALUE i;

  rb_scan_args(argc, argv, "01", &i);
  if (NIL_P(i))
    req = uid_global;
  else
    req = NUM2UIDT(i);

  if ((req < 0) || (req > 65533))
    rb_raise(rb_eArgError, "UID must be between 0 and 65533");
  while ( getpwuid(req) ) req++;

  if (NIL_P(i))
    uid_global = req + 1;
  else
    uid_global = req;

  return UIDT2NUM(req);
}

VALUE next_gid(int argc, VALUE *argv, VALUE self)
{
  gid_t req;
  VALUE i;

  rb_scan_args(argc, argv, "01", &i);
  if (NIL_P(i))
    req = gid_global;
  else
    req = NUM2GIDT(i);

  if ((req < 0) || (req > 65533))
    rb_raise(rb_eArgError, "GID must be between 0 and 65533");
  while ( getgrgid(req) ) req++;

  if (NIL_P(i))
    gid_global = req +1;
  else
    gid_global = req;

  return GIDT2NUM(req);
}

VALUE iv_get_time(VALUE self, char *name)
{
  VALUE e = rb_iv_get(self, name);

  if (NUM2INT(e) < 0)
    return Qnil;
  
  time_t t = NUM2INT(e) * 86400;
  return rb_time_new(t, 0);
}

VALUE iv_set_time(VALUE self, VALUE v, char *name)
{
  struct timeval t;
  t.tv_sec = rb_time_timeval(v);

  long int d = ((long)t.tv_sec / 86400);

  if (FIXNUM_P(v) && d == 0 && t.tv_sec == NUM2INT(v))
    d = NUM2INT(v);
  else if (d < 1)
    d = -1;

  return rb_iv_set(self, name, INT2NUM(d));
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

void ensure_file(VALUE io)
{
  Check_Type(io, T_FILE);
}

/*   Great way to validate (s)group members/admins
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
/* End of set/end syscalls */

VALUE eu_sgetpwent(VALUE self, VALUE nam)
{
  VALUE ary, uid, gid, tmp;
  struct passwd *pwd;
  struct group  *grp;

  eu_setpwent(self);
  eu_setgrent(self);

  ary = rb_str_split(nam,":");
  nam = rb_ary_entry(ary,0);
  if (!(pwd = getpwnam( StringValuePtr(nam) ))) {
    pwd->pw_name   = StringValuePtr(nam);
    tmp = rb_ary_entry(ary,1);
    pwd->pw_passwd = StringValuePtr(tmp);

    uid = rb_ary_entry(ary,2);
    if ( NIL_P(uid) || RSTRING_LEN(uid) == 0 )
      uid = next_uid(0, 0, self);
    else if (getpwuid( NUM2UIDT( rb_Integer( uid ) ) )) {
      tmp = rb_Integer( uid );
      uid = next_uid(1, &tmp, self);
    }

    gid = rb_ary_entry(ary,3);
    if ( NIL_P(gid) || RSTRING_LEN(gid) == 0 )
      if ( (grp = getgrnam( StringValuePtr(nam) )) ) {
	gid = GIDT2NUM(grp->gr_gid);
	tmp = uid;
	uid = next_uid(1, &gid, self);
	next_uid(1, &tmp, self);
	next_uid(0, 0, self);
      } else
	gid = next_gid(1, &uid, self);
    else if ( (grp = getgrgid( NUM2GIDT( rb_Integer(gid) ) )) )
      gid = GIDT2NUM(grp->gr_gid);
    else
      rb_raise(rb_eArgError,
	       "Group ID %ld does not exist!", gid);

    pwd->pw_uid = uid;
    pwd->pw_gid = gid;
    pwd->pw_gecos = StringValuePtr( *((VALUE *)(rb_ary_entry(ary,4))) );
    pwd->pw_dir   = StringValuePtr( *((VALUE *)(rb_ary_entry(ary,5))) );
    pwd->pw_shell = StringValuePtr( *((VALUE *)(rb_ary_entry(ary,5))) );
  }

  return setup_passwd(pwd);
}

VALUE eu_sgetspent(VALUE self, VALUE nam)
{
  struct spwd *shadow;

  SafeStringValue(nam);
  if ( !(shadow = sgetspent(StringValuePtr(nam))) )
    rb_raise(rb_eArgError,
	     "can't parse %s into EtcUtils::Shadow", StringValuePtr(nam));

  return setup_shadow(shadow);
}


// name:passwd:gid:members
VALUE eu_sgetgrent(VALUE self, VALUE nam)
{
  VALUE ary, obj, tmp;
  struct group grp;
  eu_setgrent(self);
  eu_setpwent(self);

  ary = rb_str_split(nam,":");
  nam = rb_ary_entry(ary,0);

  if (NIL_P(obj = eu_getgrp(self, nam))) {
    grp.gr_name   = StringValuePtr(nam);

    if ( NIL_P(tmp = rb_ary_entry(ary,1)) || RSTRING_LEN(tmp) == 0 )
      tmp = rb_str_new2("x");

    grp.gr_passwd = StringValuePtr(tmp);

    if ( NIL_P(tmp = rb_ary_entry(ary,2)) || RSTRING_LEN(tmp) == 0 )
      tmp = GIDT2NUM(0);

    tmp = rb_Integer( tmp );
    grp.gr_gid = NUM2GIDT(next_gid(1, &tmp, self));

    if ( (NIL_P(tmp = rb_ary_entry(ary,3))) )
      tmp = rb_str_new2("");

    grp.gr_mem = setup_char_members( rb_str_split(tmp,",") );
    obj = setup_group(&grp);
  }

  return obj;
}

VALUE eu_sgetsgent(VALUE self, VALUE nam)
{
  struct sgrp *gshadow;

  SafeStringValue(nam);
  if ( !(gshadow = sgetsgent(StringValuePtr(nam))) )
    rb_raise(rb_eArgError,
	     "can't parse %s into EtcUtils::GShadow", StringValuePtr(nam));

  return setup_gshadow(gshadow);
}

static VALUE
eu_fgetgrent(VALUE self, VALUE io)
{
  struct group *grp;

  ensure_file(io);
  if ( (grp = fgetgrent(RFILE_FPTR(io))) == NULL )
    return Qnil;

  return setup_group(grp);
}

static VALUE
eu_fgetpwent(VALUE self, VALUE io)
{
  struct passwd *pwd;

  ensure_file(io);
  if ( (pwd = fgetpwent(RFILE_FPTR(io))) == NULL )
    return Qnil;

  return setup_passwd(pwd);
}

static VALUE
eu_fgetspent(VALUE self, VALUE io)
{
  struct spwd *spwd;

  ensure_file(io);
  if ( (spwd = fgetspent(RFILE_FPTR(io))) == NULL )
    return Qnil;

  return setup_shadow(spwd);
}

static VALUE
eu_fgetsgent(VALUE self, VALUE io)
{
  struct sgrp *sgroup;

  ensure_file(io);
  if ( (sgroup = fgetsgent(RFILE_FPTR(io))) == NULL )
    return Qnil;

  return setup_gshadow(sgroup);
}

VALUE eu_getpwd(VALUE self, VALUE v)
{
  struct passwd *strt;
  eu_setpwent(self);

  if (TYPE(v) == T_FIXNUM)
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
  struct spwd *strt;
  eu_setspent(self);

  if (TYPE(v) == T_FIXNUM) {
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
}

VALUE eu_getsgrp(VALUE self, VALUE v)
{
  struct sgrp *strt;
  eu_setsgent(self);

  if (TYPE(v) == T_FIXNUM) {
    struct group *s;
    if ( (s = getgrgid(NUM2UIDT(v))) )
      v = setup_safe_str(s->gr_name);
  }

  SafeStringValue(v);
  strt = getsgnam(StringValuePtr(v));

  if (!strt)
    return Qnil;

  return setup_gshadow(strt);
}

VALUE eu_getgrp(VALUE self, VALUE v)
{
  struct group *strt;
  eu_setgrent(self);

  if (TYPE(v) == T_FIXNUM)
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

static VALUE
eu_putspent(VALUE mod, VALUE entry, VALUE io)
{
  return user_putspent(entry,io);
}

static VALUE
eu_putgrent(VALUE klass, VALUE entry, VALUE io)
{
  return group_putgrent(entry,io);
}

static VALUE
eu_putsgent(VALUE klass, VALUE entry, VALUE io)
{
  return group_putsgent(entry,io);
}

static VALUE
eu_locked_p(VALUE self)
{
  if (lckpwdf())
    return Qtrue;
  else if (!ulckpwdf())
    return Qfalse;
  else
    rb_raise(rb_eIOError,"Unable to determine the locked state of password files");
}

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
static int spwd_block = 0;
static int pwd_block = 0;
static int sgrp_block = 0;
static int grp_block = 0;

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

static VALUE
shadow_iterate(void)
{
  struct spwd *shadow;

  setspent();
  while ( (shadow = getspent()) ) {
    rb_yield(setup_shadow(shadow));
  }
  return Qnil;
}

static VALUE
shadow_ensure(void)
{
  endspent();
  spwd_block = (int)Qfalse;
  return Qnil;
}

static void
each_shadow(void)
{
  if (spwd_block)
    rb_raise(rb_eRuntimeError, "parallel shadow iteration");
  spwd_block = (int)Qtrue;
  rb_ensure(shadow_iterate, 0, shadow_ensure, 0);
}
static VALUE
pwd_iterate(void)
{
  struct passwd *pwd;

  setspent();
  while ( (pwd = getpwent()) ) {
    rb_yield(setup_passwd(pwd));
  }
  return Qnil;
}

static VALUE
pwd_ensure(void)
{
  endpwent();
  pwd_block = (int)Qfalse;
  return Qnil;
}

static void
each_passwd(void)
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

static VALUE
grp_iterate(void)
{
  struct group *grp;

  setgrent();
  while ( (grp = getgrent()) ) {
    rb_yield(setup_group(grp));
  }
  return Qnil;
}

static VALUE
grp_ensure(void)
{
  endgrent();
  grp_block = (int)Qfalse;
  return Qnil;
}

static void
each_group(void)
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

VALUE eu_getspent(VALUE self)
{
  struct spwd *shadow;

  if (rb_block_given_p())
    each_shadow();
  else if ( (shadow = getspent()) )
    return setup_shadow(shadow);
  return Qnil;
}

static VALUE
sgrp_iterate(void)
{
  struct sgrp *sgroup;

  setsgent();
  while ( (sgroup = getsgent()) ) {
    rb_yield(setup_gshadow(sgroup));
  }
  return Qnil;
}

static VALUE
sgrp_ensure(void)
{
  endsgent();
  sgrp_block = (int)Qfalse;
  return Qnil;
}

static void
each_sgrp(void)
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

VALUE eu_to_entry(VALUE self, VALUE(*user_to)(VALUE, VALUE))
{
  VALUE line;
  VALUE rb_io;
  char filename[] = "/tmp/etc_utilsXXXXXX";
  int fd = mkstemp(filename);

  if ( fd == -1 )
    rb_raise(rb_eIOError,
	     "Error creating temp file: %s", strerror(errno));

  rb_io = rb_file_open(filename,"w+");
  user_to(self, rb_io);
  rewind(RFILE_FPTR(rb_io));
  line = rb_io_gets(rb_io);

  if ( close(fd) < 0)
    rb_raise(rb_eIOError, "Error closing temp file: %s", strerror(errno));

  rb_io_close(rb_io);

  if ( unlink(filename) < 0 )
    rb_raise(rb_eIOError, "Error unlinking temp file: %s", strerror(errno));

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


void Init_etcutils()
{
  mEtcUtils = rb_define_module("EtcUtils");
  rb_extend_object(mEtcUtils, rb_mEnumerable);

  rb_cPasswd  = rb_define_class_under(mEtcUtils,"Passwd",rb_cObject);
  rb_cShadow  = rb_define_class_under(mEtcUtils,"Shadow",rb_cObject);
  rb_cGroup   = rb_define_class_under(mEtcUtils,"Group",rb_cObject);
  rb_cGshadow = rb_define_class_under(mEtcUtils,"GShadow",rb_cObject);
  rb_define_const(mEtcUtils, "Gshadow", rb_cGshadow);

  id_name   = rb_intern("@name");
  id_passwd = rb_intern("@passwd");
  id_uid    = rb_intern("@uid");
  id_gid    = rb_intern("@gid");

  // EtcUtils Constants
  rb_define_global_const("PASSWD", setup_safe_str(PASSWD));
#ifdef SHADOW
  rb_define_global_const("SHADOW", setup_safe_str(SHADOW));
#endif

  rb_define_global_const("GROUP", setup_safe_str(GROUP));
#ifdef GSHADOW
  rb_define_global_const("GSHADOW", setup_safe_str(GSHADOW));
#endif

  // EtcUtils Functions
  rb_define_module_function(mEtcUtils,"next_uid",next_uid,-1);
  rb_define_module_function(mEtcUtils,"next_gid",next_gid,-1);
  rb_define_module_function(mEtcUtils,"next_uid=",next_uid,-1);
  rb_define_module_function(mEtcUtils,"next_gid=",next_gid,-1);
  rb_define_module_function(mEtcUtils,"setXXent",eu_setXXent,0);
  rb_define_module_function(mEtcUtils,"endXXent",eu_endXXent,0);

  // Shadow Functions
  rb_define_module_function(mEtcUtils,"getspent",eu_getspent,0);
  rb_define_module_function(mEtcUtils,"find_spwd",eu_getspwd,1);
  rb_define_module_function(mEtcUtils,"setspent",eu_setspent,0);
  rb_define_module_function(mEtcUtils,"endspent",eu_endspent,0);
  rb_define_module_function(mEtcUtils,"sgetspent",eu_sgetspent,1);
  rb_define_module_function(mEtcUtils,"fgetspent",eu_fgetspent,1);
  rb_define_module_function(mEtcUtils,"putspent",eu_putspent,2);
  // Backward compatibility
  rb_define_module_function(mEtcUtils, "getspnam",eu_getspwd,1);

  // Password Functions
  rb_define_module_function(mEtcUtils,"getpwent",eu_getpwent,0);
  rb_define_module_function(mEtcUtils,"find_pwd",eu_getpwd,1);
  rb_define_module_function(mEtcUtils,"setpwent",eu_setpwent,0);
  rb_define_module_function(mEtcUtils,"endpwent",eu_endpwent,0);
  rb_define_module_function(mEtcUtils,"sgetpwent",eu_sgetpwent,1);
  rb_define_module_function(mEtcUtils,"fgetpwent",eu_fgetpwent,1);
  rb_define_module_function(mEtcUtils,"putpwent",eu_putpwent,2);
  // Backward compatibility
  rb_define_module_function(mEtcUtils,"getpwnam",eu_getpwd,1);

  // GShadow Functions
  rb_define_module_function(mEtcUtils,"getsgent",eu_getsgent,0);
  rb_define_module_function(mEtcUtils,"find_sgrp",eu_getsgrp,1);
  rb_define_module_function(mEtcUtils,"setsgent",eu_setsgent,0);
  rb_define_module_function(mEtcUtils,"endsgent",eu_endsgent,0);
  rb_define_module_function(mEtcUtils,"sgetsgent",eu_sgetsgent,1);
  rb_define_module_function(mEtcUtils,"fgetsgent",eu_fgetsgent,1);
  rb_define_module_function(mEtcUtils,"putsgent",eu_putsgent,2);
  // Backward compatibility
  rb_define_module_function(mEtcUtils,"getsgnam",eu_getsgrp,1);

  // Group Functions
  rb_define_module_function(mEtcUtils,"getgrent",eu_getgrent,0);
  rb_define_module_function(mEtcUtils,"find_grp",eu_getgrp,1);
  rb_define_module_function(mEtcUtils,"setgrent",eu_setgrent,0);
  rb_define_module_function(mEtcUtils,"endgrent",eu_endgrent,0);
  rb_define_module_function(mEtcUtils,"sgetgrent",eu_sgetgrent,1);
  rb_define_module_function(mEtcUtils,"fgetgrent",eu_fgetgrent,1);
  rb_define_module_function(mEtcUtils,"putgrent",eu_putgrent,2);
  // Backward compatibility
  rb_define_module_function(mEtcUtils,"getgrnam",eu_getgrp,1);

  // Lock Functions
  rb_define_module_function(mEtcUtils,"lckpwdf",eu_lckpwdf,0);
  rb_define_module_function(mEtcUtils,"ulckpwdf",eu_ulckpwdf,0);
  rb_define_module_function(mEtcUtils,"lock",eu_lock,0);
  rb_define_module_function(mEtcUtils,"unlock",eu_unlock,0);
  rb_define_module_function(mEtcUtils,"locked?",eu_locked_p,0);

  Init_etcutils_user();
  Init_etcutils_group();
}
