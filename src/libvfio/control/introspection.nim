#
# Copyright: 2666680 Ontario Inc.
# Reason: Introspection specific code.
#
import os
import osproc
import posix
import strformat
import logging

import ../types

func getIntrospections*(cfg: Config, uuid: string,
                        install: bool = false): seq[string] =
  ## getIntrospections - Gets a list of introspection devices.
  ##
  ## Inputs
  ## @cfg - Configuration file to use.
  ## @uuid - UUID to use.
  ## @install - If we are installing there are no introspection tools we can use.
  ##
  ## Returns
  ## result - A list of devices that can be used for introspection.
  if not install:
    case cfg.introspect
    of isLookingGlass:
      result = @["/dev/shm/kvmfr-" & uuid, "/dev/shm/kvmsr-" & uuid]
    else: discard

proc lookingGlassIntrospect(lgKey: int, spicePort: int, introspections: seq[string], uuid: string) =
  ## lookingGlassIntrospect - Introspection using looking glass.
  ##
  ## Inputs
  ## @introspections - Devices we can run introspections on.
  ## @uuid - UUID Name for this introspection.
  ##
  ## Side effect - Spawns up a looking glass introspection window.

  # Linux key scancodes as their names, required for title bar
  let scanCodes: array[250,string] = ["RESERVED","ESC","1","2","3","4","5","6","7","8","9","0","MINUS","EQUAL","BACKSPACE","TAB","Q","W","E","R","T","Y","U","I","O","P","LEFTBRACE","RIGHTBRACE","ENTER","LEFTCTRL","A","S","D","F","G","H","J","K","L","SEMICOLON","APOSTROPHE","GRAVE","LEFTSHIFT","BACKSLASH","Z","X","C","V","B","N","M","COMMA","DOT","SLASH","RIGHTSHIFT","KPASTERISK","LEFTALT","SPACE","CAPSLOCK","F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","NUMLOCK","SCROLLLOCK","KP7","KP8","KP9","KPMINUS","KP4","KP5","KP6","KPPLUS","KP1","KP2","KP3","KP0","KPDOT","blank","ZENKAKUHANKAKU","102ND","F11","F12","RO","KATAKANA","HIRAGANA","HENKAN","KATAKANAHIRAGANA","MUHENKAN","KPJPCOMMA","KPENTER","RIGHTCTRL","KPSLASH","SYSRQ","RIGHTALT","LINEFEED","HOME","UP","PAGEUP","LEFT","RIGHT","END","DOWN","PAGEDOWN","INSERT","DELETE","MACRO","MUTE","VOLUMEDOWN","VOLUMEUP","POWER","KPEQUAL","KPPLUSMINUS","PAUSE","SCALE","","KPCOMMA","HANGEUL","HANJA","YEN","LEFTMETA","RIGHTMETA","COMPOSE","STOP","AGAIN","PROPS","UNDO","FRONT","COPY","OPEN","PASTE","FIND","CUT","HELP","MENU","CALC","SETUP","SLEEP","WAKEUP","FILE","SENDFILE","DELETEFILE","XFER","PROG1","PROG2","WWW","MSDOS","COFFEE","ROTATE_DISPLAY","CYCLEWINDOWS","MAIL","BOOKMARKS","COMPUTER","BACK","FORWARD","CLOSECD","EJECTCD","EJECTCLOSECD","NEXTSONG","PLAYPAUSE","PREVIOUSSONG","STOPCD","RECORD","REWIND","PHONE","ISO","CONFIG","HOMEPAGE","REFRESH","EXIT","MOVE","EDIT","SCROLLUP","SCROLLDOWN","KPLEFTPAREN","KPRIGHTPAREN","NEW","REDO","F13","F14","F15","F16","F17","F18","F19","F20","F21","F22","F23","F24","unknown","unknown","unknown","unknown","unknown","PLAYCD","PAUSECD","PROG3","PROG4","ALL_APPLICATIONS","SUSPEND","CLOSE","PLAY","FASTFORWARD","BASSBOOST","PRINT","HP","CAMERA","SOUND","QUESTION","EMAIL","CHAT","SEARCH","CONNECT","FINANCE","SPORT","SHOP","ALTERASE","CANCEL","BRIGHTNESSDOWN","BRIGHTNESSUP","MEDIA","SWITCHVIDEOMODE","KBDILLUMTOGGLE","KBDILLUMDOWN","KBDILLUMUP","SEND","REPLY","FORWARDMAIL","SAVE","DOCUMENTS","BATTERY","BLUETOOTH","WLAN","UWB","UNKNOWN","VIDEO_NEXT","VIDEO_PREV","BRIGHTNESS_CYCLE","BRIGHTNESS_AUTO","DISPLAY_OFF","WWAN","RFKILL","MICMUTE"]
  
  let
    lookingGlassArgs = Args(
      exec: "/usr/local/bin/looking-glass-client",
 args: @[
        "-f", introspections[0], "-a", "yes", "egl:scale", "1", "-m", $lgKey, "-p", $spicePort,
        "input:rawMouse", "yes", "input:captureOnly", "yes", "spice:captureOnStart", "yes",
        "win:title=" & "Looking Glass + LibVF.IO (" & scanCodes[lgKey] & " toggles input, Hold for menu) UUID: " & uuid
      ]
    )
    screamArgs = Args(
      exec: "/usr/local/bin/scream",
      args: @[
        "-m", introspections[1]
      ]
    )


  # Fork to spawn up the introspection client.
  let forkRet = fork()
  if forkRet > 0:
    return
  elif forkRet < 0:
    error("Could not fork for introspection process")
    return

  # Spawn up looking glass
  var
    lookingGlassPid = startProcess(
      lookingGlassArgs.exec,
      args=lookingGlassArgs.args,
      options={poEchoCmd, poParentStreams}
    )
    screamPid = startProcess(
      screamArgs.exec,
      args=screamArgs.args,
      options={poEchoCmd, poParentStreams}
    )

  # This allows us to potentially expend this introspection.
  discard waitForExit(lookingGlassPid)
  terminate(screamPid)
  quit(0)

proc realIntrospect*(cfg: Config, intro: IntrospectEnum, introspections: seq[string],
                     uuid: string) =
  ## introspectVm - Starts an introspection script for the VM.
  ##
  ## Inputs
  ## @cfg - Config type.
  ## @intro - Introspection type.
  ## @introspections - List of introspection devices.
  ## @uuid - UUID for the name of the introspection.
  ##
  ## Side effects - Opens all introspection devices.
  case intro
  of isLookingGlass:
    lookingGlassIntrospect(cfg.lgKey, cfg.spicePort, introspections, uuid)
  else: discard

proc introspectVm*(cfg: Config, uuid: string) =
  ## introspectVm - Starts an introspection script for the VM.
  ##
  ## Inputs
  ## @cfg - Configuration file to use.
  ## @uuid - UUID of the VM to introspect.
  ##
  ## Side effects - Opens all introspection devices.
  let
    lockFile = cfg.root / "lock" / &"{uuid}.json"
    lock = getLockFile(lockFile)
    config = lock.config
  realIntrospect(cfg, config.introspect, getIntrospections(config, uuid), uuid)
