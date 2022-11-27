## Intro
- Support `Debian`/`Ubuntu`/`NixOS`[x86_64/aarch64]. For other distros, install `wget` `kexec-tools` manually
- Require script to be run as root or sudo
- Ensure `/home/$SUDO_USER/.ssh/authorized_keys` or `/root/.ssh/authorized_keys` or `/etc/ssh/authorized_keys.d/root` contains your public SSH key.
## Usage
#### kexec NixOS
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-$(uname -m)-linux | bash -s
```


#### kexec NixOS and run script automatically (optional)
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-$(uname -m)-linux | bash -s script_url=AUTORUN_SCRIPT_URL
```


#### add 1~4 script arguments (optional)
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-$(uname -m)-linux | bash -s script_url=AUTORUN_SCRIPT_URL  script_arg1=SCRIPT_ARG1 script_arg2=SCRIPT_ARG2 script_arg3=SCRIPT_ARG3 script_arg4=SCRIPT_ARG4
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