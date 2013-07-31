# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006 Novell, Inc. All Rights Reserved.
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

# File:	include/lxc/wizards.ycp
# Package:	Configuration of lxc
# Summary:	Wizards definitions
# Authors:	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  module LxcWizardsInclude
    def initialize_lxc_wizards(include_target)
      Yast.import "UI"

      textdomain "lxc"

      Yast.import "Confirm"
      Yast.import "Lxc"
      Yast.import "Sequencer"
      Yast.import "Wizard"

      Yast.include include_target, "lxc/dialogs.rb"
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "read", ""))
      return :abort if !Confirm.MustBeRoot
      ret = Lxc.Read
      ret ? :next : :abort
    end

    # Main workflow of the lxc configuration
    # @return sequence result
    def MainSequence
      aliases = { "overview" => lambda { OverviewDialog() }, "add" => lambda do
        AddDialog()
      end }

      sequence = {
        "ws_start" => "overview",
        "overview" => { :abort => :abort, :next => :next, :add => "add" },
        "add"      => { :abort => :abort, :next => "overview" }
      }

      ret = Sequencer.Run(aliases, sequence)

      deep_copy(ret)
    end

    # Whole configuration of lxc
    # @return sequence result
    def LxcSequence
      aliases = { "read" => [lambda { ReadDialog() }, true], "main" => lambda do
        MainSequence()
      end }

      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :next => "main" },
        "main"     => { :abort => :abort, :next => :next }
      }

      Wizard.CreateDialog
      Wizard.HideBackButton
      Wizard.HideAbortButton

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      deep_copy(ret)
    end
  end
end
