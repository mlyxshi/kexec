## Intro
- Require script to be run as root or sudo
- Ensure `/home/$SUDO_USER/.ssh/authorized_keys` or `/root/.ssh/authorized_keys` or `/etc/ssh/authorized_keys.d/root` contains your public SSH key.
## Usage
#### kexec NixOS
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-$(uname -m) | bash -s
```


#### kexec NixOS and run script automatically (optional)
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-$(uname -m) | bash -s AUTORUN_SCRIPT_URL
```


#### add script arguments (optional)
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-$(uname -m) | bash -s AUTORUN_SCRIPT_URL ARG1 ARG2 ...
```


## Disclaimer
Only test on
- Azure 
  - B1s 
    - Debian/Ubuntu/NixOS x86_64
- Oracle
  - Ampere A1
    - Debian/Ubuntu/NixOS aarch64 
  - E2.1.Micro
    - Debian/Ubuntu/NixOS x86_64