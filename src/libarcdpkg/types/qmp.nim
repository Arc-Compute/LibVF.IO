#
# Copyright: 2666680 Ontario Inc..
# Reason: Types and serialization for different QMP commands.
#
import sequtils
import strutils
import sugar
import json

type
  QmpCommand* = enum
    qcQueryCapabilities = "qmp_capabilities"

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
    major = getInt(j{"major"})
    minor = getInt(j{"minor"})
    micro = getInt(j{"micro"})
  return join(map([major, minor, micro], (x: int) => $x))
