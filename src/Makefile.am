# Sources for lxc

module_DATA = \
  modules/Lxc.rb

client_DATA = \
  clients/lxc.rb

yncludedir = @yncludedir@/lxc
ynclude_DATA = \
  include/lxc/wizards.rb \
  include/lxc/dialogs.rb \
  include/lxc/helps.rb

desktop_DATA = \
  desktop/lxc.desktop

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common