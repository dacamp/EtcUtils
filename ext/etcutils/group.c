#include "etcutils.h"
VALUE rb_cGroup, rb_cGshadow;

VALUE group_putgrent(VALUE self, VALUE io)
{
  struct group grp, *tmp_str;
  VALUE name = rb_struct_getmember(self,rb_intern("name"));
  VALUE passwd = rb_struct_getmember(self,rb_intern("passwd"));
  VALUE path = RFILE_PATH(io);
  long i;

  ensure_file(io);

  rewind(RFILE_FPTR(io));
  i = 0;
  while ( (tmp_str = fgetgrent(RFILE_FPTR(io))) ) {
    i++;
    if ( !strcmp(tmp_str->gr_name,StringValuePtr( name ) ) )
      rb_raise(rb_eArgError, "%s is already mentioned in %s:%ld",
	       tmp_str->gr_name,  StringValuePtr(path), i );
  }

  grp.gr_name   = StringValueCStr( name );
  grp.gr_passwd = StringValueCStr( passwd );
  grp.gr_gid    = NUM2GIDT( rb_struct_getmember(self,rb_intern("gid")) );
  grp.gr_mem    = setup_char_members( rb_struct_getmember(self,rb_intern("members")) );

  if ( putgrent(&grp,RFILE_FPTR(io)) )
    eu_errno(RFILE_PATH(io));

  free_char_members(grp.gr_mem, RARRAY_LEN( rb_struct_getmember(self,rb_intern("members")) ));

  return Qtrue;
}

VALUE group_putsgent(VALUE self, VALUE io)
{
  struct sgrp sgroup, *tmp_str;
  VALUE name = rb_struct_getmember(self,rb_intern("name"));
  VALUE passwd = rb_struct_getmember(self,rb_intern("passwd"));
  VALUE path = RFILE_PATH(io);
  long i;

  rewind(RFILE_FPTR(io));
  i = 0;
  while ( (tmp_str = fgetsgent(RFILE_FPTR(io))) ) {
    i++;
    if ( !strcmp(SGRP_NAME(tmp_str),StringValuePtr( name ) ) )
      rb_raise(rb_eArgError, "%s is already mentioned in %s:%ld",
	       SGRP_NAME(tmp_str),  StringValuePtr(path), i );
  }

#ifdef HAVE_ST_SG_NAMP
  sgroup.sg_namp = StringValueCStr( name );
#endif
#if HAVE_ST_SG_NAME
  sgroup.sg_name = StringValueCStr( name );
#endif

  sgroup.sg_passwd = StringValueCStr( passwd );
  // char** members start here
  sgroup.sg_adm    = setup_char_members( rb_struct_getmember(self,rb_intern("admins")) );
  sgroup.sg_mem    = setup_char_members( rb_struct_getmember(self,rb_intern("members")) );

  if ( putsgent(&sgroup,RFILE_FPTR(io)) )
    eu_errno(RFILE_PATH(io));

  free_char_members(sgroup.sg_adm, RARRAY_LEN( rb_struct_getmember(self,rb_intern("admins")) ) );
  free_char_members(sgroup.sg_mem, RARRAY_LEN(  rb_struct_getmember(self,rb_intern("members")) ) );

  return Qtrue;
}

VALUE setup_group(struct group *grp)
{
  if (!grp) errno  || (errno = 61); // ENODATA
  eu_errno( setup_safe_str ( "Error setting up Group instance." ) );

  VALUE obj = rb_obj_alloc(rb_cGroup);

  rb_ivar_set(obj, id_name, setup_safe_str(grp->gr_name));
  rb_ivar_set(obj, id_passwd, setup_safe_str(grp->gr_passwd));
  rb_ivar_set(obj, id_gid, GIDT2NUM(grp->gr_gid));
  rb_iv_set(obj, "@members", setup_safe_array(grp->gr_mem));

  return obj;
}

VALUE setup_gshadow(struct sgrp *sgroup)
{
#if defined(HAVE_GSHADOW_H) || defined(HAVE_GSHADOW__H)  
  if (!sgroup) errno  || (errno = 61); // ENODATA
  eu_errno( setup_safe_str ( "Error setting up GShadow instance." ) );

  VALUE obj = rb_obj_alloc(rb_cGroup);

  rb_ivar_set(obj, id_name, setup_safe_str(SGRP_NAME(sgroup)));
  rb_ivar_set(obj, id_passwd, setup_safe_str(sgroup->sg_passwd));
  rb_iv_set(obj, "@admins", setup_safe_array(sgroup->sg_adm));
  rb_iv_set(obj, "@members", setup_safe_array(sgroup->sg_mem));
  return obj;
#else
  return Qnil;
#endif
}

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

  rb_define_method(rb_cGroup, "fputs", group_putgrent, 1);
  rb_define_method(rb_cGroup, "to_entry", eu_to_entry,0);

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
  rb_define_method(rb_cGshadow, "to_entry", eu_to_entry,0);
}
