## Intro
- Support `Debian`/`Ubuntu`/`NixOS`. For other distros, install `wget` `kexec-tools` manually
- Require script to be run as root or sudo
- Ensure `/home/$SUDO_USER/.ssh/authorized_keys` or `/root/.ssh/authorized_keys` or `/etc/ssh/authorized_keys.d/root` contains your public SSH key.
## Usage
#### kexec NixOS
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-x86_64-linux | bash -s
```
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-aarch64-linux | bash -s
```

#### kexec NixOS and run script automatically (optional)
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-x86_64-linux | bash -s script_url=AUTORUN_SCRIPT_URL
```
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-aarch64-linux | bash -s script_url=AUTORUN_SCRIPT_URL
```

#### add 1~3 script arguments (optional)
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-x86_64-linux | bash -s script_url=AUTORUN_SCRIPT_URL  script_arg1=SCRIPT_ARG1 script_arg2=SCRIPT_ARG2 script_arg3=SCRIPT_ARG3
```
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-aarch64-linux | bash -s script_url=AUTORUN_SCRIPT_URL  script_arg1=SCRIPT_ARG1 script_arg2=SCRIPT_ARG2 script_arg3=SCRIPT_ARG3
```

## Disclaimer
Only test on
- Azure 
  - B1s 
    - Debian/Ubuntu x64
- Oracle
  - Ampere A1
    - Debian/Ubuntu/NixOS arm64 
  - E2.1.Micro
    - Debian/Ubuntu x64