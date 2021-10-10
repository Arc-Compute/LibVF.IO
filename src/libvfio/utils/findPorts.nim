#
# Copyright: 2666680 Ontario Inc.
# Reason: Provide function for finding ports in a sequence of Port
#
import ../types

func findPorts*(ports: seq[Port], find: seq[int]): seq[Port] =
  ## findPorts - Matches port forwards in given sequence
  ## 
  ## Inputs
  ## @ports - sequence of ports seq[Port] to be searched through
  ## @find - sequence of ports seq[int] to be found
  ## 
  ## Returns
  ## result - sequence of [Port] that were matched
  for port in ports:
    if port.guest in find:
      result &= port
