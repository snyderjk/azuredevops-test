# VMSS runner → private VM file copy (POC)

On every push to `main`, GitHub Actions:

1. **start-runner** (GitHub-hosted): logs into Azure via OIDC, scales the VMSS from 0 → 1, and uses
   Azure Run Command to install an **ephemeral** GitHub Actions runner on the new instance
   (`scripts/register-runner.sh`). Waits until the runner is online.
2. **copy-file** (on the VMSS runner, inside your VNet): `scp`s `files/hello.txt` to the private VM.
3. **stop-runner** (GitHub-hosted, always runs): scales the VMSS back to 0 and deletes any leftover
   runner registration.

```
GitHub ──(OIDC/ARM API)──> VMSS (0→1) ──run-command──> runner registers with GitHub
                                │
                                └──scp over private IP──> private VM
```

## Azure prerequisites (existing infra)

- VMSS (Ubuntu, Uniform or Flexible) in a subnet that can reach the private VM on port 22.
- **Outbound internet** from the VMSS subnet to `github.com` / `*.actions.githubusercontent.com`
  (NAT Gateway, firewall, etc. — new VNets no longer get default outbound access).
- The private VM accepts the SSH public key matching `TARGET_VM_SSH_KEY`.
- An Entra app registration / user-assigned identity with a **federated credential** for this repo
  (`repo:<owner>/<repo>:ref:refs/heads/main`) and **Virtual Machine Contributor** on the VMSS's
  resource group.

## GitHub configuration

**Secrets** (Settings → Secrets and variables → Actions → Secrets)

| Name | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | App registration / managed identity client ID |
| `AZURE_TENANT_ID` | Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID |
| `RUNNER_ADMIN_PAT` | Fine-grained PAT on this repo with **Administration: Read and write** (needed to mint runner registration tokens; `GITHUB_TOKEN` can't) |
| `TARGET_VM_SSH_KEY` | Private SSH key for the target VM user |

**Variables** (same page → Variables)

| Name | Example |
| --- | --- |
| `AZURE_RESOURCE_GROUP` | `rg-poc` |
| `VMSS_NAME` | `vmss-runner` |
| `TARGET_VM_IP` | `10.0.1.4` |
| `TARGET_VM_USER` | `azureuser` |
| `TARGET_PATH` *(optional)* | `/tmp/` (default) |
| `SOURCE_FILE` *(optional)* | `files/hello.txt` (default) |

## POC shortcuts (harden before real use)

- Host key checking is disabled for the scp; pin the target's host key via a `known_hosts` secret instead.
- The registration token is passed as a Run Command parameter, so it appears in the instance's
  Run Command logs. It's single-use and expires in 1 hour, but a GitHub App or baking registration
  into the VMSS custom data is cleaner.
- A single shared VMSS + `concurrency` group means runs are serialized.

Test CI/CI Pipeline
