#
# Copyright: 2666680 Ontario Inc.
# Reason: Code to interact with QMP for different commands.
#
import std/[asyncnet, asyncdispatch, os, options, nativesockets, json, logging, strutils]

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
  result = parseResponse(parseJson(r))

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

  var sock = newAsyncSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  info("Connecting to the socket")
  waitFor(connectUnix(sock, sockPath))

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
