#
# Copyright: 2666680 Ontario Inc.
# Reason: Provide function to separate vfios
#
import ../types

func separateVfios*(lock: Lock): (seq[Vfio], seq[Vfio]) =
  ## separateVfios - Separates vfios into net and gpu vfios
  ## 
  ## Inputs
  ## @lock - Lock object to get vfios
  ## 
  ## Returns
  ## result - tuple containing two sequences
  ##  ([gpuVfios], [netVfios])
  var
    gpus: seq[Vfio]
    nets: seq[Vfio]

  for vfio in lock.vm.vfios:
    if isGpu(vfio):
      gpus &= vfio
    elif isNet(vfio):
      nets &= vfio
  result = (gpus, nets)
