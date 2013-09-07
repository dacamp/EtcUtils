#include "extconf.h"
#include "ruby.h"

#ifdef HAVE_RUBY_IO_H
#include "ruby/io.h"
#else
#include "rubyio.h"
#endif

#ifdef HAVE_SHADOW_H
#include <shadow.h>
#ifndef SHADOW
#define SHADOW "/etc/shadow"
#endif
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
#endif

#ifndef GSHADOW
#define GSHADOW "/etc/gshadow"
#endif

#ifdef HAVE_GRP_H
#include <grp.h>
#ifndef GROUP
#define GROUP "/etc/group"
#endif
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
extern VALUE rb_cUser;
extern VALUE rb_cGroup;

static VALUE cShadow;
static VALUE cGShadow;
static VALUE cPasswd;
static VALUE cGroup;

/* EtcUtils helper functions */
extern uid_t uid_global;
extern gid_t gid_global;

extern VALUE next_uid( int argc, VALUE *argv, VALUE self);
extern VALUE next_gid( int argc, VALUE *argv, VALUE self);
extern VALUE iv_get_time( VALUE self, char *name);
extern VALUE iv_set_time( VALUE self, VALUE v, char *name);
extern void etcutils_errno(VALUE str);
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
/* End of helper functions */

extern void Init_etcutils_main();
extern void Init_etcutils_user();
extern void Init_etcutils_group();
