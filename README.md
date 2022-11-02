## Usage
- Support `Debian`/`Ubuntu`/`NixOS`. For other distros, install `wget` `kexec-tools` manually
- Require script to be run as root or sudo
- Ensure `/home/$SUDO_USER/.ssh/authorized_keys` or `/root/.ssh/authorized_keys` or `/etc/ssh/authorized_keys.d/root` contains your public SSH key.
#### kexec NixOS
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot-x86_64-linux | bash -s
```
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot-aarch64-linux | bash -s
```

#### run script (optional)
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot-x86_64-linux | bash -s script_url=AUTORUN_SCRIPT_URL
```
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot-aarch64-linux | bash -s script_url=AUTORUN_SCRIPT_URL
```

#### add 1~3 script arguments (optional)
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot-x86_64-linux | bash -s script_url=AUTORUN_SCRIPT_URL  script_arg1=SCRIPT_ARG1 script_arg2=SCRIPT_ARG2 script_arg3=SCRIPT_ARG3
```
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot-aarch64-linux | bash -s script_url=AUTORUN_SCRIPT_URL  script_arg1=SCRIPT_ARG1 script_arg2=SCRIPT_ARG2 script_arg3=SCRIPT_ARG3
```
