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

# File:	modules/Lxc.ycp
# Package:	Configuration of lxc
# Summary:	Lxc settings, input and output functions
# Authors:	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
#
# Representation of the configuration of lxc.
# Input and output routines.
require "yast"

module Yast
  class LxcClass < Module
    def main
      Yast.import "UI"
      textdomain "lxc"

      Yast.import "Directory"
      Yast.import "FileUtils"
      Yast.import "Progress"
      Yast.import "Security"
      Yast.import "String"


      # text or graphic mode?
      @textmode = false

      # current password encryption method
      @method = "des"
    end

    # read list of available templates
    def ReadTemplates
      ret = []
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          "rpm -ql lxc | grep 'templates/' | cut -f 2- -d -"
        )
      )
      if Ops.get_string(out, "stdout", "") != ""
        Builtins.foreach(
          Builtins.sort(
            Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")
          )
        ) do |line|
          if line != ""
            ret = Builtins.add(
              ret,
              # sles goes later = selected if present
              Item(line, line == "sles" || line == "opensuse")
            )
          end
        end
      end
      deep_copy(ret)
    end

    # Encrypt given password using current method
    def CryptPassword(pw)
      return Builtins.cryptmd5(pw) if @method == "md5"
      return Builtins.cryptblowfish(pw) if @method == "blowfish"
      return Builtins.cryptsha256(pw) if @method == "sha256"
      return Builtins.cryptsha512(pw) if @method == "sha512"
      Builtins.crypt(pw)
    end

    # Read list of available bridges
    def ReadBridgesIds
      ret = []
      if FileUtils.Exists("/sbin/brctl")
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            "/sbin/brctl show | tail -n +2 | cut -f 1"
          )
        )

        if Ops.get_string(out, "stdout", "") != ""
          ret = Builtins.maplist(
            Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")
          ) { |line| line }
        end
      end
      deep_copy(ret)
    end

    # Read list of containers and their states
    def GetContainers
      ret = {}

      out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "lxc-ls -1")
      )

      Builtins.foreach(
        Builtins.sort(
          Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")
        )
      ) do |line|
        if line != "" && !Builtins.haskey(ret, line)
          cmd = Builtins.sformat("lxc-info -n %1 | grep state", line)
          out = Convert.to_map(
            SCR.Execute(path(".target.bash_output"), cmd, { "LANG" => "C" })
          )
          state = Builtins.splitstring(
            Builtins.deletechars(Ops.get_string(out, "stdout", ""), " \t\n"),
            ":"
          )
          Ops.set(ret, line, Ops.get(state, 1, "") == "RUNNING")
        end
      end
      deep_copy(ret)
    end

    # Check if LXC is correctly configured
    def CheckLXCConfiguration
      problem = false

      out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "/usr/bin/id --user")
      )
      root = Ops.get_string(out, "stdout", "") == "0\n"

      # zgrep does not seem to work with .target.bash_output -> grep uncompressed config
      tmpdir = Directory.tmpdir
      SCR.Execute(
        path(".target.bash_output"),
        Builtins.sformat(
          "cp /proc/config.gz '%1/' && gunzip '%1/config.gz'",
          String.Quote(tmpdir)
        )
      )

      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "LANG=C GREP=grep CONFIG='%1/config' /usr/bin/lxc-checkconfig",
            String.Quote(tmpdir)
          )
        )
      )

      rt = []
      colors = { "blue" => "", "red" => "", "yellow" => "" }
      Builtins.foreach(
        Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")
      ) do |line|
        colored = false
        Builtins.foreach(colors) do |name, color|
          raise Break if colored
          found2 = Builtins.find(line, color)
          if found2 != nil && Ops.greater_than(found2, 0)
            if @textmode
              line = Builtins.sformat(
                "%1<i>%2</i>",
                Builtins.substring(line, 0, found2),
                Builtins.substring(line, Ops.add(found2, Builtins.size(color)))
              )
            else
              line = Builtins.sformat(
                "%1<font color=%2>%3</font>",
                Builtins.substring(line, 0, found2),
                name,
                Builtins.substring(line, Ops.add(found2, Builtins.size(color)))
              )
            end
            colored = true
            if name == "red" || name == "yellow"
              # When running as root, "File capabilities" warning is not relevant (bnc#776172)
              if root && Builtins.issubstring(line, "File capabilities")
                Builtins.y2milestone(
                  "File capabilities not met. Ignoring the warning for root user."
                )
              else
                problem = true
              end
            end
          end
        end
        # 'normalizing' color
        found = Builtins.find(line, "")
        if found != nil && Ops.greater_or_equal(found, 0)
          line = Ops.add(
            Builtins.substring(line, 0, found),
            Builtins.substring(line, Ops.add(found, Builtins.size("")))
          )
        end
        rt = Builtins.add(rt, line)
      end

      return true if !problem

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1.5),
          VSpacing(30),
          VBox(
            HSpacing(85),
            VSpacing(0.5),
            # info label (try to keep the text short)
            Label(
              _(
                "Some problems with LXC configuration were found. Check the documentation for details."
              )
            ),
            VSpacing(0.5),
            # output follows in widget below
            Left(Label(_("Output of 'lxc-checkconfig' script:"))),
            RichText(Id(:rt), Builtins.mergestring(rt, "<br>")),
            PushButton("OK")
          )
        )
      )

      UI.UserInput
      UI.CloseDialog

      false
    end

    # Read all lxc settings
    # @return true on success
    def Read
      # Lxc read dialog caption
      caption = _("Initializing LXC Configuration")

      steps = 2

      # We do not set help text here, because it was set outside
      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage
          _("Check LXC availability"),
          # Progress stage
          _("Read system settings")
        ],
        [
          # Progress step
          _("Check LXC availability..."),
          # Progress step
          _("Reading system settings..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )


      Progress.NextStage

      @textmode = Ops.get_boolean(UI.GetDisplayInfo, "TextMode", false)

      CheckLXCConfiguration()

      Progress.NextStage

      orig = Progress.set(false)

      Security.Read

      Progress.set(orig)

      security = Security.Export
      @method = Builtins.tolower(
        Ops.get_string(security, "PASSWD_ENCRYPTION", "des")
      )

      Progress.NextStage

      true
    end

    publish :variable => :textmode, :type => "boolean"
    publish :function => :ReadTemplates, :type => "list <term> ()"
    publish :function => :CryptPassword, :type => "string (string)"
    publish :function => :ReadBridgesIds, :type => "list <string> ()"
    publish :function => :GetContainers, :type => "map <string, boolean> ()"
    publish :function => :Read, :type => "boolean ()"
  end

  Lxc = LxcClass.new
  Lxc.main
end
