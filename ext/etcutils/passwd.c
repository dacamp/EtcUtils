#include "etcutils.h"

VALUE rb_cPasswd, rb_cShadow;
int expire_warned = 0;

static VALUE
user_get_pw_change(VALUE self)
{
  return iv_get_time(self, "@last_pw_change");
}

static VALUE
user_set_pw_change(VALUE self, VALUE pw)
{
  rb_ivar_set(self, id_passwd, pw);
  return iv_set_time(self, rb_current_time(), "@last_pw_change");
}

static VALUE
user_get_expire(VALUE self)
{
  return iv_get_time(self, "@expire");
}

static VALUE
user_set_expire(VALUE self, VALUE v)
{
  if ((rb_equal(v, INT2FIX(0))) && (expire_warned == 0)) {
    rb_warn("Setting %s#expire to 0 should not be used as it is interpreted as either an account with no expiration, or as an expiration of Jan 1, 1970.", rb_obj_classname(self));
    expire_warned = 1;
  }

  return iv_set_time(self, v, "@expire");
}

#ifdef HAVE_PUTPWENT
static VALUE user_pw_put(VALUE self, VALUE io)
{
  struct passwd pwd;
  VALUE path;
  rb_io_t *fptr;
  FILE *file_ptr;

#ifdef HAVE_FGETPWENT
  struct passwd *tmp_pwd;
  long i = 0;
#endif

  Check_EU_Type(self, rb_cPasswd);
  Check_Writes(io, FMODE_WRITABLE);

  GetOpenFile(io, fptr);
  path = rb_str_new2(fptr->pathv);
  file_ptr = rb_io_stdio_file(fptr);

  rewind(file_ptr);
  pwd.pw_name     = RSTRING_PTR(rb_ivar_get(self, id_name));

#ifdef HAVE_FGETPWENT
  while ( (tmp_pwd = fgetpwent(file_ptr)) )
    if ( !strcmp(tmp_pwd->pw_name, pwd.pw_name) )
      rb_raise(rb_eArgError, "%s is already mentioned in %s:%ld",
	       tmp_pwd->pw_name,  StringValuePtr(path), ++i );
#endif

  pwd.pw_passwd   = RSTRING_PTR(rb_ivar_get(self, id_passwd));
  pwd.pw_uid      = NUM2UIDT( rb_ivar_get(self,id_uid) );
  pwd.pw_gid      = NUM2GIDT( rb_ivar_get(self,id_gid) );
  pwd.pw_gecos    = RSTRING_PTR(rb_iv_get(self, "@gecos"));
  pwd.pw_dir      = RSTRING_PTR(rb_iv_get(self, "@directory"));
  pwd.pw_shell    = RSTRING_PTR(rb_iv_get(self, "@shell"));

  if ( (putpwent(&pwd, file_ptr)) )
    eu_errno(path);

  return Qtrue;
}
#endif

static VALUE user_pw_sprintf(VALUE self)
{
  VALUE args[11];
  args[0]  = setup_safe_str("%s:%s:%s:%s:%s:%s:%s:%s:%s:%s\n");
  args[1]  = rb_ivar_get(self, id_name);
  args[2]  = rb_ivar_get(self, id_passwd);
  args[3]  = rb_ivar_get(self, id_uid);
  args[4]  = rb_ivar_get(self,id_gid);
  args[5]  = rb_iv_get(self, "@access_classs");
  args[6]  = rb_iv_get(self, "@last_pw_change");
  args[7]  = rb_iv_get(self, "@expire");
  args[8]  = rb_iv_get(self, "@gecos");
  args[9]  = rb_iv_get(self, "@directory");
  args[10] = rb_iv_get(self, "@shell");
  return rb_f_sprintf(11, args);
}

VALUE user_putpwent(VALUE self, VALUE io)
{
#ifdef HAVE_PUTPWENT
  return user_pw_put(self, io);
#else
  return user_pw_sprintf(self);
#endif
}

VALUE user_pw_entry(VALUE self)
{
  return eu_to_entry(self, user_putpwent);
}

VALUE user_putspent(VALUE self, VALUE io)
{
#ifdef SHADOW
  struct spwd spasswd, *tmp_spwd;
  VALUE path;
  rb_io_t *fptr;
  FILE *file_ptr;
  long i;
  errno = 0;
  i = 0;

  Check_EU_Type(self, rb_cShadow);
  Check_Writes(io, FMODE_WRITABLE);

  GetOpenFile(io, fptr);
  path = rb_str_new2(fptr->pathv);
  file_ptr = rb_io_stdio_file(fptr);

  rewind(file_ptr);
  spasswd.sp_namp  = RSTRING_PTR(rb_ivar_get(self, id_name));

  while ( (tmp_spwd = fgetspent(file_ptr)) )
    if ( !strcmp(tmp_spwd->sp_namp, spasswd.sp_namp) )
      rb_raise(rb_eArgError, "%s is already mentioned in %s:%ld",
	       tmp_spwd->sp_namp,  StringValuePtr(path), ++i );

  spasswd.sp_pwdp   = RSTRING_PTR(rb_ivar_get(self, id_passwd));
  spasswd.sp_lstchg = FIX2INT( rb_iv_get(self, "@last_pw_change") );
  spasswd.sp_min    = FIX2INT( rb_iv_get(self, "@min_pw_age") );
  spasswd.sp_max    = FIX2INT( rb_iv_get(self, "@max_pw_age") );
  spasswd.sp_warn   = QFIX2INT( rb_iv_get(self, "@warning") );
  spasswd.sp_inact  = QFIX2INT( rb_iv_get(self, "@inactive") );
  spasswd.sp_expire = QFIX2INT( rb_iv_get(self, "@expire") );
  spasswd.sp_flag   = QFIX2ULONG( rb_iv_get(self, "@flag") );

  if ( (putspent(&spasswd, file_ptr)) )
    eu_errno(path);

  return Qtrue;
#else
  return Qnil;
#endif
}

VALUE user_sp_entry(VALUE self)
{
  return eu_to_entry(self, user_putspent);
}

#ifdef SHADOW
VALUE setup_shadow(struct spwd *spasswd)
{
  VALUE obj;
  if (!spasswd) errno  || (errno = 61); // ENODATA
  eu_errno( setup_safe_str ( "Error setting up Shadow instance." ) );

  obj = rb_obj_alloc(rb_cShadow);

  rb_ivar_set(obj, id_name, setup_safe_str(spasswd->sp_namp));
  rb_ivar_set(obj, id_passwd, setup_safe_str(spasswd->sp_pwdp));

  rb_iv_set(obj, "@last_pw_change", INT2FIX(spasswd->sp_lstchg));
  rb_iv_set(obj, "@min_pw_age", INT2FIX(spasswd->sp_min));
  rb_iv_set(obj, "@max_pw_age", INT2FIX(spasswd->sp_max));
  rb_iv_set(obj, "@warning", INT2QFIX(spasswd->sp_warn));
  rb_iv_set(obj, "@inactive",  INT2QFIX(spasswd->sp_inact));
  rb_iv_set(obj, "@expire", INT2QFIX(spasswd->sp_expire));
  rb_iv_set(obj, "@flag", UINT2QFIX(spasswd->sp_flag));

  return obj;
}
#endif

VALUE setup_passwd(struct passwd *pwd)
{
  VALUE obj;
  if (!pwd) errno  || (errno = 61); // ENODATA
  eu_errno( setup_safe_str ( "Error setting up Password instance." ) );

  obj = rb_obj_alloc(rb_cPasswd);

  rb_ivar_set(obj, id_name, setup_safe_str(pwd->pw_name));
  rb_ivar_set(obj, id_passwd, setup_safe_str(pwd->pw_passwd));
  rb_ivar_set(obj, id_uid, UIDT2NUM(pwd->pw_uid));
  rb_ivar_set(obj, id_gid, GIDT2NUM(pwd->pw_gid));

  rb_iv_set(obj, "@gecos", setup_safe_str(pwd->pw_gecos));
  rb_iv_set(obj, "@directory", setup_safe_str(pwd->pw_dir));
  rb_iv_set(obj, "@shell", setup_safe_str(pwd->pw_shell));
  #ifdef HAVE_ST_PW_CHANGE
  if (!pwd->pw_change)
    pwd->pw_change = (time_t)0;
  rb_iv_set(obj, "@last_pw_change", INT2FIX(pwd->pw_change));
  #endif
  #ifdef HAVE_ST_PW_EXPIRE
  if (!pwd->pw_expire)
    pwd->pw_expire = (time_t)0;

  rb_iv_set(obj, "@expire", INT2QFIX(pwd->pw_expire));
  #endif
  #ifdef HAVE_ST_PW_CLASS
  if (pwd->pw_class)
    rb_iv_set(obj, "@access_class", setup_safe_str(pwd->pw_class));
  #endif

  #ifdef HAVE_ST_PW_FIELD
  if (pwd->pw_field)
    rb_iv_set(obj, "@field", setup_safe_str(pwd->pw_field));
  #endif

  return obj;
}

void Init_etcutils_user()
{

#ifdef HAVE_PWD_H
  rb_define_attr(rb_cPasswd, "name", 1, 1);
  rb_define_attr(rb_cPasswd, "uid", 1, 1);
  rb_define_attr(rb_cPasswd, "gid", 1, 1);
  rb_define_attr(rb_cPasswd, "gecos", 1, 1);
  rb_define_attr(rb_cPasswd, "directory", 1, 1);
  rb_define_attr(rb_cPasswd, "shell", 1, 1);

  #ifdef HAVE_ST_PW_CHANGE
  rb_define_attr(rb_cPasswd, "last_pw_change", 1, 0); /* Number expressed as a count of days since Jan 1, 1970
							 since the last password change */
  rb_define_method(rb_cPasswd, "last_pw_change_date", user_get_pw_change, 0);
  rb_define_attr(rb_cPasswd, "passwd", 1, 0);
  rb_define_method(rb_cPasswd, "passwd=", user_set_pw_change, 1);
  #else
  rb_define_attr(rb_cPasswd, "passwd", 1, 1);
  #endif
  #ifdef HAVE_ST_PW_EXPIRE
  rb_define_attr(rb_cPasswd, "expire", 1, 0); /* Number expressed as a count of days since Jan 1, 1970
						 on which the account will be disabled */
  rb_define_method(rb_cPasswd, "expire=", user_set_expire, 1);
  rb_define_method(rb_cPasswd, "expire_date", user_get_expire, 0);
  rb_define_method(rb_cPasswd, "expire_date=", user_set_expire, 1);
  #endif

  #ifdef HAVE_ST_PW_CLASS
  rb_define_attr(rb_cPasswd, "access_class", 1, 1);
  #endif

  #ifdef HAVE_ST_PW_FIELD
  rb_define_attr(rb_cPasswd, "field", 1, 0);
  #endif

  rb_define_method(rb_cPasswd, "to_entry", user_pw_entry,0);
  rb_define_method(rb_cPasswd, "fputs", user_putpwent, 1);

  rb_define_singleton_method(rb_cPasswd,"get",eu_getpwent,0);
  rb_define_singleton_method(rb_cPasswd,"each",eu_getpwent,0);
  rb_define_singleton_method(rb_cPasswd,"find",eu_getpwd,1); // -1 return array
  rb_define_singleton_method(rb_cPasswd,"parse",eu_sgetpwent,1);


  rb_define_singleton_method(rb_cPasswd,"set", eu_setpwent, 0);
  rb_define_singleton_method(rb_cPasswd,"end", eu_endpwent, 0);
#endif

#ifdef HAVE_SHADOW_H // Shadow specific methods
  rb_define_attr(rb_cShadow, "name", 1, 1);   /* Login name.  */
  rb_define_attr(rb_cShadow, "passwd", 1, 0); /* Encrypted password.  */
  rb_define_attr(rb_cShadow, "min_pw_age", 1, 1); /* Minimum number of days between changes.  */
  rb_define_attr(rb_cShadow, "max_pw_age", 1, 1); /* Maximum number of days between changes.  */
  rb_define_attr(rb_cShadow, "last_pw_change", 1, 0); /* Number expressed as a count of days since Jan 1, 1970
							 since the last password change */
  rb_define_attr(rb_cShadow, "warning", 1, 1); /* Number of days to warn user to change
						  the password.  */
  rb_define_attr(rb_cShadow, "inactive", 1, 1); /* Number of days after password expires
						   that account is considered inactive and disabled */
  rb_define_attr(rb_cShadow, "expire", 1, 0); /* Number expressed as a count of days since Jan 1, 1970
						 on which the account will be disabled */
  rb_define_attr(rb_cShadow, "flag", 1, 0); /* Reserved */

  rb_define_method(rb_cShadow, "passwd=", user_set_pw_change, 1);
  rb_define_method(rb_cShadow, "expire=", user_set_expire, 1);
  rb_define_method(rb_cShadow, "last_pw_change_date", user_get_pw_change, 0);
  rb_define_method(rb_cShadow, "expire_date", user_get_expire, 0);
  rb_define_method(rb_cShadow, "expire_date=", user_set_expire, 1);

  rb_define_method(rb_cShadow, "to_entry", user_sp_entry,0);
  rb_define_method(rb_cShadow, "fputs", user_putspent, 1);

  rb_define_singleton_method(rb_cShadow,"get",eu_getspent,0);
  rb_define_singleton_method(rb_cShadow,"each",eu_getspent,0);
  rb_define_singleton_method(rb_cShadow,"find",eu_getspwd,1);
  rb_define_singleton_method(rb_cShadow,"parse",eu_sgetspent,1);

  rb_define_singleton_method(rb_cShadow,"set", eu_setspent, 0);
  rb_define_singleton_method(rb_cShadow,"end", eu_endspent, 0);
#endif
}
