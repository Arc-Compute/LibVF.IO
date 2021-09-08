#
# Copyright: 2666680 Ontario Inc..
# Reason: Environment specific values.
#
import options

type
  ArcContainer* = object  ## Container for an Arc Kernel.
    kernel*: string       ## The kernel name.
    state*: seq[string]   ## Additional state drives.
    initialSize*: int     ## Initial size of the kernel, in GBs.
    iso*: Option[string]  ## ISO file if we are creating a new file.
                          ## NOTE: Apps are removed for the moment, they
                          ##       will come into the system a bit later.
