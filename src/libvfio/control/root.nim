
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

proc setresuid(a1, a2, a3: Uid): cint {.importc, header: "<unistd.h>".}

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
    if setresuid(monad.rootUid, monad.rootUid, monad.oldUid) != 0:
      error("Could not set root correctly: ", strerror(errno))
      return false
  result = execCmd(realCommand) == 0
  if monad.sudo:
    if setresuid(monad.oldUid, monad.oldUid, monad.rootUid) != 0:
      error("Could not set user correctly: ", strerror(errno))
      return false

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
    if setresuid(monad.rootUid, monad.rootUid, monad.oldUid) != 0:
      error("Could not set root correctly: ", strerror(errno))
  result = startProcess(
    command=cmd.exec,
    args=cmd.args,
    options={poParentStreams}
  )
  if monad.sudo:
    if setresuid(monad.oldUid, monad.oldUid, monad.rootUid) != 0:
      error("Could not set user correctly: ", strerror(errno))

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
