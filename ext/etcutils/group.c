#include "etcutils.h"
VALUE rb_cGroup;

#if defined(HAVE_GSHADOW_H) || defined(HAVE_GSHADOW__H)
VALUE setup_gshadow(struct sgrp *sgroup)
{
  if (!sgroup) errno  || (errno = 61); // ENODATA
  etcutils_errno( setup_safe_str ( "Error setting up GShadow instance." ) );
  return rb_struct_new(cGShadow,
		       setup_safe_str(SGRP_NAME(sgroup)),
		       setup_safe_str(sgroup->sg_passwd),
		       setup_safe_array(sgroup->sg_adm),
		       setup_safe_array(sgroup->sg_mem),
		       NULL);
}
#endif

VALUE setup_group(struct group *grp)
{
  if (!grp) errno  || (errno = 61); // ENODATA
  etcutils_errno( setup_safe_str ( "Error setting up Group instance." ) );
  return rb_struct_new(cGroup,
		       setup_safe_str(grp->gr_name),
		       setup_safe_str(grp->gr_passwd),
		       GIDT2NUM(grp->gr_gid),
		       setup_safe_array(grp->gr_mem),
		       NULL);
}

void Init_etcutils_group()
{
  VALUE rb_cGroup = rb_define_class_under(mEtcUtils,"Group2",rb_cObject);
}
