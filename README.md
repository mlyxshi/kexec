## Usage
- Support Debian/Ubuntu. For other distros, install `wget` `kexec-tools` manually
- Require script to be run as root(sudo)
- Check whether or not `/home/$SUDO_USER/.ssh/authorized_keys` contains your public SSH key, it will be the sshd authorizedKeys of NixOS. If `/home/$SUDO_USER/.ssh/authorized_keys` is empty, write your public SSH key to it.

#### kexec NixOS
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot | bash -s
```

#### run script (optional)
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot | bash -s script_url=AUTORUN_SCRIPT_URL
```

#### add 1~3 script arguments (optional)
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot | bash -s script_url=AUTORUN_SCRIPT_URL  script_arg1=SCRIPT_ARG1 script_arg2=SCRIPT_ARG2 script_arg3=SCRIPT_ARG3
```
