#
# Copyright: 2666680 Ontario Inc.
# Reason: Helper structures for passing arguments.
#
type
  Args* = object         ## Argument structure for startProcess.
    exec*: string        ## Executable command.
    args*: seq[string]   ## Arguments to that command

  QemuArgs* = object     ## Additional Qemu commands to pass into the system.
    arg*: string         ## Additional Qemu argument
    values*: seq[string] ## Additioanl arguments to pass in.

  CommandList* = object  ## Object wrapping a command list for execution.
    is_root*: bool       ## If we need to run the command list as a root user.
    list*: seq[Args]     ## List of commands to run.
