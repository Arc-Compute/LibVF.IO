# Folder Structure

This document explains the folder structure that libvfio uses when
it is creating/working with kernels/states/applications.

```
$/path/to/root/   # In the configuration.
    - kernel/     # Where all kernel images are stored (base installs).
    - states/     # State images are stored here.
    - shells/     # Applications/configurations are stored here.
    - logs/       # Log directory.
      - arcd/     # Logging for arcd specifically.
      - qemu/     # QEMU specific logging files.
    - lock/       # Stores all the lock files on the system.
    - live/       # Live kernels that are currently running right now.
/tmp              # Temporary files which are removed.
    - locks/      # Current locks on the IOMMU group parsing.
      - $path/    # Path to the IOMMU device that is locked.
    - sockets/    # Socket directory to interact with different QEMU processes.
      - $uuid/    # Based on UUID.
```
