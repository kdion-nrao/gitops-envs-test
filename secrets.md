# Secrets Management

Uses a combination of the following tools for encrypting secrets and using them in the project:
- [helm-secrets](https://github.com/jkroepke/helm-secrets/): Helm plugin for using encrypted fields in Helm charts
- [ksops](https://github.com/viaduct-ai/kustomize-sops): Kustomize plugin for using encrypted fields in kustomize manifests (i.e. non-Helm secrets)
- [sops](https://getsops.io/): Encryption/Decryptopn backend chosen for `helm-secrets`
- [age](https://github.com/FiloSottile/age): Encryption tool/key format chosen for `sops`

Note that the choices of `sops` and `age` are not the only available options for a solution using `helm-secrets`, but were chosen for simplicity and ease of use by developers. SOPS in particular requires minimal external (to the team) coordination or 

## helm-secrets *and* ksops

If there are secrets that need to be injected into a deployed Helm chart, `helm-secrets` covers that well, but if a deployment requires *other* secrets outside of Helm values (such as a GitHub token, or repository connection), that's where `ksops` comes into play.

## `age` Keys

One of the interesting things about `age` encryption keys is that the tool supports using SSH keys (`ssh-ed25519` and `ssh-rsa` only), so in theory key management for `sops` could use existing SSH key distribution mechanisms and channels. 

In this vein, this prototype generates the list of age 'recipients` (public keys which can decrypt a given file) using SSH public keys gathered from GitHub via a list of usernames:

- `.sopsgen.cfg.yaml`: contains a list of GitHub usernames to allow, as well as any additional age keys to allow
- `sops_gen_recipients.sh`: Reads the `.sopsgen.cfg.yaml` file, and:
   - For each entry in `age.github-users`:
      - Pulls public SSH keys from `https://github.com/<username>.keys`
      - For each `ssh-ed25519` or `ssh-rsa` key, adds it to the recipient key list
   - For each entry in `age.keys`:
      - adds to the recipient key list
   - Adds all recipient keys to the `.sops.yaml` configuration file
   - Re-encrypts all secrets files with the latest keys

## Encrypting/Decrypting secrets files

For this prototype, all sensitive data is contained in files following the naming convention `*-secrets.yaml`, and a corresponding configuration in `.sops.yaml` has been added to set which keys to use. 

Rules for `.gitignore` have been added to help prevent unencrypted sensitive data from being uploaded into the public repository, with unencrypted files using a plain `*.yaml` naming convention, with the encrypted version using a `*.enc.yaml` extension.

To encrypt a plaintext yaml file, you would run the following:
```bash
sops -e secrets/test.yaml > secrets/test.enc.yaml
```

To decrypt the encrypted file, you would run
```bash
sops -d secrets/test.enc.yaml > secrets/test.yaml
```

When the key list is updated, you can re-encrypt the file with the new keys list by running:
```bash
sops updatekeys secrets/test.enc.yaml
```

## Alternative Solutions

SOPS + age keys was chosen for quick prototyping, but popular and often-recommended alternatives exist:

- [External Secrets Operator](https://external-secrets.io/latest/introduction/overview/)
- [Sealed Secrets](https://github.com/bitnami/sealed-secrets)
