# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:	clients/lxc.ycp
# Package:	Configuration of lxc
# Summary:	Main file
# Authors:	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
#
# Main file for lxc configuration. Uses all other files.
module Yast
  class LxcClient < Client
    def main
      Yast.import "UI"

      #**
      # <h3>Configuration of lxc</h3>

      textdomain "lxc"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Lxc module started")

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Summary"

      Yast.import "CommandLine"
      Yast.include self, "lxc/wizards.rb"

      @cmdline_description = {
        "id"         => "lxc",
        # Command line help text for the Xlxc module
        "help"       => _(
          "Configuration of LXC"
        ),
        "guihandler" => fun_ref(method(:LxcSequence), "any ()"),
        "initialize" => fun_ref(Lxc.method(:Read), "boolean ()"),
        "actions"    => {},
        "options"    => {},
        "mappings"   => {}
      }

      # main ui function
      @ret = nil

      @ret = CommandLine.Run(@cmdline_description)
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Lxc module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::LxcClient.new.main
