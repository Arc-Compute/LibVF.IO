#
# Copyright: 2666680 Ontario Inc..
# Reason: Provide function for ps
#
import os
import options
import times
import strformat
import strutils

import terminaltables

import ../types


type
  mLock = object  ## Wrapper for lock so it can contain path
    lock: Lock
    name: string
    path: string


proc getLocks(cfg: Config, uuid: string = ""): seq[mLock] =
  ## getLocks - Gets locks
  ## 
  ## Inputs
  ## @cfg: Config - Config object to get arcRoot
  ## @uuid: string - uuid to search for. Defaults to ""
  ## 
  ## Returns
  ## result - List of locks in a tuple with lockname
  ##  seq[mLock]
  ## 
  ## Side effects - reading files on system
  let pattern = cfg.root / "lock" / &"{uuid}*.json"

  for filePath in walkPattern(pattern):
    result &= mLock(
      lock: getLockFile(filePath),
      name: splitFile(filePath).name,
      path: filePath
    )

func separateVfios(lock: Lock): (seq[Vfio], seq[Vfio]) =
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

  for vfio in lock.vfios:
    if isGpu(vfio):
      gpus &= vfio
    elif isNet(vfio):
      nets &= vfio
  result = (gpus, nets)

func findPorts(ports: seq[Port], find: seq[int]): seq[Port] =
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

# Function to turn Port type into string
func `$`(x: Port): string = $x.guest & ":" & $x.host

# Function to turn sequence of Port into string
func `$`(x: seq[Port]): string =
  for port in x:
    result &= $port & ' '

type
  LockData = object  ## Object to contain information about lock
    lock: Lock
    uuid: string     ## UUID of the lock
    pid: int
    kernel: string
    states: seq[string]
    sockets: int
    cores: int
    threads: int
    ramAlloc: int
    gpus: seq[Vfio]
    nets: seq[Vfio]
    ports: seq[Port]
    date: string
    path: string

func newData(wl: mLock): LockData =
  result.lock = wl.lock
  result.uuid = wl.name[0 .. 35]
  result.pid = wl.lock.pidNum
  result.kernel = wl.lock.config.container.kernel
  result.states = wl.lock.config.container.state
  result.sockets = wl.lock.config.cpus.sockets
  result.cores = wl.lock.config.cpus.cores
  result.threads = wl.lock.config.cpus.threads
  result.ramAlloc = wl.lock.config.cpus.ramAlloc
  let (gpus, nets) = separateVfios(wl.lock)
  result.gpus = gpus
  result.nets = nets
  result.ports = wl.lock.config.connectivity.exposedPorts
  result.date = wl.name[37 .. 55]
  result.path = wl.path

func createPsTable(locks: seq[mLock]): string =
  ## createPsTable - Creates a table of running locks
  ## 
  ## Inputs
  ## @locks - sequence of mLocks
  ## 
  ## Returns
  ## result - string which contains the table
  func newRow(d: LockData): seq[string] =
    func fmtStates(states: seq[string]): string =
      if len(states) > 2:
        result &= join(states[0 .. 1], " ")
        result &= &" (+{len(d.states) - 2})"
      else:
        result = join(states, " ")
    func fmtPorts(ports: seq[Port]): string =
      let fPorts = findPorts(ports=ports, find = @[22, 5900])
      result &= $fPorts
      result &= &"(+{$(len(ports) - len(fPorts))})"

    result &= d.uuid                                    # 0: UUID
    result &= $d.pid                                    # 1: PID
    result &= d.kernel                                  # 2: Kernel
    result &= fmtStates(d.states)                       # 3: States
    result &= $len(d.gpus) / $len(d.nets)               # 4: GPUs/NETs
    result &= fmtPorts(d.ports)                         # 5: Ports
    result &= &"{$d.sockets}/{$d.cores}/{$d.threads}"   # 6: CPU
    result &= d.date                                    # 7: Creation date

  let
    headers = @[
      newCell("UUID", pad=1),
      newCell("PID", pad=1),
      newCell("Kernel", pad=1),
      newCell("States", pad=1),
      newCell("GPU/NET", pad=1),
      newCell("Ports", pad=1),
      newCell("S/C/T", pad=1),
      newCell("Creation date", pad=1)
    ]
  
  var tt = newTerminalTable()
  tt.setHeaders(headers)

  # Style
  tt.style = asciiStyle
  tt.separateRows = false

  # iterate lock files to create rows
  for lock in locks:
    let data = newData(lock)
    let row = newRow(data)
    tt.addRow(row)

  result = tt.render()

proc createTableStates(d: LockData): string =
  let headers = @[
    newCell("State", pad=1),
    newCell("Location", pad=1),
    newCell("Size (MiB)", pad=1)
  ]
  var tt = newTerminalTable()
  tt.setHeaders(headers)
  tt.style = asciiStyle
  tt.separateRows = false

  for state in d.states:
    let
      loc = d.lock.config.root / "states" / state
      size = float(getFileSize(loc)) / float(1_073_741_824)
    tt.addRow(@[state, loc, $size])
  result = tt.render()

func createTableGpus(d: LockData): string =
  let headers = @[
    newCell("Device Name", pad=1),
    newCell("VRAM", pad=1),
    newCell("Type", pad=1),
    newCell("Virtual Map", pad=1)
  ]
  var tt = newTerminalTable()
  tt.setHeaders(headers)
  tt.style = asciiStyle
  tt.separateRows = false

  for gpu in d.gpus:
    tt.addRow(@[$gpu.deviceName, $gpu.vRam, $gpu.gpuType, $gpu.virtNum])
  result = tt.render()

func createTableNets(d: LockData): string =
  let headers = @[
    newCell("Device Name", pad=1),
    newCell("MAC", pad=1)
  ]
  var tt = newTerminalTable()
  tt.setHeaders(headers)
  tt.style = asciiStyle
  tt.separateRows = false

  for net in d.nets:
    tt.addRow(@[$net.deviceName, net.mac])
  result = tt.render()

func createTablePorts(d: LockData): string =
  func generateHeaders(n: int): seq[Cell] =
    for i in 1 .. n:
      result &= @[
        newCell("Guest", pad=1),
        newCell("Host", pad=1)
      ]

  var tt = newTerminalTable()
  tt.style = asciiStyle
  tt.separateRows = false

  tt.setHeaders(generateHeaders(1))

  for p in d.ports:
    tt.addRow(@[$p.guest, $p.host])

  result = tt.render()

proc summaryPs(d: LockData): string =
  result &= &"Lock path: {d.path}\l"
  result &= &"UUID: {d.uuid}\l"
  result &= &"PID: {d.pid}\l"
  result &= &"Kernel: {d.kernel}\l\l"
  result &= "CPU Configuration\l"
  result &= &"  Sockets: {d.sockets}\l"
  result &= &"  Cores: {d.cores}\l"
  result &= &"  Threads: {d.threads}\l"
  result &= &"  Allocated RAM: {d.ramAlloc} MiB\l\l"

  if len(d.states) != 0:
    result &= createTableStates(d)

  if len(d.gpus) != 0:
    result &= createTableGpus(d)
  
  if len(d.nets) != 0:
    result &= createTableNets(d)
  
  if len(d.ports) != 0:
    result &= createTablePorts(d)

type
  psEnum* = enum
    peAll, peUuid, pePid

proc arcPs*(cfg: Config, pe: psEnum) =
  ## arcPs - Gives ps functionality
  ## 
  ## Inputs
  ## @cfg - Config object to find arcRoot and locks
  ## @pe - psEnum, function of ps to use
  ## 
  ## Side effects -
  ##  Reading files (Lock)
  ##  Outputting to stdout
  proc psAll(cfg: Config) =
    let locks = getLocks(cfg)
    if len(locks) == 0:
      echo "There are no sessions currently active."
    else:
      echo createPsTable(locks)
  proc psUuid(cfg: Config, uuid: string) =
    let locks = getLocks(cfg, uuid)
    if len(locks) == 0:
      echo "There are no sessions currently active."
    elif len(locks) == 1:
      let lock = newData(locks[0])
      echo summaryPs(lock)
    else:
      echo createPsTable(locks)

  case pe
  of peAll:
    psAll(cfg)
  of peUuid:
    psUuid(cfg, uuid="")
  of pePid:
    discard


when isMainModule:
  import random
  import times
  randomize()

  proc createRandomLock: mLock =
    proc createRandomPorts: seq[Port] =
      for _ in 1 .. rand(2 .. 50):
        result &= Port(
          guest: rand(1..65535),
          host: rand(1..65535)
        )
  
    result.lock.config = Config(
      root: "/opt/arc",
      cpus: Cpu(
        sockets: rand(1 .. 24),
        cores: rand(1 .. 24),
        threads: rand(1 .. 24),
        ramAlloc: rand(256 .. 16384)
      ),
      container: ArcContainer(
        kernel: "ubuntu-20.04",
        state: @["state-1.qcow2", "state-2.qcow2", "state-3.qcow2", "state-4.qcow2"]
      ),
      connectivity: Connectivity(
        exposedPorts: createRandomPorts()
      )
    )
    result.lock.config.connectivity.exposedPorts &= Port(guest: 22, host: rand(1 .. 65535))
    result.lock.vfios = @[]
    result.lock.pidNum = rand(1 .. 32768)
    result.name = &"{getUUID()}-{now()}"

  var locks: seq[mLock]
  for _ in 0 .. 10:
    locks &= createRandomLock()

  echo "\l\lDemo of ps\l"
  let t = createPsTable(locks)
  echo t

  echo "\l\lDemo of ps --uuid= or --hash"
  var l = newData(locks[0])
  l.path = &"/opt/arc/locks/{getUUID()}-{now()}.json"
  echo summaryPs(l)
