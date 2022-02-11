#
# Copyright: 2666680 Ontario Inc.
# Reason: File with different installation codes.
#
import std/logging
import std/os
import std/osproc
import std/rdstdin
import std/strformat
import std/sequtils
import std/strutils
import std/sugar
import std/json
import std/md5

import arguments
import root

import ../types

proc getpass(prompt: cstring) : cstring {.header: "<unistd.h>", importc: "getpass".}

proc getInstallationParams*(limePath: string, isoType: OsInstallEnum): Installation =
  ## getInstallationParams - Gets the installation parameters.
  ##
  ## Inputs
  ## @limePath - LIME Path for installations.
  ## @isoType - Type of installation.
  ##
  ## Returns
  ## result - Installation parameters to install a VM.
  ##
  ## Side Effects - Gets user inputs.
  result = Installation(os: isoType)
  result.username = readLineFromStdin("Enter your username for the vm: ")
  result.password = $getpass("Enter your password for the vm: ")
  result.limeInstall = limePath
  result.lang = readLineFromStdin("Enter your prefered language (en-US if you are unsure): ")

  while true:
    let availableSsh = toSeq(walkFiles(expandTilde("~/.ssh/*.pub")))

    for i, ssh in availableSsh:
      echo(&"{i}. {ssh}")

    try:
      let sshKey = parseInt(readLineFromStdin("Please pick the above SSH key to use: "))

      if sshKey >= 0 and sshKey < len(availableSsh):
        result.pathToSsh = availableSsh[sshKey]
        info(&"Selecting ssh key in: {result.pathToSsh}")
        break
    except:
      error("Invalid integer passed")

    error("Invalid choice, please try again.")

  case result.os
  of osWin10:
    result.productKey = strip(readLineFromStdin("Enter your windows key: "))
  else:
    discard

proc updateIso*(isoFile: string, installParams: Installation, isoType: OsInstallEnum, size: int,
                finalPath: string, mdevs: seq[Mdev], vfios: seq[Vfio], root: CommandMonad,
                uuid: string) =
  ## updateIso - Updates the ISO file to the modified version.
  ##
  ## Inputs
  ## @isoFile - ISO file to update.
  ## @installParams - Installation parameters.
  ## @isoType - How to modify the ISO.
  ## @size - Size of the VM.
  ## @finalPath - Final path to install the qcow image.
  ## @mdevs - Mdev devices to add.
  ## @vfios - Vfio devices to add.
  ## @root - Command monad to allow root elevation.
  ## @uuid - UUID to use (NECESSARY FOR NVIDIA 0X57).
  ##
  ## Side Effects - Modifies the ISO file.
  const
    buffer: string = staticRead("../../../templates/autounattend.xml")

  info("Getting MD5 sum of the executable file, may take a while")

  let
    currentPwd = getCurrentDir()
    autounattend = fmt(buffer)
    md5sum = split(execProcess(&"md5sum {isoFile}"))[0]
    floppy_files = @["autounattend.xml", installParams.pathToSsh]
    newIsoFile = if fileExists(isoFile): isoFile
                 else: currentPwd / isoFile
    qemuargs = @[
      @[ "-drive", "file=qemu-drives/{{ .Name }},format=qcow2,index=1" ],
      @[ "-drive", &"file={installParams.introspectionDir}.rom,media=cdrom,index=3" ],
      @[ "-uuid", uuid ],
      @[ "-machine", MachineConfig ],
      @[ "-cpu", CpuConfig ],
      @[ "-display", "gtk" ]
    ]
    jsonObject = %*{
      "builders": [
        {
          "vm_name": "temp.arc",
          "type": "qemu",
          "accelerator": "kvm",

          "cpus": 1,
          "memory": 4096,
          "disk_size": size * 1024,
          "net_device": "rtl8139",

          "iso_url": newIsoFile,
          "iso_checksum": md5sum,
          "iso_checksum_type": "md5",

          "floppy_files": floppy_files,

          "output_directory": "qemu-drives",
          "qemuargs": qemuargs,

          "communicator": "winrm",
          "winrm_username": installParams.username,
          "winrm_password": installParams.password,
          "winrm_use_ssl": "true",
          "winrm_insecure": "true",
          "winrm_timeout": "1h",

          "shutdown_command": "echo hi",
          "shutdown_timeout": "60m"
        }
      ]
    }

  info(qemuargs)
  info("Setting root: ", setRoot(root, true))
  setCurrentDir(installParams.limeInstall)

  writeFile("autounattend.xml", autounattend)
  writeFile("build.json", $jsonObject)

  discard execShellCmd("packer build build.json")

  moveFile("qemu-drives/temp.arc", finalPath)

  setCurrentDir(currentPwd)
  info("Removing root: ", setRoot(root, false))
