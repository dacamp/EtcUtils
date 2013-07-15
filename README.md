etcutils
========

Ruby C Extension for Linux reads and writes to etc dbfiles.

Tested and works on ruby 1.8.7, 1.9.3.

Huge work in progress and lots remain, if you're at all interested,
please send pull requests.

Use at your own risk!! You can do a lot of damage using this module at
this point, so please be careful before you dive in.

Issues

* Encapsulate pwd,spwd,grp,sgrp C structs into Ruby objects.
* Remove a few of the duplicated functions.
* Sanity checking (lots of it!!)
