
# Copyright: 2666680 Ontario Inc.
# Reason: Code to interact with terminal.
#
import os
import osproc
import streams
import strutils
import terminal

import logging

import ../types

type
  ## MONAD: Creates a monad for commands
  CommandMonad* = object
    pid*: int
    commandPipe: owned(Process)
    outputStream: Stream
    errorStream: Stream
    inputStream: Stream

proc readCommand*(monad: CommandMonad): string =
  ## readCommand - Reads the command output.
  ##
  ## Inputs
  ## @monad - Monad to read from.
  ##
  ## Returns
  ## result - One line of the command output or error
  ##          stream.
  ## Side Effects - Reads the data from the commands.
  if not readLine(monad.outputStream, result):
    discard readLine(monad.errorStream, result)

proc sendCommand*(monad: CommandMonad, cmd: Args, log: bool = false) =
  ## sendCommand - Sends a command into the command monad.
  ##
  ## Inputs
  ## @monad - Monad to write into.
  ## @cmd - Command to write.
  ##
  ## Side Effects - Sends arbitrary command to the command monad.
  let
    realCommand = join(cmd.exec & cmd.args, " ")
  if log: info("Executing: ", realCommand)
  write(monad.inputStream, realCommand & "\n")
  flush(monad.inputStream)

proc createCommandMonad*(super: bool): CommandMonad =
  ## createCommandMonad - Creates a monad for piping commands through.
  ##
  ## Inputs
  ## @super - Is super user required or not?
  ##
  ## Returns
  ## result - A monad which you can use for sending commands to the
  ##          shell.
  ##
  ## Side Effects - VERY DANGEROUS minimize how often you use this.
  let command = if super: "/usr/bin/sudo"
                else: "/usr/bin/sh"
  result.commandPipe = startProcess(
    command,
    args=if super: @["-i"]
         else: @[],
    options={}
  )
  result.pid = processId(result.commandPipe)
  result.outputStream = peekableOutputStream(result.commandPipe)
  result.errorStream = peekableErrorStream(result.commandPipe)
  result.inputStream = inputStream(result.commandPipe)

  # If we need a superuser monad.
  if super:
    let pass = Args(exec: readPasswordFromStdin("Sudo password: "))
    let cd = Args(exec: "cd", args: @[getCurrentDir()])
    sendCommand(result, pass)
    sendCommand(result, cd, true)

proc commandMonadOpen*(monad: CommandMonad): bool =
  ## commandMonadOpen - Is the command monad currently open?
  ##
  ## Inputs
  ## @monad - Monad file to check.
  ##
  ## Returns
  ## result - Is the monad currently running
  running(monad.commandPipe)

proc killCommandMonad*(monad: CommandMonad) =
  ## killCommandMonad - Kills the command monad.
  ##
  ## Inputs
  ## @monad - Monad to kill.
  ##
  ## Side Effects - Removes a monad.
  terminate(monad.commandPipe)
