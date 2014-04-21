#include "etcutils.h"

VALUE rb_cPasswd, rb_cShadow;

static VALUE
user_get_pw_change(VALUE self)
{
  return iv_get_time(self, "@last_pw_change");
}

static VALUE
user_set_pw_change(VALUE self)
{
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
  return iv_set_time(self, v, "@expire");
}

VALUE user_putpwent(VALUE self, VALUE io)
{
  struct passwd pwd, *tmp_pwd;
  VALUE path;
  long i = 0;

  Check_EU_Type(self, rb_cPasswd);
  Check_Writes(io, FMODE_WRITABLE);

  path = RFILE_PATH(io);

  rewind(RFILE_FPTR(io));
  pwd.pw_name     = RSTRING_PTR(rb_ivar_get(self, id_name));

  while ( (tmp_pwd = fgetpwent(RFILE_FPTR(io))) )
    if ( !strcmp(tmp_pwd->pw_name, pwd.pw_name) )
      rb_raise(rb_eArgError, "%s is already mentioned in %s:%ld",
	       tmp_pwd->pw_name,  StringValuePtr(path), ++i );

  pwd.pw_passwd   = RSTRING_PTR(rb_ivar_get(self, id_passwd));
  pwd.pw_uid      = NUM2UIDT( rb_ivar_get(self,id_uid) );
  pwd.pw_gid      = NUM2GIDT( rb_ivar_get(self,id_gid) );
  pwd.pw_gecos    = RSTRING_PTR(rb_iv_get(self, "@gecos"));
  pwd.pw_dir      = RSTRING_PTR(rb_iv_get(self, "@directory"));
  pwd.pw_shell    = RSTRING_PTR(rb_iv_get(self, "@shell"));

  if ( (putpwent(&pwd, RFILE_FPTR(io))) )
    eu_errno(path);

  return Qtrue;
}

VALUE user_pw_entry(VALUE self)
{
  return eu_to_entry(self, user_putpwent);
}

VALUE user_putspent(VALUE self, VALUE io)
{
  struct spwd spasswd, *tmp_spwd;
  VALUE path;
  long i;
  errno = 0;
  i = 0;

  Check_EU_Type(self, rb_cShadow);
  Check_Writes(io, FMODE_WRITABLE);

  path = RFILE_PATH(io);

  rewind(RFILE_FPTR(io));
  spasswd.sp_namp  = RSTRING_PTR(rb_ivar_get(self, id_name));

  while ( (tmp_spwd = fgetspent(RFILE_FPTR(io))) )
    if ( !strcmp(tmp_spwd->sp_namp, spasswd.sp_namp) )
      rb_raise(rb_eArgError, "%s is already mentioned in %s:%ld",
	       tmp_spwd->sp_namp,  StringValuePtr(path), ++i );

  spasswd.sp_pwdp   = RSTRING_PTR(rb_ivar_get(self, id_passwd));
  spasswd.sp_lstchg = FIX2INT( rb_iv_get(self, "@last_pw_change") );
  spasswd.sp_min    = FIX2INT( rb_iv_get(self, "@min_pw_age") );
  spasswd.sp_max    = FIX2INT( rb_iv_get(self, "@max_pw_age") );
  spasswd.sp_warn   = FIX2INT( rb_iv_get(self, "@warning") );
  spasswd.sp_inact  = FIX2INT( rb_iv_get(self, "@inactive") );
  spasswd.sp_expire = FIX2INT( rb_iv_get(self, "@expire") );
  spasswd.sp_flag   = FIX2INT( rb_iv_get(self, "@flag") );

  if ( (putspent(&spasswd, RFILE_FPTR(io))) )
    eu_errno(path);

  return Qtrue;
}

VALUE user_sp_entry(VALUE self)
{
  return eu_to_entry(self, user_putspent);
}

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
  rb_iv_set(obj, "@warning", INT2FIX(spasswd->sp_warn));
  rb_iv_set(obj, "@inactive", INT2FIX(spasswd->sp_inact));
  rb_iv_set(obj, "@expire", INT2FIX(spasswd->sp_expire));
  rb_iv_set(obj, "@flag", INT2FIX(spasswd->sp_flag));

  return obj;
}

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

  return obj;
}

void Init_etcutils_user()
{

#ifdef HAVE_PWD_H
  // Would love to make these read only if the user does not have access.
  rb_define_attr(rb_cPasswd, "name", 1, 1);
  rb_define_attr(rb_cPasswd, "passwd", 1, 1);
  rb_define_attr(rb_cPasswd, "uid", 1, 1);
  rb_define_attr(rb_cPasswd, "gid", 1, 1);
  rb_define_attr(rb_cPasswd, "gecos", 1, 1);
  rb_define_attr(rb_cPasswd, "directory", 1, 1);
  rb_define_attr(rb_cPasswd, "shell", 1, 1);

  rb_define_method(rb_cPasswd, "to_entry", user_pw_entry,0);
  rb_define_method(rb_cPasswd, "fputs", user_putpwent, 1);

  rb_define_singleton_method(rb_cPasswd,"get",eu_getpwent,0);
  rb_define_singleton_method(rb_cPasswd,"each",eu_getpwent,0);
  rb_define_singleton_method(rb_cPasswd,"find",eu_getpwd,1); // -1 return array
  rb_define_singleton_method(rb_cPasswd,"parse",eu_sgetpwent,1);
#endif

#ifdef HAVE_SHADOW_H // Shadow specific methods
  rb_define_attr(rb_cShadow, "name", 1, 1);
  rb_define_attr(rb_cShadow, "passwd", 1, 0);
  rb_define_attr(rb_cShadow, "min_pw_age", 1, 1);
  rb_define_attr(rb_cShadow, "max_pw_age", 1, 1);
  rb_define_attr(rb_cShadow, "last_pw_change", 1, 0); //expressed as the number of days since Jan 1, 1970
  rb_define_attr(rb_cShadow, "warning", 1, 1);
  rb_define_attr(rb_cShadow, "inactive", 1, 1);
  rb_define_attr(rb_cShadow, "expire", 1, 1); // expressed as the number of days since Jan 1, 1970
  rb_define_attr(rb_cShadow, "flag", 1, 0); // reserved for future use

  rb_define_method(rb_cShadow, "passwd=", user_set_pw_change, 1);
  rb_define_method(rb_cShadow, "last_pw_change_date", user_get_pw_change, 0);
  rb_define_method(rb_cShadow, "expire_date", user_get_expire, 0);
  rb_define_method(rb_cShadow, "expire_date=", user_set_expire, 1);

  rb_define_method(rb_cShadow, "to_entry", user_sp_entry,0);
  rb_define_method(rb_cShadow, "fputs", user_putspent, 1);

  rb_define_singleton_method(rb_cShadow,"get",eu_getspent,0);
  rb_define_singleton_method(rb_cShadow,"each",eu_getspent,0);
  rb_define_singleton_method(rb_cShadow,"find",eu_getspwd,1);
  rb_define_singleton_method(rb_cShadow,"parse",eu_sgetspent,1);
#endif

  rb_define_singleton_method(rb_cPasswd,"set", eu_setpwent, 0);
  rb_define_singleton_method(rb_cPasswd,"end", eu_endpwent, 0);

  rb_define_singleton_method(rb_cShadow,"set", eu_setspent, 0);
  rb_define_singleton_method(rb_cShadow,"end", eu_endspent, 0);
}
