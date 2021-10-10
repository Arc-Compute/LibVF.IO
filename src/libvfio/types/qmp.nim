#
# Copyright: 2666680 Ontario Inc.
# Reason: Types and serialization for different QMP commands.
#
import sequtils
import strutils
import sugar
import json

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

proc `%`*(cmd: QmpCommand): JsonNode = ## Overload for converting to JSON.
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
  result = QmpResponse(event: qrInvalid, errorMessage: "Not parsed")

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
