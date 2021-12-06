
# Copyright: 2666680 Ontario Inc.
# Reason: Code to interact with terminal.
#
import std/os
import std/osproc
import std/posix
import std/streams
import std/strutils
import std/terminal

import std/logging

import ../types

proc sendCommand*(monad: CommandMonad, cmd: Args): bool =
  ## sendCommand - Sends a command into the command monad.
  ##
  ## Inputs
  ## @monad - Monad to write into.
  ## @cmd - Command to write.
  ##
  ## Side Effects - Sends arbitrary command to the command monad.
  let
    realCommand = join(cmd.exec & cmd.args, " ")
  info("Executing: ", $cmd)
  if monad.sudo:
    discard seteuid(monad.rootUid)
  result = execCmd(realCommand) == 0
  if monad.sudo:
    discard seteuid(monad.oldUid)

proc startCommand*(monad: CommandMonad, cmd: Args): owned(Process) =
  ## startCommand - Starts a command from a command monad.
  ##
  ## Inputs
  ## @monad - Monad to use.
  ## @cmd - Command to start.
  ##
  ## Side Effects - Sends arbitrary command to the command monad.
  info("Executing: ", $cmd)
  if monad.sudo:
    discard seteuid(monad.rootUid)
  result = startProcess(
    command=cmd.exec,
    args=cmd.args
  )
  if monad.sudo:
    discard seteuid(monad.oldUid)

proc createCommandMonad*(sudo: bool): CommandMonad =
  ## createCommandMonad - Creates a monad for piping commands through.
  ##
  ## Inputs
  ## @sudo - If this is the root monad or not
  ##
  ## Returns
  ## result - A monad which you can use for sending commands to system.
  ##
  ## Side Effects - VERY DANGEROUS minimize how often you use this.
  result.oldUid = getuid()
  result.rootUid = 0
  result.sudo = sudo
