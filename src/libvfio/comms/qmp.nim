#
# Copyright: 2666680 Ontario Inc.
# Reason: Code to interact with QMP for different commands.
#
import asyncnet
import asyncdispatch
import os
import options
import nativesockets
import json
import logging
import strformat
import strutils

import ../types

proc sendMessage*(socket: AsyncSocket, msg: QmpCommand) {.async.} =
  ## sendMessage - Sends a message to the QMP.
  ##
  ## Inputs
  ## @socket - Socket to send on.
  ## @msg - Message to send to the QMP.
  ##
  ## Returns
  ## result - A boolean saying if the command was executed correctly or not.
  ##
  ## Side effects - Sends a message to the socket.
  debug("Sending to socket: ", $(%*msg))
  await send(socket, $(%*msg))

proc getResponse*(sock: AsyncSocket):
                Future[QmpResponse] {.async.} =
  ## getResponse - Gets the next response from the QMP socket.
  ##
  ## Inputs
  ## @sock - Socket to get the response from.
  ## @timeout - Timeout in milliseconds.
  ##
  ## Return
  ## result - Resulting response.
  ##
  ## Side effects - Reads a response from the socket.
  let r = await recvLine(sock)
  debug("Received from socket: ", r)
  try:
    result = parseResponse(parseJson(r))
  except:
    result = QmpResponse(event: qrInvalid, errorMessage: &"Not parsed: {$r}")
  debug("Response: ", $result)

proc createSocket*(sockPath: string): Option[AsyncSocket] =
  ## createSocket - Creates a socket for communicating with a QMP system.
  ##
  ## Inputs
  ## @sockPath - Path to communicate over a socket to.
  ##
  ## Returns
  ## result - Resulting socket.
  ##
  ## Side effects - Locks a socket file, and creates a communication
  ##                 channel into the file.
  result = none(AsyncSocket)

  var
    sock = newAsyncSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
    count = 0

  while count < 120:
  # proc will proceed once connection to vm's socket established
  #  or until timeout reached
    try:
      count = count + 1
      waitFor(connectUnix(sock, sockPath))        ## Connecting to the socket
      break                                       ## Breaks loop if exeption not
                                                  ##  previously reached on connect attempt
    except:
      debug("Exception reached while connecting to socket.")
      sleep(500)

  debug(fmt"socket connection attempted {count} times.")

  #Timeout. Exit the proc
  if count >= 120:
    error("Waited for socket connection to be established but was unsuccesful")
    return
  else:
    info("Connected to socket")

  let
    line = waitFor(recvLine(sock))
    json = parseJson(line)

  case extractVersion(json)
  of "4.2.1":
    discard
  else:
    warn("QMP has not been tested for this version")

  let
    cmd = QmpCommand(command: qcQueryCapabilities)

  asyncCheck(sendMessage(sock, cmd))

  while true:
    let x = waitFor(getResponse(sock))

    case x.event
    of qrSuccess:
      result = some(sock)
      break
    of qrInvalid, qrError:
      error(x.errorMessage)
      break
    else: discard
