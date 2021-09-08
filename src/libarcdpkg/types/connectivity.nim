#
# Copyright: 2666680 Ontario Inc..
# Reason: File for connectivity into the system.
#
type
  Port* = object              ## Port to expose to the host from the guest.
    guest*: int              ## Guest port number.
    host*: int               ## Host port number.

  Connectivity* = object     ## Connectivity setup.
    exposedPorts*: seq[Port] ## List of exposed ports on the VM.
