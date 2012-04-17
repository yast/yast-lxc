# Makefile.am for lxc/src

yncludedir = @yncludedir@/lxc

client_DATA =			\
	lxc.ycp

ynclude_DATA =			\
	dialogs.ycp

desktop_DATA =			\
	lxc.desktop

module_DATA =			\
	Lxc.ycp

# create a symlink for local build, #145327
lxc:
	ln -sf . $@
ycpchook = lxc

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
