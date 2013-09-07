#include "etcutils.h"

static VALUE
eu_user_get_pw_change(VALUE self)
{
  return iv_get_time(self, "@last_pw_change");
}

static VALUE
eu_user_set_pw_change(VALUE self, VALUE v)
{
  return iv_set_time(self, v, "@last_pw_change");
}

static VALUE
eu_user_get_expire(VALUE self)
{
  return iv_get_time(self, "@expire");
}

static VALUE
eu_user_set_expire(VALUE self, VALUE v)
{
  return iv_set_time(self, v, "@expire");
}

VALUE setup_shadow(struct spwd *shadow)
{
  if (!shadow) errno  || (errno = 61); // ENODATA
  etcutils_errno( setup_safe_str ( "Error setting up Shadow instance." ) );

  VALUE obj = rb_obj_alloc(rb_cUser);

  rb_ivar_set(obj, id_name, setup_safe_str(shadow->sp_namp));
  rb_ivar_set(obj, id_passwd, setup_safe_str(shadow->sp_pwdp));

  rb_iv_set(obj, "@last_pw_change", INT2FIX(shadow->sp_lstchg));
  rb_iv_set(obj, "@min_pw_age", INT2FIX(shadow->sp_min));
  rb_iv_set(obj, "@max_pw_age", INT2FIX(shadow->sp_max));
  rb_iv_set(obj, "@warning", INT2FIX(shadow->sp_warn));
  rb_iv_set(obj, "@inactive", INT2FIX(shadow->sp_inact));
  rb_iv_set(obj, "@expire", INT2FIX(shadow->sp_expire));
  rb_iv_set(obj, "@flag", INT2FIX(shadow->sp_flag));

  return obj;
}

VALUE setup_passwd(struct passwd *pwd)
{
  if (!pwd) errno  || (errno = 61); // ENODATA
  etcutils_errno( setup_safe_str ( "Error setting up Password instance." ) );

  VALUE obj = rb_obj_alloc(rb_cUser);

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
  rb_define_attr(rb_cUser, "name", 1, 1);
  rb_define_attr(rb_cUser, "passwd", 1, 1);
  rb_define_attr(rb_cUser, "uid", 1, 1);
  rb_define_attr(rb_cUser, "gid", 1, 1);
  rb_define_attr(rb_cUser, "gecos", 1, 1);
  rb_define_attr(rb_cUser, "directory", 1, 1);
  rb_define_attr(rb_cUser, "shell", 1, 1);
#endif

#ifdef HAVE_SHADOW_H
  // Shadow specific methods
  rb_define_attr(rb_cUser, "min_pw_age", 1, 1);
  rb_define_attr(rb_cUser, "max_pw_age", 1, 1);
  rb_define_attr(rb_cUser, "last_pw_change", 1, 0); //expressed as the number of days since Jan 1, 1970

  rb_define_attr(rb_cUser, "warning", 1, 1);
  rb_define_attr(rb_cUser, "inactive", 1, 1);
  rb_define_attr(rb_cUser, "expire", 1, 1); // expressed as the number of days since Jan 1, 1970

  rb_define_attr(rb_cUser, "flag", 1, 0); // reserved for future use

  rb_define_method(rb_cUser, "last_pw_change_date", eu_user_get_pw_change, 0);
  rb_define_method(rb_cUser, "expire_date", eu_user_get_expire, 0);
  rb_define_method(rb_cUser, "expire_date=", eu_user_set_expire, 1);
#endif
}
