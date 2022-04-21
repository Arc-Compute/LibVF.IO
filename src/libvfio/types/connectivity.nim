#
# Copyright: 2666680 Ontario Inc.
# Reason: File for connectivity into the system.
#
import yaml

type
  Protocol* = enum
    pTCP = "tcp", pUDP = "udp"

  Port* = object             ## Port to expose to the host from the guest.
    guest*: int              ## Guest port number.
    host*: int               ## Host port number.
    protocol* {.defaultVal: Protocol.pTCP.}: Protocol
                             ## Protocol of exposed port

  Connectivity* = object     ## Connectivity setup.
    exposedPorts*: seq[Port] ## List of exposed ports on the VM.

