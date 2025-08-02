# Bash Collections - by netopsys

![Lint](https://github.com/netopsys/netopsys-bash-collections/actions/workflows/lint.yml/badge.svg?style=flat-square&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square&logo=opensourceinitiative&logoColor=white)
![Version](https://img.shields.io/badge/version-0.20.0-blue.svg?style=flat-square&logoColor=white)

> A curated collection of clean, secure, and production-ready Bash scripts for sysadmins, DevOps, and power users.

## Contents

| Collections                 | Scripts                    | Description                                                            |
|-----------------------------|----------------------------|------------------------------------------------------------------------|
| *Mobile*                    | `devices-info.sh`          | Android device infos (adb)                                             | 
| *System*                    |                            |                                                                        |
| *Network*                   | `hosts-up.sh`              | Scanner Network Hosts up                                               |
| *Disk & Storage*            | `sizefiles-limit.sh`       | Checks for file size limits for a given extension in a directory       |
| *Packages & Services*       | `packages-info.sh`         | Packages infos (.deb)                                                  |
| *Security*                  | `usb-control.sh`           | Manage USB device access                                               |
|                             | `recon-enum.sh`            | Automatic reconnaissance phase on a network target                     |
| *Tools*                     | `shellcheck-control.sh`    | Check quality scripts bash                                             |
| _More scripts coming soon_  |                            |                                                                        |

## Requirements

- GNU/Linux (Debian, Ubuntu, etc.)
- `bash` (version 4 or higher)
- Relevant package dependencies (e.g., `usbguard` for USB control)

## Getting Started

```bash
git clone https://github.com/netopsys/netopsys-bash-collections.git
cd netopsys-bash-collections 
sudo ./wrapper.sh
```
## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](https://github.com/netopsys/netopsys-bash-collections/blob/main/CONTRIBUTING.md) for guidelines.

## Security

Please review our [SECURITY.md](https://github.com/netopsys/netopsys-bash-collections/blob/main/SECURITY.md) for reporting vulnerabilities and security policies.