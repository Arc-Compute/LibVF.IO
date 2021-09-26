# LibVFIO

This is a project designed to serve as a replacement to
libvirt, with a focus on GPU/Compute device multitenancy.

# Documentation

Here are some key components to the documentation that we
currently have:

1. [Deploy](docs/deployment.md)
2. [Using](docs/using.md)
3. [Undeploy](docs/undeployment.md)
4. [Example](docs/example.md)

# Release Features

1. AMDGPU mediated device support
2. Nvidia mediated device support
3. YAML Configuration files
4. Create VM
5. Start VM
6. Stop VM
7. List available kernels
8. List available states
9. List running kernels
10. Deploy script
11. Undeploy script

# Future Features

1. Intel GVT-g support
2. Snapshot features + Block diff copy
3. Hotplugging functionality

# License

Copyright (C) 2021 2666680 Ontario Inc.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
