#
# Copyright: 2666680 Ontario Inc.
# Reason: Sets up logging on the system.
#
import logging

# Allows us to export the logging to prevent a secondary logging import
export logging

const
  FmtStr = "[$date $time] - $levelname: " ## Format for strings
  LogLvl = lvlAll                         ## How verbose logging is necessary

proc initLogger*(fileName: string, console: bool) =
  ## initLogger - Initializes a logger and logging callbacks.
  ##
  ## Inputs
  ## @fileName - Name of the rolling log to initialize.
  ## @console - Do we also write the log to the screen?
  ##
  ## Side effects - If console is enabled, it prints to STDOUT.
  ##                Either way it prints to a rolling log file of the name:
  ##                fileName.
  if console:
    var consoleLogger = newConsoleLogger(
      levelThreshold = LogLvl,
      fmtStr = FmtStr,
      useStderr = true
    )
    addHandler(consoleLogger)
  var rollingLogger = newRollingFileLogger(
    fileName,
    levelThreshold = LogLvl,
    fmtStr = FmtStr
  )
  addHandler(rollingLogger)
