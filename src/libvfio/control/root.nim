#
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

proc setRoot*(monad: CommandMonad, root: bool): bool =
  ## setRoot - Sents the root uid for the monad.
  ##
  ## Inputs
  ## @monad - Monad to use for root.
  ## @root - If we set to root or to the user.
  ##
  ## Returns
  ## result - Result if we could set the monad or not.
  ##
  ## Side Effect - Makes the program root.
  let
    newUid = if root: monad.rootUid
             else: monad.oldUid
    oldUid = if root: monad.oldUid
             else: monad.rootUid

  result = true

  if setresuid(newUid, newUid, oldUid) != 0:
      error("Could not set root correctly: ", strerror(errno))
      return false

proc sendCommandList*(monad: CommandMonad, cmds: CommandList): bool =
  ## sendCommandList - Runs through a list of commands.
  ##
  ## Inputs
  ## @monad - Always a root monad, the command list will determine if root is
  ##          needed or not.
  ## @cmds - List of commands to run through.
  ##
  ## Returns
  ## result - The result of the entire command list.
  ##
  ## Side Effects - Sends an arbitrary list of commands to the command monad.
  result = true
  if cmds.is_root:
    if not setRoot(monad, true):
      return false

  for cmd in cmds.list:
    let realCmd = join(cmd.exec & cmd.args, " ")
    info("Executing: ", $cmd)
    result = result and execCmd(realCmd) == 0

  if cmds.is_root:
    result = result and setRoot(monad, false)

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
    if not setRoot(monad, true):
      return false
  result = execCmd(realCommand) == 0
  if monad.sudo:
    if not setRoot(monad, false):
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
    discard setRoot(monad, true)
  result = startProcess(
    command=cmd.exec,
    args=cmd.args,
    options={poParentStreams}
  )
  if monad.sudo:
    discard setRoot(monad, false)

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
