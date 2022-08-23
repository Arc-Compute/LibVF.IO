#
# Copyright: 2666680 Ontario Inc.
# Reason: Types and serialization for different QMP commands.
#
import sequtils
import strutils
import strformat
import sugar
import json
import asyncnet
import asyncdispatch
import os
import options
import nativesockets
import logging

type
  QmpCommandEnum* = enum                      ## Enumeration for QMP Commands.
    qcQueryCapabilities = "qmp_capabilities", ## Query the capabilities.
    qcShutdown = "system_powerdown",          ## Issues a shutdown command.
    qcSendKey = "send-key"                    ## Sends a key to QMP.

  QmpResponseEnum* = enum                     ## Different response from QMP.
    qrInvalid = "INVALID",                    ## Not a real response.
    qrSuccess = "return",                     ## Last command sent was
                                              ##  success.
    qrError = "error",                        ## Error response
    qrPowerDown = "POWERDOWN",                ## A powerdown request.
    qrShutDown = "SHUTDOWN",                  ## A shutdown event.
    qrDevTrayMove = "DEVICE_TRAY_MOVED"       ## Device tray moved event.

  QmpCommand* = object                        ## Command structure for QMP.
    case command*: QmpCommandEnum             ## Command type for QMP.
    of qcSendKey:
      keys*: seq[string]                      ## We only implemented send-key.
    else: nil

  QmpResponse* = object                       ## Event response.
    case event*: QmpResponseEnum
    of qrInvalid, qrError:
      errorMessage*: string                   ## Error message on failure.
    else: discard

proc `%`*(cmd: QmpCommand): JsonNode =        ## Overload for converting to JSON.
  func addQCode(x: string): JsonNode =
    %*{"type": "qcode", "data": x}

  result = %*{"execute": $cmd.command}
  case cmd.command
  of qcSendKey:
    result["arguments"] = %*{
      "keys": map(cmd.keys, addQCode)
    }
  else: discard

func parseResponse*(node: JsonNode): QmpResponse =
  ## parseEvent - Converts a response to a QMP Event.
  ##
  ## Inputs
  ## @response - Response to convert.
  ##
  ## Returns
  ## result - Resulting response.
  result = QmpResponse(event: qrInvalid, errorMessage: &"Not parsed: {$node}")

  if "return" in node:
    result = QmpResponse(event: qrSuccess)
  elif "error" in node:
    result = QmpResponse(event: qrError, errorMessage: $node["error"])
  elif "event" in node:
    let event = parseEnum[QmpResponseEnum](getStr(node["event"]), qrInvalid)
    result = QmpResponse(event: event)
    case event
    of qrInvalid:
      result.errorMessage = "Not applicable"
    else: discard

func extractVersion*(j: JsonNode): string =
  ## extractVersion - Extracts the QEMU version from the QMP Socket.
  ##
  ## Inputs
  ## @j - Json node that was sent to the system.
  ##
  ## Returns
  ## result - String consisting of "{major}.{minor}.{micro}".
  let
    qemuVersion = j{"QMP", "version", "qemu"}
    major = getInt(qemuVersion{"major"})
    minor = getInt(qemuVersion{"minor"})
    micro = getInt(qemuVersion{"micro"})
  return join(map([major, minor, micro], (x: int) => $x), ".")

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

  var sock = newAsyncSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  info("Connecting to the socket")

  ## Try to connect to socket until timeout
  let limit = 40
  for i in countup(0, limit):
    try:
      waitFor(connectUnix(sock, sockPath))
      break
    except:
      sleep(375)
      debug("Issue with socket. Retrying")
      if i == limit:
        warn("Issue with creating socket. Abort.")
        return

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
