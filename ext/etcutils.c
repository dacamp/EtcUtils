/************************************************

 etc_utils.c -

 Ruby C extention for systems that use shadow suite.

 This file was inspired by the original libshadow-ruby package created
 by Takaaki.Tateishi(ttate@jaist.ac.jp), however has been heavily
 modified to mimic the Ruby Standard Library Etc module.

 Find the original libshadow-ruby (1.4.1-8build1) for Ubuntu here:
 http://packages.ubuntu.com/precise/libshadow-ruby.

 This is a free software licence, compatible with the GPL via
 an explicit dual-licensing clause under the Ruby License. Free for
 any use at your own risk! http://www.ruby-lang.org/en/about/license.txt

 Original work Copyright (C) 1998-1999 by Takaaki.Tateishi(ttate@jaist.ac.jp)
 Modified work Copyright 2013 David Campbell (david@mrcampbell.org)
 Modified at: <1999/8/19 06:48:18 by ttate>
 Modified at: <2013/7/4 23:25:28 UTC by dcampbell>

************************************************/

#include "ruby.h"
#ifdef HAVE_RUBYIO_H
#include "rubyio.h"
#else
#include "ruby/io.h"
#endif

static VALUE safe_setup_str(const char *str);

#ifdef HAVE_RUBY_ENCODING_H
#include "ruby/encoding.h"

/* This is somewhat cheating since you *could* drop in an encoding
header in pre-1.9 revs, but should handle all regular use-cases.  In
the event that there actually is a overlap, change the extconf and
serach for stdio_file */
#define RFILE_FPTR(x) rb_io_stdio_file( RFILE(x)->fptr )
#define RFILE_PATH(x) (RFILE(x)->fptr)->pathv
#else
#define RFILE_FPTR(x) (RFILE(x)->fptr)->f
#define RFILE_PATH(x) ( safe_setup_str( (RFILE(x)->fptr)->path ) )
#endif

#ifndef UIDT2NUM
#define UIDT2NUM(v) UINT2NUM(v)
#endif
#ifndef NUM2UIDT
#define NUM2UIDT(v) NUM2UINT(v)
#endif
#ifndef GIDT2NUM
#define GIDT2NUM(v) UINT2NUM(v)
#endif
#ifndef NUM2GIDT
#define NUM2GIDT(v) NUM2UINT(v)
#endif

#ifdef HAVE_SHADOW_H
#include <shadow.h>
#endif
#ifdef HAVE_PWD_H
#include <pwd.h>
#endif
#ifdef HAVE_GSHADOW_H
#include <gshadow.h>
#endif
#ifdef HAVE_GSHADOW__H
#include <gshadow_.h>
#endif
#ifdef HAVE_GRP_H
#include <grp.h>
#endif

#ifndef PASSWD
#define PASSWD "/etc/passwd"
#endif

#ifndef GROUP
#define GROUP "/etc/group"
#endif

#ifdef HAVE_ST_SG_NAMP
#define SGRP_NAME(s) (s)->sg_namp
#else
#define SGRP_NAME(s) (s)->sg_name
#endif

static VALUE cShadow;
static VALUE cGShadow;
static VALUE cPasswd;
static VALUE cGroup;

/* Start of helper functions */
static VALUE
next_uid( VALUE self, VALUE i )
{
  uid_t req = NUM2UIDT(i);
  if ((req < 1) || (req > 65533))
    rb_raise(rb_eArgError, "UID must be between 1 and 65533");
  while ( getpwuid(req) ) req++;
  return UIDT2NUM(req);
}

static VALUE
next_gid (VALUE self, VALUE i )
{
  gid_t req = NUM2GIDT(i);
  if ((req < 1) || (req > 65533))
    rb_raise(rb_eArgError, "GID must be between 1 and 65533");
  while ( getgrgid(req) ) req++;
  return GIDT2NUM(req);
}

static void
etcutils_errno(VALUE str)
{
  // SafeStringValue(str);
  // if ( (errno) && ( !(errno == ENOTTY) || !(errno == ENOENT) ) )
  //  rb_sys_fail( StringValuePtr(str) );
  /*  
      Errno::ENOTTY: Inappropriate ioctl for device
      https://bugs.ruby-lang.org/issues/6127
      ioctl range error in 1.9.3
      Fixed in 1.9.3-p194 (REVISION r37138)
      Ubuntu System Ruby (via APT) - 1.9.3-p0 (REVISION 33570)
  */
  //errno = 0;
}

static void
ensure_file(VALUE io)
{
  Check_Type(io, T_FILE);
}

static void
free_char_members(char ** mem, int c)
{
  if (NULL != mem) {
    int i=0;
    for (i=0; i<c+1 ; i++) free(mem[i]);
    free(mem);
  }
}

static char**
setup_char_members(VALUE ary)
{
  char ** mem;
  VALUE temp;
  long i;

  mem = malloc((RARRAY_LEN(ary) + 1)*sizeof(char**));
  if (mem == NULL)
    rb_memerror();

  for (i = 0; i < RARRAY_LEN(ary); i++) {
    temp = rb_obj_as_string(RARRAY_PTR(ary)[i]);
    StringValueCStr(temp);
    mem[i] = malloc((RSTRING_LEN(temp))*sizeof(char*));;

    if (mem[i]  == NULL) rb_memerror();
    strcpy(mem[i], RSTRING_PTR(temp));
  }
  mem[i] = NULL;

  return mem;
}

static VALUE
safe_setup_str(const char *str)
{
  return rb_tainted_str_new2(str); // this already handles characters >= 0
}

static VALUE
safe_setup_array(char **arr)
{
  VALUE mem = rb_ary_new();

  while (*arr)
    rb_ary_push(mem, safe_setup_str(*arr++));
  return mem;
}

static VALUE
setup_gshadow(struct sgrp *sgroup)
{
  if (!sgroup) errno  || (errno = 61); // ENODATA
  etcutils_errno( safe_setup_str ( "Error setting up GShadow instance." ) );
  return rb_struct_new(cGShadow,
		       safe_setup_str(SGRP_NAME(sgroup)),
		       safe_setup_str(sgroup->sg_passwd),
		       safe_setup_array(sgroup->sg_adm),
		       safe_setup_array(sgroup->sg_mem),
		       NULL);
}

static VALUE
setup_shadow(struct spwd *shadow)
{
  if (!shadow) errno  || (errno = 61); // ENODATA
  etcutils_errno( safe_setup_str ( "Error setting up Shadow instance." ) );
  return rb_struct_new(cShadow,
		       safe_setup_str(shadow->sp_namp),
		       safe_setup_str(shadow->sp_pwdp),
		       INT2FIX(shadow->sp_lstchg),
		       INT2FIX(shadow->sp_min),
		       INT2FIX(shadow->sp_max),
		       INT2FIX(shadow->sp_warn),
		       INT2FIX(shadow->sp_inact),
		       INT2FIX(shadow->sp_expire),
		       INT2FIX(shadow->sp_flag),
		       NULL);
}

static VALUE
setup_group(struct group *grp)
{
  if (!grp) errno  || (errno = 61); // ENODATA
  etcutils_errno( safe_setup_str ( "Error setting up Group instance." ) );
  return rb_struct_new(cGroup,
		       safe_setup_str(grp->gr_name),
		       safe_setup_str(grp->gr_passwd),
		       GIDT2NUM(grp->gr_gid),
		       safe_setup_array(grp->gr_mem),
		       NULL);
}

static VALUE
setup_passwd(struct passwd *pwd)
{
  if (!pwd) errno  || (errno = 61); // ENODATA
  etcutils_errno( safe_setup_str ( "Error setting up Password instance." ) );
  return rb_struct_new(cPasswd,
		       safe_setup_str(pwd->pw_name),
		       safe_setup_str(pwd->pw_passwd),
		       UIDT2NUM(pwd->pw_uid),
		       GIDT2NUM(pwd->pw_gid),
		       safe_setup_str(pwd->pw_gecos),
		       safe_setup_str(pwd->pw_dir),
		       safe_setup_str(pwd->pw_shell),
		       NULL);
}
/* End of helper functions */

static VALUE
etcutils_setsgent(VALUE self)
{
#ifdef HAVE_SETSGENT
  setsgent();
#endif
  return Qnil;
}

static VALUE
etcutils_endsgent(VALUE self)
{
#ifdef HAVE_ENDSGENT
  endsgent();
#endif
  return Qnil;
}

static VALUE
etcutils_setgrent(VALUE self)
{
#ifdef HAVE_SETGRENT
  setgrent();
#endif
  return Qnil;
}

static VALUE
etcutils_endgrent(VALUE self)
{
#ifdef HAVE_ENDGRENT
  endgrent();
#endif
  return Qnil;
}

static VALUE
etcutils_setspent(VALUE self)
{
#ifdef HAVE_SETSPENT
  setspent();
#endif
  return Qnil;
}

static VALUE
etcutils_setpwent(VALUE self)
{
#ifdef HAVE_SETPWENT
  setpwent();
#endif
  return Qnil;
}

static VALUE
etcutils_endpwent(VALUE self)
{
#ifdef HAVE_ENDPWENT
  endpwent();
#endif
  return Qnil;
}

static VALUE
etcutils_endspent(VALUE self)
{
#ifdef HAVE_ENDSPENT
  endspent();
#endif
  return Qnil;
}

static VALUE
etcutils_sgetspent(VALUE self, VALUE nam)
{
  struct spwd *shadow;

  SafeStringValue(nam);
  if ( !(shadow = sgetspent(StringValuePtr(nam))) )
    rb_raise(rb_eArgError,
	     "can't parse %s into EtcUtils::Shadow", StringValuePtr(nam));

  return setup_shadow(shadow);
}

static VALUE
etcutils_sgetsgent(VALUE self, VALUE nam)
{
  struct sgrp *gshadow;

  SafeStringValue(nam);
  if ( !(gshadow = sgetsgent(StringValuePtr(nam))) )
    rb_raise(rb_eArgError,
	     "can't parse %s into EtcUtils::GShadow", StringValuePtr(nam));

  return setup_gshadow(gshadow);
}

static VALUE
etc_fgetgrent(VALUE self, VALUE io)
{
  struct group *grp;

  ensure_file(io);
  if ( (grp = fgetgrent(RFILE_FPTR(io))) == NULL )
    return Qnil;

  return setup_group(grp);
}

static VALUE
etc_fgetpwent(VALUE self, VALUE io)
{
  struct passwd *pwd;

  ensure_file(io);
  if ( (pwd = fgetpwent(RFILE_FPTR(io))) == NULL )
    return Qnil;

  return setup_passwd(pwd);
}

static VALUE
etcutils_fgetspent(VALUE self, VALUE io)
{
  struct spwd *spasswd;

  ensure_file(io);
  if ( (spasswd = fgetspent(RFILE_FPTR(io))) == NULL )
    return Qnil;

  return setup_shadow(spasswd);
}

static VALUE
etcutils_fgetsgent(VALUE self, VALUE io)
{
  struct sgrp *sgroup;

  ensure_file(io);
  if ( (sgroup = fgetsgent(RFILE_FPTR(io))) == NULL )
    return Qnil;

  return setup_gshadow(sgroup);
}

static VALUE
etcutils_getpwXXX(VALUE self, VALUE v)
{
  struct passwd *strt;
  etcutils_setpwent(self);

  if (TYPE(v) == T_FIXNUM)
    strt = getpwuid(NUM2UIDT(v));
  else {
    SafeStringValue(v);
    strt = getpwnam(StringValuePtr(v));
  }
  
  if (!strt)
    rb_raise(rb_eArgError, "can't find %s in %s", StringValuePtr(v), PASSWD);

  return setup_passwd(strt);
}

static VALUE
etcutils_getspXXX(VALUE self, VALUE v)
{
  struct spwd *strt;
  etcutils_setspent(self);

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
    rb_raise(rb_eArgError, "can't find %s in %s", StringValuePtr(v), SHADOW);

  return setup_shadow(strt);
}

static VALUE
etcutils_getsgXXX(VALUE self, VALUE v)
{
  struct sgrp *strt;
  etcutils_setsgent(self);

  if (TYPE(v) == T_FIXNUM) {
    struct group *s;
    if ( (s = getgrgid(NUM2UIDT(v))) )
      v = safe_setup_str(s->gr_name);
  }

  SafeStringValue(v);
  strt = getsgnam(StringValuePtr(v));
  
  if (!strt)
    rb_raise(rb_eArgError, "can't find %s in %s", StringValuePtr(v), GSHADOW);

  return setup_gshadow(strt);
}

static VALUE
etcutils_getgrXXX(VALUE self, VALUE v)
{
  struct group *strt;
  etcutils_setgrent(self);

  if (TYPE(v) == T_FIXNUM)
    strt = getgrgid(NUM2UIDT(v));
  else {
    SafeStringValue(v);
    strt = getgrnam(StringValuePtr(v));
  }
  
  if (!strt)
    rb_raise(rb_eArgError, "can't find %s in %s", StringValuePtr(v), GROUP);
  return setup_group(strt);
}

static VALUE
pwd_putpwent(VALUE self, VALUE io)
{
  struct passwd pwd, *tmp_str;
  VALUE val[RSTRUCT_LEN(self)];
  VALUE path = RFILE_PATH(io);
  long i;

  for (i=0; i<RSTRUCT_LEN(self); i++)
    val[i] = RSTRUCT_PTR(self)[i];

  SafeStringValue(val[1]);
  SafeStringValue(val[4]);
  SafeStringValue(val[5]);
  SafeStringValue(val[6]);
  ensure_file(io);

  rewind(RFILE_FPTR(io));
  i = 0;
  while ( (tmp_str = fgetpwent(RFILE_FPTR(io))) ) {
    i++;
    if ( !strcmp(tmp_str->pw_name,StringValuePtr(val[0])) )
      rb_raise(rb_eArgError, "%s is already mentioned in %s:%ld",
	       tmp_str->pw_name,  StringValuePtr(path), i );
  }

  pwd.pw_name     = StringValueCStr(val[0]);
  pwd.pw_passwd   = StringValueCStr(val[1]);
  pwd.pw_uid      = NUM2UIDT(val[2]);
  pwd.pw_gid      = NUM2GIDT(val[3]);
  pwd.pw_gecos    = StringValueCStr(val[4]);
  pwd.pw_dir      = StringValueCStr(val[5]);
  pwd.pw_shell    = StringValueCStr(val[6]);

  if ( (putpwent(&pwd, RFILE_FPTR(io))) )
    etcutils_errno(path);

  return Qtrue;
}

static VALUE
etc_putpwent(VALUE klass, VALUE entry, VALUE io)
{
  return pwd_putpwent(entry,io);
}


static VALUE
spwd_putspent(VALUE self, VALUE io)
{
  struct spwd spasswd, *tmp_str;
  VALUE val[RSTRUCT_LEN(self)];
  VALUE path = RFILE_PATH(io);
  long i;

  for (i=0; i<RSTRUCT_LEN(self); i++)
    val[i] = RSTRUCT_PTR(self)[i];

  SafeStringValue(val[0]);
  SafeStringValue(val[1]);
  ensure_file(io);

  rewind(RFILE_FPTR(io));
  i = 0;
  while ( (tmp_str = fgetspent(RFILE_FPTR(io))) ) {
    i++;
    if ( !strcmp(tmp_str->sp_namp,StringValuePtr(val[0])) )
      rb_raise(rb_eArgError, "%s is already mentioned in %s:%ld",
	       tmp_str->sp_namp,  StringValuePtr(path), i );
  }

  spasswd.sp_namp   = StringValueCStr(val[0]);
  spasswd.sp_pwdp   = StringValueCStr(val[1]);
  spasswd.sp_lstchg = FIX2INT(val[2]);
  spasswd.sp_min    = FIX2INT(val[3]);
  spasswd.sp_max    = FIX2INT(val[4]);
  spasswd.sp_warn   = FIX2INT(val[5]);
  spasswd.sp_inact  = FIX2INT(val[6]);
  spasswd.sp_expire = FIX2INT(val[7]);
  spasswd.sp_flag   = FIX2INT(val[8]);

  if ( (putspent(&spasswd, RFILE_FPTR(io))) )
    etcutils_errno(path);

  return Qtrue;
}

static VALUE
etcutils_putspent(VALUE klass, VALUE entry, VALUE io)
{
  return spwd_putspent(entry,io);
}

static VALUE
grp_putgrent(VALUE self, VALUE io)
{
  struct group grp, *tmp_str;
  VALUE val[RSTRUCT_LEN(self)];
  VALUE path = RFILE_PATH(io);
  long i;

  for (i=0; i<RSTRUCT_LEN(self); i++)
    val[i] = RSTRUCT_PTR(self)[i];

  SafeStringValue(val[0]);
  SafeStringValue(val[1]);
  Check_Type(val[3],T_ARRAY);
  ensure_file(io);

  rewind(RFILE_FPTR(io));
  i = 0;
  while ( (tmp_str = fgetgrent(RFILE_FPTR(io))) ) {
    i++;
    if ( !strcmp(tmp_str->gr_name,StringValuePtr(val[0])) )
      rb_raise(rb_eArgError, "%s is already mentioned in %s:%ld",
	       tmp_str->gr_name,  StringValuePtr(path), i );
  }

  grp.gr_name   = StringValueCStr(val[0]);
  grp.gr_passwd = StringValueCStr(val[1]);
  grp.gr_gid    = NUM2GIDT(val[2]);
  grp.gr_mem    = setup_char_members(val[3]);

  if ( putgrent(&grp,RFILE_FPTR(io)) )
    etcutils_errno(RFILE_PATH(io));

  free_char_members(grp.gr_mem, RARRAY_LEN(val[3]));

  return Qtrue;
}

static VALUE
etc_putgrent(VALUE klass, VALUE entry, VALUE io)
{
  return grp_putgrent(entry,io);
}


static VALUE
sgrp_putsgent(VALUE self, VALUE io)
{
  struct sgrp sgroup, *tmp_str;
  VALUE val[RSTRUCT_LEN(self)];
  VALUE path = RFILE_PATH(io);
  long i;

  for (i=0; i<RSTRUCT_LEN(self); i++)
    val[i] = RSTRUCT_PTR(self)[i];

  SafeStringValue(val[0]);
  SafeStringValue(val[1]);
  Check_Type(val[2],T_ARRAY);
  Check_Type(val[3],T_ARRAY);
  ensure_file(io);

  rewind(RFILE_FPTR(io));
  i = 0;
  while ( (tmp_str = fgetsgent(RFILE_FPTR(io))) ) {
    i++;
    if ( !strcmp(SGRP_NAME(tmp_str),StringValuePtr(val[0])) )
      rb_raise(rb_eArgError, "%s is already mentioned in %s:%ld",
	       SGRP_NAME(tmp_str),  StringValuePtr(path), i );
  }

#ifdef HAVE_ST_SG_NAMP
  sgroup.sg_namp = StringValueCStr(val[0]);
#endif
#if HAVE_ST_SG_NAME
  sgroup.sg_name = StringValueCStr(val[0]);
#endif

  sgroup.sg_passwd = StringValueCStr(val[1]);
  // char** members start here
  sgroup.sg_adm    = setup_char_members(val[2]);
  sgroup.sg_mem    = setup_char_members(val[3]);

  if ( putsgent(&sgroup,RFILE_FPTR(io)) )
    etcutils_errno(RFILE_PATH(io));

  free_char_members(sgroup.sg_adm, RARRAY_LEN(val[2]));
  free_char_members(sgroup.sg_mem, RARRAY_LEN(val[3]));

  return Qtrue;
}

static VALUE
etcutils_putsgent(VALUE klass, VALUE entry, VALUE io)
{
  return sgrp_putsgent(entry,io);
}

static VALUE
etcutils_locked_p(VALUE self)
{
  if (lckpwdf())
    return Qtrue;
  else if (!ulckpwdf())
    return Qfalse;
  else
    rb_raise(rb_eIOError,"Unable to determine the locked state of password files");
}

static VALUE
etcutils_lckpwdf(VALUE self)
{
  VALUE r;
  if ( !(r = etcutils_locked_p(self)) ) {
    if ( !(lckpwdf()) )
      r = Qtrue;
  }
  return r;
}

static VALUE
etcutils_ulckpwdf(VALUE self)
{
  VALUE r;
  if ( (r = etcutils_locked_p(self)) )
    if ( !(ulckpwdf()) )
      r = Qtrue;
  return r;
}

static int in_lock = 0;
static int shadow_block = 0;
static int pwd_block = 0;
static int gshadow_block = 0;
static int grp_block = 0;

static VALUE
lock_ensure(void)
{
  ulckpwdf();
  in_lock = (int)Qfalse;
  return Qnil;
}

static VALUE
etcutils_lock(VALUE self)
{
  if (etcutils_lckpwdf(self)) {
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
etcutils_unlock(VALUE self)
{
  return etcutils_ulckpwdf(self);
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
  shadow_block = (int)Qfalse;
  return Qnil;
}

static void
each_shadow(void)
{
  if (shadow_block)
    rb_raise(rb_eRuntimeError, "parallel shadow iteration");
  shadow_block = (int)Qtrue;
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


static VALUE
etcutils_getpwent(VALUE self)
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
  pwd_block = (int)Qtrue;
  rb_ensure(grp_iterate, 0, grp_ensure, 0);
}


static VALUE
etcutils_getgrent(VALUE self)
{
  struct group *grp;

  if (rb_block_given_p())
    each_group();
  else if ( (grp = getgrent()) )
    return setup_group(grp);
  return Qnil;
}


static VALUE
etcutils_getspent(VALUE self)
{
  struct spwd *shadow;

  if (rb_block_given_p())
    each_shadow();
  else if ( (shadow = getspent()) )
    return setup_shadow(shadow);
  return Qnil;
}

static VALUE
etcutils_getsgent(VALUE self)
{
  struct sgrp *sgroup;
  if ( (sgroup = getsgent()) )
    return setup_gshadow(sgroup);
  return Qnil;
}

static VALUE
strt_to_s(VALUE self)
{
  VALUE v, ary = rb_ary_new();
  long i;

  // g.map{|x| x.kind_of?(Array) ? x.join(',') : x.to_s }.join(':')
  for (i=0; i<RSTRUCT_LEN(self); i++) {
    v = RSTRUCT_PTR(self)[i];
    if (TYPE(v) == T_ARRAY)
      rb_ary_push(ary, rb_ary_join( (v), safe_setup_str(",") ));
    else if (TYPE(v) == T_STRING)
      rb_ary_push(ary,v);
    else if (TYPE(v) == T_FIXNUM) {
      if (FIX2INT(v) < 0 )
	v = safe_setup_str("");
      rb_ary_push(ary,v);
    } else
      Check_Type(v, T_STRING); // Or Array, but testing one is easier
  }

  return rb_ary_join(ary, safe_setup_str(":"));
}

static VALUE
etcutils_setXXent(VALUE self)
{
  etcutils_setpwent(self);
  etcutils_setgrent(self);
  etcutils_setspent(self);
  etcutils_setsgent(self);
  return Qnil;
}

static VALUE
etcutils_endXXent(VALUE self)
{
  etcutils_endpwent(self);
  etcutils_endgrent(self);
  etcutils_endspent(self);
  etcutils_endsgent(self);
  return Qnil;
}

void Init_etcutils()
{
  VALUE mEtcUtils = rb_define_module("EtcUtils");
  rb_extend_object(mEtcUtils, rb_mEnumerable);

  // EtcUtils Constants
  rb_define_global_const("PASSWD", safe_setup_str(PASSWD));
  rb_define_global_const("SHADOW", safe_setup_str(SHADOW));
  rb_define_global_const("GROUP", safe_setup_str(GROUP));
  rb_define_global_const("GSHADOW", safe_setup_str(GSHADOW));

  // EtcUtils Functions
  rb_define_module_function(mEtcUtils,"next_uid",next_uid,1);
  rb_define_module_function(mEtcUtils,"next_gid",next_gid,1);
  rb_define_module_function(mEtcUtils,"setXXent", etcutils_setXXent,0);
  rb_define_module_function(mEtcUtils,"endXXent", etcutils_endXXent,0);

  // Shadow Functions
  rb_define_module_function(mEtcUtils,"getspent",etcutils_getspent,0);
  rb_define_module_function(mEtcUtils,"find_spwd",etcutils_getspXXX,1);
  rb_define_module_function(mEtcUtils,"setspent",etcutils_setspent,0);
  rb_define_module_function(mEtcUtils,"endspent",etcutils_endspent,0);
  rb_define_module_function(mEtcUtils,"sgetspent",etcutils_sgetspent,1);
  rb_define_module_function(mEtcUtils,"fgetspent",etcutils_fgetspent,1);
  rb_define_module_function(mEtcUtils,"putspent",etcutils_putspent,2);

  // Password Functions
  rb_define_module_function(mEtcUtils,"getpwent",etcutils_getpwent,0);
  rb_define_module_function(mEtcUtils,"find_pwd",etcutils_getpwXXX,1);
  rb_define_module_function(mEtcUtils,"getpwnam",etcutils_getpwXXX,1); // Backward compatibility
  rb_define_module_function(mEtcUtils,"setpwent",etcutils_setpwent,0);
  rb_define_module_function(mEtcUtils,"endpwent",etcutils_endpwent,0);
  rb_define_module_function(mEtcUtils,"fgetpwent",etc_fgetpwent,1);
  rb_define_module_function(mEtcUtils,"putpwent",etc_putpwent,2);

  // GShadow Functions
  rb_define_module_function(mEtcUtils,"getsgent",etcutils_getsgent,0);
  rb_define_module_function(mEtcUtils,"find_sgrp",etcutils_getsgXXX,1);
  rb_define_module_function(mEtcUtils,"setsgent",etcutils_setsgent,0);
  rb_define_module_function(mEtcUtils,"endsgent",etcutils_endsgent,0);
  rb_define_module_function(mEtcUtils,"sgetsgent",etcutils_sgetsgent,1);
  rb_define_module_function(mEtcUtils,"fgetsgent",etcutils_fgetsgent,1);
  rb_define_module_function(mEtcUtils,"putsgent",etcutils_putsgent,2);

  // Group Functions
  rb_define_module_function(mEtcUtils,"getgrent",etcutils_getgrent,0);
  rb_define_module_function(mEtcUtils,"find_grp",etcutils_getgrXXX,1);
  rb_define_module_function(mEtcUtils,"getgrnam",etcutils_getgrXXX,1);
  rb_define_module_function(mEtcUtils,"setgrent",etcutils_setgrent,0);
  rb_define_module_function(mEtcUtils,"endgrent",etcutils_endgrent,0);
  rb_define_module_function(mEtcUtils,"fgetgrent",etc_fgetgrent,1);
  rb_define_module_function(mEtcUtils,"putgrent",etc_putgrent,2);

  // Lock Functions
  rb_define_module_function(mEtcUtils,"lckpwdf",etcutils_lckpwdf,0);
  rb_define_module_function(mEtcUtils,"ulckpwdf",etcutils_ulckpwdf,0);
  rb_define_module_function(mEtcUtils,"lock",etcutils_lock,0);
  rb_define_module_function(mEtcUtils,"unlock",etcutils_unlock,0);
  rb_define_module_function(mEtcUtils,"locked?",etcutils_locked_p,0);

  cPasswd =  rb_struct_define(NULL,
			      "name",
			      "passwd",
			      "uid",
			      "gid",
			      "gecos",
			      "dir",
			      "shell",
			      NULL);
  /* Define-const: Passwd
   *
   * Passwd is a Struct that contains the following members:
   *
   * name::
   *    contains the short login name of the user as a String.
   * passwd::
   *    contains the encrypted password of the user as a String.
   *    an 'x' is returned if shadow passwords are in use. An '*' is returned
   *      if the user cannot log in using a password.
   * uid::
   *    contains the integer user ID (uid) of the user.
   * gid::
   *    contains the integer group ID (gid) of the user's primary group.
   * dir::
   *    contains the path to the home directory of the user as a String.
   * gecos::
   *     contains a longer String description of the user, such as a
   *     full name. Some Unix systems provide structured information
   *     in the gecos field, but this is system-dependent.
   * shell::
   *    contains the path to the login shell of the user as a String.
   */
  rb_define_const(mEtcUtils,"Passwd",cPasswd);
  rb_set_class_path(cPasswd, mEtcUtils, "Passwd");
  rb_define_singleton_method(cPasswd,"get",etcutils_getpwent,0);
  rb_define_singleton_method(cPasswd,"find",etcutils_getpwXXX,1); // -1 return array
  rb_define_singleton_method(cPasswd,"set",etcutils_setpwent,0);
  rb_define_singleton_method(cPasswd,"end",etcutils_endpwent,0);
  rb_define_method(cPasswd, "fputs", pwd_putpwent, 1);
  rb_define_method(cPasswd, "to_s", strt_to_s,0);

  cShadow = rb_struct_define(NULL,
			     "name",
			     "passwd",
			     "last_change",
			     "min_change",
			     "max_change",
			     "warn",
			     "inactive",
			     "expire",
			     "flag",
			     NULL);

  rb_define_const(mEtcUtils,"Shadow",cShadow);
  rb_set_class_path(cShadow, mEtcUtils, "Shadow");
  rb_define_const(rb_cStruct, "Shadow", cShadow); /* deprecated name */
  rb_define_singleton_method(cShadow,"get",etcutils_getspent,0);
  rb_define_singleton_method(cShadow,"find",etcutils_getspXXX,1);
  rb_define_singleton_method(cShadow,"set",etcutils_setspent,0);
  rb_define_singleton_method(cShadow,"end",etcutils_endspent,0);
  rb_define_method(cShadow, "fputs", spwd_putspent, 1);
  rb_define_method(cShadow, "to_s", strt_to_s,0);

  cGroup = rb_struct_define(NULL,
			    "name",
			    "passwd",
			    "gid",
			    "mem",
			    NULL);
  /* Define-const: Group
   *
   * The struct contains the following members:
   *
   * name::
   *    contains the name of the group as a String.
   * passwd::
   *    contains the encrypted password as a String. An 'x' is
   *    returned if password access to the group is not available; an empty
   *    string is returned if no password is needed to obtain membership of
   *    the group.
   * gid::
   *    contains the group's numeric ID as an integer.
   * mem::
   *    is an Array of Strings containing the short login names of the
   *    members of the group.
   */
  rb_define_class_under(mEtcUtils,"Group",cGroup);
  rb_set_class_path(cGroup, mEtcUtils, "Group");
  rb_define_singleton_method(cGroup,"get",etcutils_getgrent,0);
  rb_define_singleton_method(cGroup,"find",etcutils_getgrXXX,1);
  rb_define_singleton_method(cGroup,"set",etcutils_setgrent,0);
  rb_define_singleton_method(cGroup,"end",etcutils_endgrent,0);
  rb_define_method(cGroup, "fputs", grp_putgrent, 1);
  rb_define_method(cGroup, "to_s", strt_to_s,0);

  cGShadow = rb_struct_define(NULL,
                              "name",
                              "passwd",
                              "admins",
                              "members",
                              NULL);

  rb_define_const(mEtcUtils, "GShadow",cGShadow);
  rb_set_class_path(cGShadow, mEtcUtils, "GShadow");
  rb_define_const(rb_cStruct, "GShadow", cGShadow); /* deprecated name */
  rb_define_singleton_method(cGShadow,"get",etcutils_getsgent,0);
  rb_define_singleton_method(cGShadow,"find",etcutils_getsgXXX,1);
  rb_define_singleton_method(cGShadow,"set",etcutils_setsgent,0);
  rb_define_singleton_method(cGShadow,"end",etcutils_endsgent,0);
  rb_define_method(cGShadow, "fputs", sgrp_putsgent, 1);
  rb_define_method(cGShadow, "to_s", strt_to_s,0);
}
