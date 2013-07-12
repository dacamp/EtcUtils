#
# extconf.rb
#
# Modified at: <2013/07/04 16:12:45 by dcampbell>
#

require 'mkmf'

have_header('ruby.h') or missing('ruby.h')
have_header('ruby/io.h') or have_header('rubyio.h')
have_header('ruby/encoding.h')

if (have_library("shadow") or have_header('shadow.h'))
  have_var('SHADOW', 'shadow.h')
  have_library("gshadow")
  have_header('pwd.h')
  have_header('grp.h')


  ["gshadow.h","gshadow_.h"].each do |h|
    if have_header(h)
      have_var('GSHADOW', h)
      nam = "sg_nam"+ (h =~ /_/ ? 'e' : 'p')
      [nam, "sg_passwd", "sg_adm", "sg_mem"].each do |m|
        have_struct_member("struct sgrp", m, h)
      end
    end
  end

  ['sp','sg','pw','gr'].each do |h|
    ["get#{h}ent","sget#{h}ent","fget#{h}ent","put#{h}ent","set#{h}ent","end#{h}ent"].each do |func|
      have_func(func)
    end
  end
  have_func("lckpwdf")
  have_func("ulckpwdf")

  if with_config("debug")
    $defs.push("-DDEBUG -Wall") unless $defs.include? "-DDEBUG"
  end

  create_makefile("etcutils")
else
  puts "This system is not managed by shadow files... Exiting"
end
