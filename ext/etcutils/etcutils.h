#include "extconf.h"
#include "ruby.h"

#ifdef HAVE_RUBY_IO_H
#include "ruby/io.h"
#define RTIME_VAL(x) (x)
#else
#include "rubyio.h"
#define RTIME_VAL(x) (x.tv_sec)
#endif

#ifdef HAVE_SHADOW_H
#include <shadow.h>
#ifndef SHADOW
#define SHADOW "/etc/shadow"
#endif
#define PW_DEFAULT_PASS setup_safe_str("x")
#else
#define PW_DEFAULT_PASS setup_safe_str("*")
#endif

#ifdef HAVE_PWD_H
#include <pwd.h>
#ifndef PASSWD
#define PASSWD "/etc/passwd"
#endif
#endif

#ifdef HAVE_GSHADOW_H
#include <gshadow.h>
#elif defined(HAVE_GSHADOW__H)
#include <gshadow_.h>
#define HAVE_GSHADOW_H 1
#endif

#ifdef HAVE_GSHADOW_H
#ifndef GSHADOW
#define GSHADOW "/etc/gshadow"
#endif
#endif

#ifdef HAVE_GRP_H
#include <grp.h>
#ifndef GROUP
#define GROUP "/etc/group"
#endif
#endif

#ifndef DEFAULT_SHELL
#define DEFAULT_SHELL "/bin/bash"
#endif

#ifdef HAVE_ST_SG_NAMP
#define SGRP_NAME(s) (s)->sg_namp
#else
#define SGRP_NAME(s) (s)->sg_name
#endif

#ifdef HAVE_STRUCT_RB_IO_T_PATHV
#define RFILE_PATH(x) (RFILE(x)->fptr)->pathv
#else
#define RFILE_PATH(x) ( setup_safe_str( (RFILE(x)->fptr)->path ) )
#endif

#ifdef HAVE_RB_IO_STDIO_FILE
#define RFILE_FPTR(x) rb_io_stdio_file( RFILE(x)->fptr )
#else
#define RFILE_FPTR(x) (RFILE(x)->fptr)->f
#endif

#ifndef RSTRING_BLANK_P
#define RSTRING_BLANK_P(x) (NIL_P(x) || RSTRING_LEN(x) == 0)
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

extern ID id_name, id_passwd, id_uid, id_gid;
extern VALUE mEtcUtils;

extern VALUE rb_cPasswd;
extern VALUE rb_cShadow;
extern VALUE rb_cGroup;
extern VALUE rb_cGshadow;

/* EU helper functions */
extern uid_t uid_global;
extern gid_t gid_global;
extern VALUE assigned_uids;
extern VALUE assigned_gids;

extern VALUE next_uid( int argc, VALUE *argv, VALUE self);
extern VALUE next_gid( int argc, VALUE *argv, VALUE self);
extern VALUE iv_get_time(VALUE self, const char *name);
extern VALUE iv_set_time(VALUE self, VALUE v, const char *name);
extern void eu_errno(VALUE str);
extern void ensure_file(VALUE io);

extern char** setup_char_members(VALUE ary);
extern void free_char_members(char ** mem, int c);

extern VALUE setup_safe_str(const char *str);
extern VALUE setup_safe_array(char **arr);

extern VALUE setup_shadow(struct spwd *shadow);
extern VALUE setup_passwd(struct passwd *pwd);

extern VALUE setup_group(struct group *grp);
#if defined(HAVE_GSHADOW_H) || defined(HAVE_GSHADOW__H)
extern VALUE setup_gshadow(struct sgrp *sgroup);
#endif

extern VALUE eu_to_entry(VALUE self, VALUE(*user_to)(VALUE, VALUE));

extern VALUE eu_setpwent(VALUE self);
extern VALUE eu_setspent(VALUE self);
extern VALUE eu_setgrent(VALUE self);
extern VALUE eu_setsgent(VALUE self);

extern VALUE eu_endpwent(VALUE self);
extern VALUE eu_endspent(VALUE self);
extern VALUE eu_endsgent(VALUE self);
extern VALUE eu_endgrent(VALUE self);

extern VALUE eu_getpwent(VALUE self);
extern VALUE eu_getspent(VALUE self);
extern VALUE eu_getgrent(VALUE self);
extern VALUE eu_getsgent(VALUE self);

extern VALUE eu_getpwd(VALUE self, VALUE v);
extern VALUE eu_getspwd(VALUE self, VALUE v);
extern VALUE eu_getgrp(VALUE self, VALUE v);
extern VALUE eu_getsgrp(VALUE self, VALUE v);

extern VALUE eu_sgetpwent(VALUE self, VALUE nam);
extern VALUE eu_sgetspent(VALUE self, VALUE nam);
extern VALUE eu_sgetgrent(VALUE self, VALUE nam);
extern VALUE eu_sgetsgent(VALUE self, VALUE nam);
/* END EU helper functions */

/* EU User functions */
extern VALUE user_putpwent(VALUE self, VALUE io);
extern VALUE user_putspent(VALUE self, VALUE io);
/* END EU User functions */

/* EU Group functions */
extern VALUE group_putgrent(VALUE self, VALUE io);
extern VALUE group_putsgent(VALUE self, VALUE io);
/* END EU Group functions */

extern VALUE rb_ary_uniq_bang(VALUE ary);

extern void Init_etcutils_main();
extern void Init_etcutils_user();
extern void Init_etcutils_group();
