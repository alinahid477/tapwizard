# Merlin's tapwizard

<img src="images/logo.png" alt="Merlin-TAP" width=200 height=210/>

Merlin's TAP Wizard for is a bootstrapped docker instance that has
- Essential Tools (such as Kapp, Ytt, Kpack, yq, jq, Tanzu CLI etc) needed to TAP and Cartographer
- Many automations built in to achieve the below feature set

A wizard like UI (with automation) for 
- Tanzu Application Platform
    - Installing TAP using UI for the TAP profile to support the architecture described here: https://github.com/vmware-tanzu-labs/tanzu-validated-solutions/blob/main/src/reference-designs/tap-architecture-planning.md
    - UI interface to AppToolkit
- UI for configuring Cartographer
    - Interactive UI to Create Cartographer Templates for common scenarios such as 
        - GitPull (private repository)
        - Test (using Maven) and associated Tekton Task
        - Kpack image build
        - Grype Source and Image Scan, Trivy Image Scan (UI presents a choice to choose one) and associated seevral Tekton Tasks
        - GitOps CI (Knative Config and Git Writer) and associated Tekton Tasks
        - Deploy Deliverable - GitOps CD (GitPull from private GitOps Repo, Delivery template)
    - Interactive UI to Create Supply Chains using templates
    - The UI and automations behind it also takes care of creating and wiring of Cartographer Templates, SupplyChain and Tekton Task using RBAC, Secrets, and ServiceAccounts etc following best practice.
- UI for configuring Kpack
    - Interactive UI to Create Kpack Store, Stack and Builder
    - The UI and automations behind it also takes care of creating and wiring of using RBAC, ServiceAcconts and Secrets.
 

*(GUI coming soon)*

This docker will server interface for
- Tanzu CLI installed (Usage: `tanzu --help` in the bash prompt)
- kapp cli (Usage: `kapp --help` in the bash prompt)
- Merlin CLI for Tap or TCE App Toolkit (Usage: `merlin --help` in the bash prompt)

## Pre-Requisites 
- docker ce or ee installed locally
- kubeconfig file of a k8 cluster (aks, eks, tkg, tce managed, tce unmanaged).
    - **If k8s cluster is not pre-existing** you can create a new k8s cluster using this wizard
        - **This wizard can create aks k8s cluster** if there's no kubeconfig detected the wizard will prompt for creating a new cluster. Choose `aks` and the wizard will create an aks cluster. (post cluster create it will add the kubeconfig file in `.kube` directory). *creating aks cluster requires a service principle. If you do not have a service principal follow the wizard prompt to create a new one.*
        - You may also choose to **create a TCE cluster** using `tanzu cli` which will also place config file in the .kube dir. 
        - when you provide `AWS_ACCESS_KEY_ID` **the wizard will install `aws cli`**. You can create a **eks cluster** using the `aws cli`.
    - **if there's already a k8s cluster** get the kubeconfig file for the cluser and place it in the `.kube` directory with filename `config`
        - this wizard will detect the available contexts and prompt for selecting the the right one.
        - ***If the kubernetes control plane is private and requires accessing through bastion host*** please replace the control plane url/ip of `clusters.cluster.server` field with `kubernetes`. eg> `server: https://kubernetes:6443` in `kubeconfig` file placed in `.kube` directory of this dir. You may also be required to replace the value of `users.user.exec.env.name=CLUSTER_ENDPOINT` from private url/ip to `kubernetes`, eg> `value: https://kubernetes:6443`
- Container registry details (see below env variable)
- .env file (see below)

### Few more Prerequisites for TAP

- account in tanzunet (https://login.run.pivotal.io/login). If you dont have an account create one (it's free). ***NEEDED for TAP. NOT needed for TCE App Toolkit***
- download `tanu framework` (https://network.pivotal.io/products/tanzu-application-platform/), and place the tar in `binaries` directory ***NEEDED for TAP. NOT needed for TCE App Toolkit***
- download `cluster essential for vmware tanzu` (https://network.pivotal.io/products/tanzu-cluster-essentials) and place the tgz in `binaries` directory. ***NEEDED for TAP. NOT needed for TCE App Toolkit***
- download `tap gui` (https://network.pivotal.io/products/tanzu-application-platform/#/releases/1095326/file_groups/6091) ***NEEDED for TAP. NOT needed for TCE App Toolkit***
    - untar the tar.gz
    - create a git public repository and clone it
    - add the untar-ed/inflated contents to the git repo and push the untar (eg: blank or yelp) 
    - grab the url of catalog-info.yaml (eg: https://github.com/alinahid477/tap-gui/blob/main/blank/catalog-info.yaml) and keep it handy.




## .env
Run `cp .env.sample .env`

fill out the necessary details (ignore the vsphere related variables for now)

- `BASTION_HOST`=IP or FQDN of the bastion host. This wizard does not support password based login. Hence, when using bastion host you must place private key file called `id_rsa` (name must be `id_rsa`) in the `.ssh` dir (and the public key file named `id_rsa.pub` being in the bastion host's user's `.ssh` dir).
- `BASTION_USERNAME`=username for the bastion host login (the user who's .ssh has the id_rsa.pub file).
- `AWS_ACCESS_KEY_ID`=delete this variable or leave empty if not eks
- `AWS_SECRET_ACCESS_KEY`=delete this variable or leave empty if not eks
- `AWS_SESSION_TOKEN`=delete this variable or leave empty if not eks
- `AWS_DEFAULT_REGION`=delete this variable or leave empty if not eks
- `PVT_REGISTRY_SERVER`=the hostname of the registry server for cartographer used for supply chain. Examples: for DockerHub: https://index.docker.io/v2/, for Harbor: my-harbor.example.com, for GCR: gcr.io, for ACR: azurecr.io etc.
- `PVT_REGISTRY_REPO`=the repository where workload images (after container images are stored) are stored in the registry. Images are written to SERVER-NAME/REPO-NAME/WL_NAME-WL_NAMESPACE. EG: DockerHub: dockerhub-username, Harbor: my-project/supply-chain, GCR: my-project/supply-chain ACR: my-project/supply-chain
- `PVT_REGISTRY_USERNAME`=username of the above registry
- `PVT_REGISTRY_PASSWORD`=password for the above username
- TANZU_CLI_NO_INIT=true | leave it as it is
- `TAP_VERSION`=1.1.1 | You MUST DELETE this variable if you want to use TCE app-toolkit. ONLY KEEP this variable if you want to use Tanzu TAP
- `INSTALL_BUNDLE`=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:ab0a3539da241a6ea59c75c0743e9058511d7c56312ea3906178ec0f3491f51d | delete the below variable for app-toolkit or if not TAP
- `INSTALL_REGISTRY_HOSTNAME`=registry.tanzu.vmware.com | delete the below variable for app-toolkit or if not TAP
- `INSTALL_REGISTRY_USERNAME`=username for tanzunet | delete this variable if not TAP
- `INSTALL_REGISTRY_PASSWORD`=password for tanzunet | delete this variable if not TAP
- `DESCRIPTOR_NAME`=tap-1.1 | delete the below variable if not TAP



## Start

### for linux or mac
```
chmod +x start.sh
./start.sh
```

### for windows
```
start.bat
```

# That's it
follow the prompt of the UI for a guided experience of installing TAP on k8s

## Usage
- `--install-tap` Signals the wizard to start the process for installing TAP for Tanzu Enterprise.
- `--install-app-toolkit` Signals the wizard to start the process for installing App Toolkit package for TCE. Optionally pass values file using -f or --file flag.
- `--install-tap-package-repository` Signals the wizard to start the process for installing package repository for TAP.
- `--install-tap-profile` Signals the wizard to launch the UI for user input to take necessary inputs and deploy TAP based on profile curated from user input. Optionally pass profile file using -f or --file flag.
- `--create-developer-namespace` signals the wizard create developer namespace.
- `--configure-kpack` signals the wizard to configure kpack.
- `--configure-carto-templates` signals the wizard start creating cartographer templates for supply-chain.
- `--create-carto-supplychain` signals the wizard start creating cartographer supply-chain.
- `--create-carto-delivery` signals the wizard start creating cartographer delivery (for git-ops).
- `--create-service-account` signals the wizard start creating service account.
- `--create-docker-registry-secret` signals the wizard start creating docker registry secret.
- `--create-basic-auth-secret` signals the wizard start creating basic auth secret.
- `--create-git-ssh-secret` signals the wizard start creating git ssh secret.


## Demo Video:

TAP: 
[![Watch the video](https://img.youtube.com/vi/vHhRGqbM3uU/hqdefault.jpg)](https://youtu.be/vHhRGqbM3uU)


Cartographer:
[![Watch the video](https://img.youtube.com/vi/rnIVsDjxhS0/hqdefault.jpg)](https://youtu.be/rnIVsDjxhS0)



# TODO
- GUI for installer


# Flux CD Stuff

- exclude `fluxcd.source.controller.tanzu.vmware.com` from RUN cluster profile
- Manually install fluxcd (as described below)
    - This is because with `source-control.flux.io` (which is what TAP installs) only does source code fetch
    - We also need to "kubectl apply -f config/delivery.yaml" (delivery.yaml generated and pushed by build cluster -- supply-chain / tekton gitops)
    - installing fluxcd the below way will also install `Kustomize.flux.io` which will do kubectl apply based on the source 

https://fluxcd.io/docs/installation/

```
curl -s https://fluxcd.io/install.sh | sudo bash
flux check --pre
export GITHUB_TOKEN=<your-token>
flux bootstrap github --owner=alinahid477 --repository=pvtrepo --path=flux-system --personal=true --private=true
## Modify the binaries/templates/fluxcd-run.yaml file accordingly and run the below
kubectl deploy -f binaries/templates/fluxcd-run.yaml
```


# Some concept dump (WIP)

## Road Map
- EKS cluster create

## IGNORE this part ---- TAP components

*This diagram needs to be fixed*
<img src="images/tap-whiteboard.png" alt="TAP"/>