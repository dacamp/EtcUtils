#
# extconf.rb
#
# Modified at: <2013/07/04 16:12:45 by dcampbell>
#

require 'mkmf'

have_header('ruby/io.h')
have_struct_member("struct rb_io_t", "pathv", "ruby/io.h")
have_func('rb_io_stdio_file')
have_func('eaccess')

have_header('etcutils.h')

if (have_header('pwd.h') && have_header('grp.h'))
  short_v = ['pw','gr']

  if have_header('shadow.h')
    short_v << 'sp'
  end

  ["gshadow.h","gshadow_.h"].each do |h|
    short_v << 'sg'
    if have_header(h)
      nam = "sg_nam"+ (h =~ /_/ ? 'e' : 'p')
      [nam, "sg_passwd", "sg_adm", "sg_mem"].each do |m|
        have_struct_member("struct sgrp", m, h)
      end
    end
  end

  have_func("lckpwdf")
  have_func("ulckpwdf")

  short_v.each do |h|
    ["get#{h}ent","sget#{h}ent","fget#{h}ent","put#{h}ent","set#{h}ent","end#{h}ent"].each do |func|
      have_func(func)
    end
  end

  create_header
  create_makefile("etcutils")
else
  puts "This system is not managed by passwd/group files.","Exiting"
end
