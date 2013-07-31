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
  module LxcDialogsInclude
    def initialize_lxc_dialogs(include_target)
      textdomain "lxc"

      Yast.import "FileUtils"
      Yast.import "IP"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Security"
      Yast.import "String"
      Yast.import "Wizard"

      Yast.include include_target, "lxc/helps.rb"

      # PIDs of running consoles (indexed by lxc names)
      @console_pids = {}
    end

    # Create configuration file for a container
    # @return success
    def CreateContainerConfig(name, ip, subnet, bridge, template)
      # busy message
      Popup.ShowFeedback("", _("Creating Configuration..."))

      # lxc-createconfig -n <name> [-i <ipaddr/cidr>] [-b <bridge>] [-t <template]
      cmd = Builtins.sformat("echo 'y' | lxc-createconfig -n %1", name)
      if ip != ""
        cmd = Ops.add(Ops.add(cmd, " -i "), ip)
        if subnet != ""
          cmd = Ops.add(cmd, "/") if Builtins.substring(subnet, 0, 1) != "/"
          cmd = Ops.add(cmd, subnet)
        end
      end

      cmd = Ops.add(Ops.add(cmd, " -b "), bridge) if bridge != ""

      cmd = Ops.add(Ops.add(cmd, " -t "), template) if template != ""

      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

      Popup.ClearFeedback

      if Ops.get_integer(out, "exit", 0) != 0
        Builtins.y2milestone("cmd: %1", cmd)
        Builtins.y2milestone("lxc-createconfig output: %1", out)

        # error message
        Report.Error(
          Builtins.sformat(
            _("Error occured during configuration:\n\n%1"),
            Ops.get_string(out, "stdout", "")
          )
        )
        return false
      end
      true
    end

    # Dialog for adding new Linux Container
    # @return dialog result
    def AddDialog
      # add dialog caption
      caption = _("Adding New Container")

      template_items = Lxc.ReadTemplates

      contents = HBox(
        HSpacing(),
        VBox(
          VSpacing(),
          # frame label
          Frame(
            _("New Container"),
            HBox(
              HSpacing(0.5),
              # text entry
              Left(TextEntry(Id(:name), _("Name"))),
              HSpacing(),
              # combo box label
              ComboBox(Id(:template), _("Template"), template_items)
            )
          ),
          VSpacing(),
          # frame label
          Frame(
            _("Network Settings"),
            HBox(
              HSpacing(0.5),
              VBox(
                HBox(
                  # text entry label
                  TextEntry(Id(:ip), _("IP Address"), "0.0.0.0"),
                  HSpacing(),
                  # text entry label
                  TextEntry(Id(:subnet), _("Subnet"), "/24"),
                  HSpacing(),
                  ReplacePoint(
                    Id(:rp_lan),
                    # combo box label
                    ComboBox(Id(:bridge), _("Bridge"), Lxc.ReadBridgesIds)
                  )
                ),
                VSpacing(0.5),
                Right(
                  # push button label
                  PushButton(Id(:lan), _("Configure Network..."))
                )
              ),
              HSpacing(0.5)
            )
          ),
          VSpacing(),
          # frame label
          Frame(
            _("Password Settings"),
            HBox(
              HSpacing(0.5),
              # password entry
              HWeight(1, Password(Id(:pw1), _("Root Password"))),
              # password entry
              HWeight(1, Password(Id(:pw2), _("Repeat Password"))),
              HSpacing(0.5)
            )
          ),
          VSpacing(2),
          ReplacePoint(Id(:rp_status), Label(Id(:status), "")),
          VSpacing()
        ),
        HSpacing()
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "create", ""),
        # button label
        Label.CancelButton,
        _("Create")
      )

      UI.ChangeWidget(Id(:ip), :ValidChars, IP.ValidChars4)
      UI.ChangeWidget(Id(:name), :ValidChars, String.CGraph)

      ret = nil
      while true
        ret = UI.UserInput

        break if ret == :abort || ret == :cancel || ret == :back

        if ret == :lan
          WFM.CallFunction("lan")
          UI.ReplaceWidget(
            Id(:rp_lan),
            # combo box label
            ComboBox(Id(:bridge), _("Bridge"), Lxc.ReadBridgesIds)
          )
          next
        end

        name = Convert.to_string(UI.QueryWidget(Id(:name), :Value))
        ip = Convert.to_string(UI.QueryWidget(Id(:ip), :Value))
        subnet = Convert.to_string(UI.QueryWidget(Id(:subnet), :Value))
        bridge = Convert.to_string(UI.QueryWidget(Id(:bridge), :Value))
        template = Convert.to_string(UI.QueryWidget(Id(:template), :Value))
        pw1 = Convert.to_string(UI.QueryWidget(Id(:pw1), :Value))
        pw2 = Convert.to_string(UI.QueryWidget(Id(:pw2), :Value))

        if name == ""
          # error popup
          Report.Error(_("Name was not entered."))
          UI.SetFocus(Id(:name))
          next
        end

        if ip != "" && !IP.Check(ip)
          Report.Error(IP.Valid4)
          UI.SetFocus(Id(:ip))
          next
        end
        if pw1 != pw2
          # error message
          Report.Error(_("The passwords do not match."))
          UI.SetFocus(Id(:pw1))
          next
        end

        if ret == :next
          config_file = Builtins.sformat("/root/%1.config", name)
          create_config = true

          if FileUtils.Exists(config_file)
            if !Popup.AnyQuestion(
                Popup.NoHeadline,
                # yes/no popup
                _(
                  "Configuration with the same name already exist.\n" +
                    "\n" +
                    "Do you want to use existing configuration or\n" +
                    "remove it and use the data you have just entered?\n"
                ),
                # button label
                _("Use Existing Configuration"),
                _("Replace With New"),
                :focus_yes
              )
              SCR.Execute(path(".target.remove"), config_file)
            else
              create_config = false
            end
          end

          if create_config &&
              CreateContainerConfig(name, ip, subnet, bridge, template) == false
            next
          end

          # busy message
          Popup.ShowFeedback(
            "",
            Builtins.sformat(_("Creating Container %1..."), name)
          )

          # lxc-create -n <name> -f /root/<name>.config -t <template>
          cmd = Builtins.sformat("lxc-create -n %1 -f /root/%1.config", name)
          cmd = Ops.add(Ops.add(cmd, " -t "), template) if template != ""

          out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

          Popup.ClearFeedback

          if Ops.get_integer(out, "exit", 0) != 0
            Builtins.y2milestone("cmd: %1", cmd)
            Builtins.y2milestone("lxc-create output: %1", out)

            Report.Error(
              Builtins.sformat(
                _(
                  "Error occured during container creation:\n" +
                    "\n" +
                    "%1"
                ),
                Ops.get_string(out, "stdout", "")
              )
            )
            next
          end

          # busy message
          Popup.ShowFeedback("", _("Saving Root Password..."))

          password = Lxc.CryptPassword(pw1)

          file = Builtins.sformat("/var/lib/lxc/%1/rootfs/etc/shadow", name)
          if pw1 != "" && FileUtils.Exists(file)
            # slash would break sed command
            password = Builtins.mergestring(
              Builtins.splitstring(password, "/"),
              "\\/"
            )
            # change the root password in the file /var/lib/lxc/<name>/rootfs/etc/shadow/
            cmd = Builtins.sformat(
              "sed --in-place 's/^root:[^:]*:/root:%1:/' %2",
              password,
              file
            )
            out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
            Builtins.y2security("out: %1", out)
          end
          Popup.ClearFeedback
          Popup.Message(
            Builtins.sformat(
              _("Container '%1' was successfully created."),
              name
            )
          )
          break
        end
      end
      deep_copy(ret)
    end


    # Start selected container
    # @return success
    def StartContainer(name)
      # start container as a deamon, so it survives YaST's exit
      cmd = Builtins.sformat("lxc-start -d -n %1", name)

      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

      if Ops.get_integer(out, "exit", 0) != 0
        Report.Error(
          Builtins.sformat(
            _("Error while starting container:\n\n%1"),
            Ops.add(
              Ops.get_string(out, "stdout", ""),
              Ops.get_string(out, "stderr", "")
            )
          )
        )
        return false
      end
      if Lxc.textmode
        # message, %1 is a name
        Popup.Message(
          Builtins.sformat(
            _(
              "The Container '%1' was started in the background.\nUse 'lxc-console' command to connect to the running Container."
            ),
            name
          )
        )
      end
      true
    end

    # Stop given container
    def StopContainer(name)
      Builtins.y2milestone(
        "result of lxc-stop: %1",
        SCR.Execute(path(".target.bash_output"), Ops.add("lxc-stop -n ", name))
      )
      if Ops.get(@console_pids, name) != nil
        # close the console if stopping
        SCR.Execute(path(".process.kill"), Ops.get(@console_pids, name), 15)
      end

      nil
    end

    # Delete given container
    # @return success
    def DestroyContainer(name)
      # busy message
      Popup.ShowFeedback(
        "",
        Builtins.sformat("Destroying Container '%1'...", name)
      )

      cmd = Ops.add("lxc-destroy -n ", name)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

      Popup.ClearFeedback

      if Ops.get_integer(out, "exit", 0) != 0
        Builtins.y2milestone("lxc-destroy output: %1", out)
        # error message
        Report.Error(
          Builtins.sformat(
            _("Error while destroying:\n\n%1"),
            Ops.get_string(out, "stdout", "")
          )
        )
        return false
      end
      true
    end

    # Launch console for selected container
    # Return PID of console process
    def Connect(name)
      cmd = Builtins.sformat("xterm -e lxc-console -n %1", name)

      pid = Convert.to_integer(SCR.Execute(path(".process.start_shell"), cmd))

      pid
    end

    # Overview of existing Linux Containers
    # @return dialog result
    def OverviewDialog
      # LXC overview dialog caption
      caption = _("LXC Configuration")

      # current container
      selected = ""

      # mapping of containers to their state
      lxc_map = {}

      # update status of the buttons according to current item
      update_buttons = lambda do |selected2|
        return if selected2 == nil || selected2 == ""

        running = Ops.get(lxc_map, selected2, false)
        UI.ChangeWidget(Id(:start), :Enabled, !running)
        UI.ChangeWidget(Id(:stop), :Enabled, running)
        return if Lxc.textmode
        if Ops.get(@console_pids, selected2) == nil
          UI.ReplaceWidget(
            Id(:rp_console),
            # button label
            PushButton(Id(:connect), _("Connect"))
          )
          UI.ChangeWidget(Id(:connect), :Enabled, running)
        else
          UI.ReplaceWidget(
            Id(:rp_console),
            # button label
            PushButton(Id(:disconnect), _("Disconnect"))
          )
        end

        nil
      end

      # update table with fresh items
      update_table = lambda do
        lxc_map = Lxc.GetContainers
        lxc_list = Builtins.maplist(lxc_map) do |name, status|
          Item(
            name,
            status ?
              # container status
              _("Running") :
              # container status
              _("Stopped")
          )
        end

        UI.ChangeWidget(Id(:table), :Items, lxc_list)
        if Builtins.size(lxc_list) == 0
          Builtins.foreach([:table, :destroy, :start, :stop, :connect]) do |t|
            UI.ChangeWidget(Id(t), :Enabled, false)
          end
        else
          UI.SetFocus(Id(:table))
          UI.ChangeWidget(Id(:table), :CurrentItem, selected) if selected != ""
          selected = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
          update_buttons.call(selected)
        end

        nil
      end

      contents = HBox(
        HSpacing(),
        VBox(
          VSpacing(),
          # button label
          Right(PushButton(Id(:refresh), _("Refresh"))),
          # Table header
          Table(
            Id(:table),
            Opt(:notify, :immediate),
            Header(_("Name"), _("Status")),
            []
          ),
          HBox(
            PushButton(Id(:add_button), Opt(:key_F3), Label.CreateButton),
            # button label
            PushButton(Id(:destroy), Opt(:key_F5), _("&Destroy")),
            # button label
            Right(PushButton(Id(:start), _("&Start"))),
            # button label
            PushButton(Id(:stop), _("Sto&p")),
            ReplacePoint(
              Id(:rp_console),
              Lxc.textmode ?
                HBox() :
                # button label
                PushButton(Id(:connect), _("Connect"))
            )
          ),
          VSpacing()
        ),
        HSpacing()
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "overview", ""),
        Label.BackButton,
        Label.FinishButton
      )
      Wizard.HideBackButton

      update_table.call

      ret = nil

      while true
        # polling only if there's some process to watch
        if Ops.greater_than(Builtins.size(@console_pids), 0)
          Builtins.sleep(100)
          ret = UI.PollInput
        else
          ret = UI.UserInput
        end

        break if ret == :abort || ret == :cancel || ret == :next || ret == :back

        if ret == :add_button
          ret = :add
          break
        end
        selected = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
        console_pid = Ops.get(@console_pids, selected)

        # check the status of console process
        if console_pid != nil &&
            SCR.Read(path(".process.running"), console_pid) != true
          Builtins.y2milestone("console process is dead")
          @console_pids = Builtins.remove(@console_pids, selected)
          update_buttons.call(selected)
          next
        end

        update_buttons.call(selected) if ret == :table

        update_table.call if ret == :refresh

        if ret == :start
          StartContainer(selected)
          update_table.call
        end

        if ret == :connect && console_pid == nil
          Ops.set(@console_pids, selected, Connect(selected))
          update_buttons.call(selected)
        end

        if ret == :disconnect && console_pid != nil
          Builtins.y2milestone(
            "killing console proces with PID %1...",
            console_pid
          )
          SCR.Execute(path(".process.kill"), console_pid, 15)
          # FIXME timeout + kill -9
          @console_pids = Builtins.remove(@console_pids, selected)
          update_buttons.call(selected)
        end

        if ret == :stop
          StopContainer(selected)
          update_table.call
        end

        if ret == :destroy &&
            Popup.YesNo(
              Builtins.sformat(
                _("Are you sure to delete container '%1'?"),
                selected
              )
            )
          StopContainer(selected)
          DestroyContainer(selected)
          update_table.call
        end
      end

      deep_copy(ret)
    end
  end
end
