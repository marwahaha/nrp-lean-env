# nrp-lean-env

A self-contained container image for checking Lean proofs against the Prove2me platform environment:

- Lean **v4.33.1** (via elan, under `/opt/elan`)
- Mathlib at commit **`0df444a360eaa60ab8c11dca51a86af692955474`**, with the prebuilt `.olean` cache already unpacked
- the [prove2me_workspace](https://github.com/prove2me/prove2me_workspace) checked out at `/opt/prove2me_workspace`, pinned exactly as the workspace's `references/lean-setup.md` describes (`lean-toolchain` + `lakefile.lean` with `autoImplicit false`)
- an entrypoint, `check <module>...`, that runs `lake build` on files added at run time

Built in GitHub Actions and published to `ghcr.io/prove2me/nrp-lean-env`. Made for batch proof checks on the [NRP Nautilus](https://nrp.ai) cluster, but it is a plain OCI image and runs anywhere.

## Tags

| Tag | Meaning |
|-----|---------|
| `v4.33.1-0df444a` | toolchain version, then the first 7 characters of the Mathlib commit |
| `latest` | the most recent build |

Pin the full tag in anything that matters. `latest` moves.

## Build

The **build image** workflow (`.github/workflows/build.yml`) runs on every push to `main` that touches the Dockerfile, the entrypoint, or the workflow itself, and can be run by hand from the Actions tab with a different toolchain or Mathlib commit. A build takes about 15 minutes, almost all of it downloading the Mathlib cache. The image is around 7 GB.

The Mathlib layer is rebuilt only when `MATHLIB_REV` changes. The build fails if the resolved Mathlib HEAD does not equal the requested commit, or if the workspace smoke test does not build.

Locally:

```bash
docker build -t nrp-lean-env .
docker run --rm nrp-lean-env Solutions.SmokeTest
```

After the first push, open the package on GitHub (Packages tab of the prove2me org) and set its visibility to **public**, or NRP cannot pull it without an image pull secret.

## Use

Drop `.lean` files into the workspace tree and name the module to build:

```bash
docker run --rm \
  -v "$PWD/k8s/example/Sol_example.lean:/opt/prove2me_workspace/Solutions/Sol_example.lean:ro" \
  ghcr.io/prove2me/nrp-lean-env:v4.33.1-0df444a Solutions.Sol_example
```

Mirror the platform's module layout, as the workspace skill describes:

| Path | Contents |
|------|----------|
| `Theorems/Thm_<slug>.lean` | a platform theorem's `preamble` + `formal_statement`, ending in `by sorry` |
| `Definitions/Def_<name>.lean` | a platform definition, verbatim |
| `Solutions/Sol_<name>.lean` | the file you intend to submit |

With no arguments `check` builds the whole `Solutions` library.

## On NRP Nautilus

`k8s/` holds two Job manifests that follow the cluster policies as written on 2026-11-02:

- `smoke-job.yaml` builds the workspace smoke test. Run it once after every new image.
- `check-job.yaml` mounts files from a ConfigMap named `lean-check-files` and builds one module. The header comment has the exact commands.

Both request 2 CPU, 6 GiB memory, and 4 GiB ephemeral storage, with limits equal to requests, no retries, and a 15 minute self-delete. The entrypoint prints the peak heap and peak mapped-file memory at the end of every run; after a few real proofs, trim the requests toward those peaks so usage stays within the cluster's 20 to 150 percent band. Read the log before the Job disappears, or raise `ttlSecondsAfterFinished`. Do not add GPUs, tolerations, or a priority class. Job specs are readable by every cluster user, so nothing secret belongs in them.

## Changing the pins

Edit the two `ARG` defaults at the top of the Dockerfile (or pass them to the workflow), push, and use the new tag. The platform's authoritative list of environments is `GET https://prove2me.com/api/v1/environments`.
