
# overview

recently had to redeploy my gitops k3s homelab due to a network migration and not wanting to manually renew tls certs, i just manually reprovisioned the VMs/k3s and then pointed flux to it. That of course worked beautifully, except that I was left wanting more out of my lab. 

To quote Kelsey Hightower I had "left room for greatness" so to speak, now it was time to capitalize on that room made and make something that I've been working on for a while now; Great(er). 

TL;DR I'm going to automate the provisioning of my VMs and k3s, and the hand off to Flux; accomplished using a combo of Terraform, Packer, and Cloud-Init. These tools will enable be me automate the deployment of my gitops-production-homelab on any hardware running Proxmox. In theory it should be just one command, but we'll see how this goes.

My mental model: 
```
jumpbox (10.10.10.x, Debian 13 headless)
 ├─ terraform, packer, kubectl, kubectx, flux, age key, GITHUB_TOKEN env
 │
 ├─ [1] packer build  ──SSH──> temp build-VM on Proxmox ──> becomes template
 │
 ├─ [2] terraform apply ──API──> Proxmox clones template ×2 (staging/prod)
 │        cloud-init on each new VM: hostname, ssh key, swapoff, install k3s ONLY
 │
 └─ [3] terraform's local-exec (still running ON the jumpbox, as you):
          scp kubeconfig off the new node → point it at node's real IP
          flux bootstrap github  (uses your jumpbox's GITHUB_TOKEN, never the VM's)
          kubectl create secret sops-age  (uses your jumpbox's age key, never the VM's)
```

ensure packer and terraform are installed on the system you are working from and that packer and terraform have a secure way of talking to the ProxmoxAPI i.e. a proxmox api token

---
#### Oldies but Still Goodies DevOps

I see a lot of fellow homelabbers who use Ansible and custom shell scripts to redeploy and manage infra/config. This is awesome, however it is the old way of doing things and while I see the appeal I purposely do not use Ansible because of this. I will however always use BASH in my workflow, its just too powerful, but w/Flux and K-Native tools I see no need to implement Ansible in the lab. 

I did get an idea from someone; using Ansible for "Day 2" ops e.g. adding a user to sudo, installing docker-compose, or custom builds. This could be good practice to keep me grounded in the fundies, as well as broadening my devops skills to include what would be considered "Traditional" devops.

---
# Packer - Golden Image

navigate to the packer directory of your project and enter the following commands:

```bash
packer init .

packer validate -var-file=variables.pkrvars.hcl debian13-k3s.pkr.hcl

packer build -on-error=ask -var-file=variables.pkrvars.hcl debian13-k3s.pkr.hcl
```

Zettel Notes:
```
after running validate i got a lot depracation warnings,and a checksum missing warning. it still validated tho - ultimately tho it needed to be addressed because it was causing bugs.

I also needed to tweak the `provision.sh` script because some packages were named incorrectly, and thats about it.

the template is successfull, but can not be manually cloned since it is locked down. I hope this will not mess w/Terraform but we'll find out tomorrow.

more to come.

```

