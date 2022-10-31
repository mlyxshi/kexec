## Usage
- Support Debian/Ubuntu. For other distros, install `wget` `kexec-tools` manually
- Use your own sshkey

#### openssh
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot | bash -s sshkey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpaY3LyCW4HHqbp4SA4tnA+1Bkgwrtro2s/DEsBcPDe"
```

#### run script (optional)
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot | bash -s sshkey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpaY3LyCW4HHqbp4SA4tnA+1Bkgwrtro2s/DEsBcPDe" script_url=AUTORUN_SCRIPT_URL
```

#### add 1~3 script arguments (optional)
```
curl -sL https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot | bash -s sshkey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpaY3LyCW4HHqbp4SA4tnA+1Bkgwrtro2s/DEsBcPDe" script_url=AUTORUN_SCRIPT_URL  script_arg1=SCRIPT_ARG1 script_arg2=SCRIPT_ARG2 script_arg3=SCRIPT_ARG3
```
