#include "etcutils.h"
VALUE rb_cGroup, rb_cGshadow;

#ifdef HAVE_PUTGRENT
static VALUE group_gr_put(VALUE self, VALUE io)
{
  struct group grp;
  VALUE path;
  rb_io_t *fptr;
  FILE *file_ptr;
#ifdef HAVE_FGETGRENT
  struct group *tmp_grp;
  long i = 0;
#endif

  Check_EU_Type(self, rb_cGroup);
  Check_Writes(io, FMODE_WRITABLE);

  GetOpenFile(io, fptr);
  path = rb_str_new2(fptr->pathv);
  file_ptr = rb_io_stdio_file(fptr);

  rewind(file_ptr);
  grp.gr_name     = RSTRING_PTR(rb_ivar_get(self, id_name));

#ifdef HAVE_FGETGRENT
  while ( (tmp_grp = fgetgrent(file_ptr)) )
    if ( !strcmp(tmp_grp->gr_name, grp.gr_name) )
      rb_raise(rb_eArgError, "%s is already mentioned in %s:%ld",
	       tmp_grp->gr_name,  StringValuePtr(path), ++i );
#endif

  grp.gr_passwd = RSTRING_PTR(rb_ivar_get(self, id_passwd));
  grp.gr_gid    = NUM2GIDT( rb_ivar_get(self, id_gid) );
  grp.gr_mem    = setup_char_members( rb_iv_get(self, "@members") );

  if ( putgrent(&grp, file_ptr) )
    eu_errno(path);

  free_char_members(grp.gr_mem, (int)RARRAY_LEN( rb_iv_get(self, "@members") ));

  return Qtrue;
}
#endif

/*
 * Generate group entry string in standard format.
 *
 * Group format (4 fields):
 *   name:passwd:gid:members
 *
 * This function is used as a fallback when putgrent() is not available
 * (e.g., on macOS). All fields are nil-guarded to prevent crashes.
 */
static VALUE group_gr_sprintf(VALUE self)
{
  VALUE args[5];
  VALUE name, passwd, members_ary, members_str;

  args[0] = setup_safe_str("%s:%s:%s:%s\n");

  /* name defaults to empty string if nil */
  name = rb_ivar_get(self, id_name);
  args[1] = NIL_P(name) ? setup_safe_str("") : name;

  /* passwd defaults to empty string if nil */
  passwd = rb_ivar_get(self, id_passwd);
  args[2] = NIL_P(passwd) ? setup_safe_str("") : passwd;

  /* gid is numeric - rb_f_sprintf handles nil gracefully (converts to "") */
  args[3] = rb_ivar_get(self, id_gid);

  /* members is an array - ensure it's not nil before joining */
  members_ary = rb_iv_get(self, "@members");
  if (NIL_P(members_ary)) {
    members_str = setup_safe_str("");
  } else {
    members_str = rb_ary_join(members_ary, setup_safe_str(","));
  }
  args[4] = members_str;

  return rb_f_sprintf(5, args);
}

VALUE group_putgrent(VALUE self, VALUE io)
{
#ifdef HAVE_PUTGRENT
  return group_gr_put(self, io);
#else
  return group_gr_sprintf(self);
#endif
}

VALUE group_gr_entry(VALUE self)
{
  return eu_to_entry(self, group_putgrent);
}

VALUE group_putsgent(VALUE self, VALUE io)
{
#ifdef GSHADOW
  struct sgrp sgroup, *tmp_sgrp;
  VALUE path;
  rb_io_t *fptr;
  FILE *file_ptr;
  long i = 0;

  Check_EU_Type(self, rb_cGshadow);
  Check_Writes(io, FMODE_WRITABLE);

  GetOpenFile(io, fptr);
  path = rb_str_new2(fptr->pathv);
  file_ptr = rb_io_stdio_file(fptr);

  rewind(file_ptr);
  SGRP_NAME(&sgroup)  = RSTRING_PTR(rb_ivar_get(self, id_name));

  while ( (tmp_sgrp = fgetsgent(file_ptr)) )
    if ( !strcmp(SGRP_NAME(tmp_sgrp), SGRP_NAME(&sgroup)) )
      rb_raise(rb_eArgError, "%s is already mentioned in %s:%ld",
	       RSTRING_PTR(rb_ivar_get(self, id_name)), StringValuePtr(path), ++i );

  sgroup.sg_passwd = RSTRING_PTR(rb_ivar_get(self, id_passwd));
  sgroup.sg_adm    = setup_char_members( rb_iv_get(self,"@admins") );
  sgroup.sg_mem    = setup_char_members( rb_iv_get(self, "@members") );

  if ( putsgent(&sgroup, file_ptr) )
    eu_errno(path);

  free_char_members(sgroup.sg_adm, RARRAY_LEN( rb_iv_get(self, "@admins") ));
  free_char_members(sgroup.sg_mem, RARRAY_LEN( rb_iv_get(self, "@members") ));

  return Qtrue;
#else
  return Qnil;
#endif
}

VALUE group_sg_entry(VALUE self)
{
  return eu_to_entry(self, group_putsgent);
}

VALUE setup_group(struct group *grp)
{
  VALUE obj;
  if (!grp) errno  || (errno = 61); // ENODATA
  eu_errno( setup_safe_str ( "Error setting up Group instance." ) );

  obj = rb_obj_alloc(rb_cGroup);

  rb_ivar_set(obj, id_name, setup_safe_str(grp->gr_name));
  rb_ivar_set(obj, id_passwd, setup_safe_str(grp->gr_passwd));
  rb_ivar_set(obj, id_gid, GIDT2NUM(grp->gr_gid));
  rb_iv_set(obj, "@members", setup_safe_array(grp->gr_mem));

  return obj;
}

#if defined(HAVE_GSHADOW_H) || defined(HAVE_GSHADOW__H)
VALUE setup_gshadow(struct sgrp *sgroup)
{
  VALUE obj;
  if (!sgroup) errno  || (errno = 61); // ENODATA
  eu_errno( setup_safe_str ( "Error setting up GShadow instance." ) );

  obj = rb_obj_alloc(rb_cGshadow);

  rb_ivar_set(obj, id_name, setup_safe_str(SGRP_NAME(sgroup)));
  rb_ivar_set(obj, id_passwd, setup_safe_str(sgroup->sg_passwd));
  rb_iv_set(obj, "@admins", setup_safe_array(sgroup->sg_adm));
  rb_iv_set(obj, "@members", setup_safe_array(sgroup->sg_mem));
  return obj;
}
#endif

/*
 * Stub methods for platforms without gshadow.h (macOS/BSD).
 * These raise NotImplementedError with a helpful message.
 */
#ifndef GSHADOW
static VALUE
gshadow_not_implemented(int argc, VALUE *argv, VALUE self)
{
  rb_raise(rb_eNotImpError,
           "GShadow is not available on this platform (no gshadow.h)");
  return Qnil;
}

static VALUE
gshadow_instance_not_implemented(int argc, VALUE *argv, VALUE self)
{
  rb_raise(rb_eNotImpError,
           "GShadow is not available on this platform (no gshadow.h)");
  return Qnil;
}
#endif

void Init_etcutils_group()
{
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
#ifdef GROUP
  rb_define_attr(rb_cGroup, "name", 1, 1);
  rb_define_attr(rb_cGroup, "passwd", 1, 1);
  rb_define_attr(rb_cGroup, "gid", 1, 1);
  rb_define_attr(rb_cGroup, "members", 1, 1);

  rb_define_singleton_method(rb_cGroup,"get",eu_getgrent,0);
  rb_define_singleton_method(rb_cGroup,"find",eu_getgrp,1);
  rb_define_singleton_method(rb_cGroup,"parse",eu_sgetgrent,1);
  rb_define_singleton_method(rb_cGroup,"set",eu_setgrent,0);
  rb_define_singleton_method(rb_cGroup,"end",eu_endgrent,0);
  rb_define_singleton_method(rb_cGroup,"each",eu_getgrent,0);

  rb_define_method(rb_cGroup, "fputs", group_putgrent,1);
  rb_define_method(rb_cGroup, "to_entry", group_gr_entry,0);
#endif

#ifdef GSHADOW
  rb_define_attr(rb_cGshadow, "name", 1, 1);
  rb_define_attr(rb_cGshadow, "passwd", 1, 1);
  rb_define_attr(rb_cGshadow, "admins", 1, 1);
  rb_define_attr(rb_cGshadow, "members", 1, 1);

  rb_define_singleton_method(rb_cGshadow,"get",eu_getsgent,0);
  rb_define_singleton_method(rb_cGshadow,"find",eu_getsgrp,1); //getsgent, getsguid
  rb_define_singleton_method(rb_cGshadow,"parse",eu_sgetsgent,1);
  rb_define_singleton_method(rb_cGshadow,"set",eu_setsgent,0);
  rb_define_singleton_method(rb_cGshadow,"end",eu_endsgent,0);
  rb_define_singleton_method(rb_cGshadow,"each",eu_getsgent,0);
  rb_define_method(rb_cGshadow, "fputs", group_putsgent, 1);
  rb_define_method(rb_cGshadow, "to_entry", group_sg_entry,0);
#else
  /* macOS/BSD: Define stub methods that raise NotImplementedError */
  rb_define_singleton_method(rb_cGshadow,"get",gshadow_not_implemented,-1);
  rb_define_singleton_method(rb_cGshadow,"each",gshadow_not_implemented,-1);
  rb_define_singleton_method(rb_cGshadow,"find",gshadow_not_implemented,-1);
  rb_define_singleton_method(rb_cGshadow,"parse",gshadow_not_implemented,-1);
  rb_define_singleton_method(rb_cGshadow,"set",gshadow_not_implemented,-1);
  rb_define_singleton_method(rb_cGshadow,"end",gshadow_not_implemented,-1);

  rb_define_method(rb_cGshadow,"to_entry",gshadow_instance_not_implemented,-1);
  rb_define_method(rb_cGshadow,"fputs",gshadow_instance_not_implemented,-1);
#endif
}
