#
# Copyright: 2666680 Ontario Inc..
# Reason: Helper structures for passing arguments.
#
type
  Args* = object       ## Argument structure for startProcess.
    exec*: string      ## Executable command.
    args*: seq[string] ## Arguments to that command
