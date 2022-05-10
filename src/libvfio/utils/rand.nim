#
# Copyright: 2666680 Ontario Inc.
# Reason: Provide functions for proper randomized numbers
#

import std/random

proc randNum*(limit = high(uint64)): uint64 =
  ## randNum - Thread safe generate random number
  ##
  ## Inputs
  ## @limit - The max value of the returned random integer
  ##
  ##Side effects - Opens and reads from file

  # Take bytes from file
  let frand: File = open("/dev/urandom", fmRead)
  var randomBits: array[8, uint8]
  discard readBytes(frand, randomBits, 0, 8)
  close(frand)
  var seed: int64 = 0
  for i in randomBits:
    seed = (seed shl 8) or int64(i)

  # Use random bytes as seed for random number
  var r = initRand(seed)
  result = uint64(r.rand(1.0) * float64(limit))
