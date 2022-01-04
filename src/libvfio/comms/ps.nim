#
# Copyright: 2666680 Ontario Inc.
# Reason: Provide function for ps
#
import os
import options
import strformat
import strutils

import terminaltables

import ../types
import ../utils/getLocks
import ../utils/separateVfios
import ../utils/findPorts

const
  textNoActiveSessions = "There are no sessions currently active."

type
  LockData = object     ## Object to contain information about lock
    lock: Lock          ## Copy of the original lock
    uuid: string        ## UUID
    pid: int            ## PID
    kernel: string      ## Kernel
    states: seq[string] ## States
    sockets: int        ## CPU Sockets
    cores: int          ## CPU Cores
    threads: int        ## CPU Threads
    ramAlloc: int       ## RAM Allocation
    gpus: seq[Vfio]     ## GPU VFIOs
    nets: seq[Vfio]     ## NET VFIOs
    ports: seq[Port]    ## Port forwards
    path: string        ## Lock path


func newData(wl: wLock): LockData =
  ## newData - Creates an object based on the lock
  ## 
  ## Inputs
  ## @wl - wLock wrapped form of lock
  ## 
  ## Returns
  ## result - LockData object
  let fn = splitFile(wl.path).name
  result.lock = wl.lock
  result.uuid = fn[0 .. 35]
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
  result.path = wl.path

func newTable(headers: seq[Cell]): TerminalTable =
  ## newTable - Creates a custom styled TerminalTable
  ## 
  ## Inputs
  ## @headers - Column headers
  ## 
  ## Returns
  ## result - Stylized TerminalTable
  ## 
  # TODO: Should be a Template or Macro?
  result = newTerminalTable()
  result.setHeaders(headers)
  result.style = asciiStyle
  result.separateRows = false

func overviewPs(locks: seq[wLock]): string =
  ## createPsTable - Creates a table for arc ps
  ## 
  ## Inputs
  ## @locks - sequence of wLock
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
    result &= &"{d.ramAlloc} MiB"                       # 7: Memory allocation

  let
    headers = @[
      newCell("UUID", pad=1),
      newCell("PID", pad=1),
      newCell("Kernel", pad=1),
      newCell("States", pad=1),
      newCell("GPU/NET", pad=1),
      newCell("Ports", pad=1),
      newCell("S/C/T", pad=1),
      newCell("RAM Alloc", pad=1),
    ]
  
  var tt = newTable(headers)

  # iterate lock files to create rows
  for lock in locks:
    let data = newData(lock)
    let row = newRow(data)
    tt.addRow(row)

  result = tt.render()

proc createTableStates(d: LockData): string =
  ## createTableStates - Creates a table of States
  ## 
  ## Input
  ## d - LockData
  ## 
  ## Returns
  ## result - string containg table
  let headers = @[
    newCell("State", pad=1),
    newCell("Location", pad=1),
    newCell("Size (MiB)", pad=1)
  ]
  var tt = newTable(headers)

  for state in d.states:
    let
      loc = d.lock.config.root / "states" / state
      size = float(getFileSize(loc)) / float(1_073_741_824) # POTENTIAL ROUNDING ERROR, CHANGE TO INTS
    tt.addRow(@[state, loc, $size])

  result = tt.render()

func createTableGpus(d: LockData): string =
  ## createTableGpus - Creates a table of VFIO GPU devices
  ## 
  ## Input
  ## @d - LockData
  ## 
  ## Returns
  ## result - string containing table
  let headers = @[
    newCell("Device Name", pad=1),
    newCell("VRAM", pad=1),
    newCell("Type", pad=1),
    newCell("Virtual Map", pad=1)
  ]
  var tt = newTable(headers)

  for gpu in d.gpus:
    tt.addRow(@[$gpu.deviceName, $gpu.vRam, $gpu.gpuType, $gpu.virtNum])

  result = tt.render()

func createTableNets(d: LockData): string =
  ## createTableNets - Creates a table of VFIO network devices
  ## 
  ## Input
  ## @d - LockData
  ## 
  ## Returns
  ## result - string containing table
  let headers = @[
    newCell("Device Name", pad=1),
    newCell("MAC", pad=1)
  ]
  var tt = newTable(headers)

  for net in d.nets:
    tt.addRow(@[$net.deviceName, net.mac])

  result = tt.render()

func createTablePorts(d: LockData): string =
  ## createTablePorts - Creates a table of port forwards
  ## 
  ## Input
  ## @d - LockData
  ## 
  ## Returns
  ## result - string containing table
  func generateHeaders(n: int): seq[Cell] =
    for i in 1 .. n:
      result &= @[
        newCell("Guest", pad=1),
        newCell("Host", pad=1)
      ]

  let headers = generateHeaders(1)
  var tt = newTable(headers)

  for p in d.ports:
    tt.addRow(@[$p.guest, $p.host])

  result = tt.render()

proc detailedPs(d: LockData): string =
  ## detailedPs - Gives more data about VM
  ## 
  ## Input
  ## @d - LockData
  ## 
  ## Returns
  ## result - string containing table
  ## 
  ## Side effects - related to getting file info
  result &= &"Lock path: {d.path}\l"
  result &= &"UUID: {d.uuid}\l"
  result &= &"PID: {d.pid}\l"
  result &= &"Kernel: {d.kernel}\l\l"
  result &= &"Sockets: {d.sockets} Cores: {d.cores} Threads: {d.threads}\l"
  result &= &"Allocated RAM: {d.ramAlloc} MiB\l\l"

  if len(d.states) != 0:
    result &= createTableStates(d)

  if len(d.gpus) != 0:
    result &= createTableGpus(d)
  
  if len(d.nets) != 0:
    result &= createTableNets(d)
  
  if len(d.ports) != 0:
    result &= createTablePorts(d)


proc arcPs*(cfg: Config, cmd: CommandLineArguments) =
  ## arcPs - Gives ps functionality
  ## 
  ## Inputs
  ## @cfg - Config object to find arcRoot and locks
  ## @cmd - arguments (search)
  ## 
  ## Side effects -
  ##  Reading files (Lock)
  ##  Outputting to stdout
  proc psOverview(cfg: Config) =
    let locks = getLocks(cfg)
    if len(locks) == 0:
      echo textNoActiveSessions
    else:
      echo overviewPs(locks)
  proc psA(cfg: Config, locks: seq[wLock]) =
    if len(locks) == 0:
      echo textNoActiveSessions
    elif len(locks) == 1:
      let lock = newData(locks[0])
      echo detailedPs(lock)
    else:
      echo overviewPs(locks)
  proc psUuid(cfg: Config, uuid: string) =
    let locks = findLocksByUuid(cfg, uuid)
    psA(cfg, locks)

  if isSome(cmd.search):
    let search = get(cmd.search)
    psUuid(cfg, search)
  else:
    psOverview(cfg)
