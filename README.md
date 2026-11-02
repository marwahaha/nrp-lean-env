# nrp-lean-env

Container image for checking Lean proofs against the Prove2me default environment:
Lean v4.33.1, Mathlib `0df444a360eaa60ab8c11dca51a86af692955474` with the prebuilt cache,
and [prove2me_workspace](https://github.com/prove2me/prove2me_workspace) at `/opt/prove2me_workspace`.

Image: `ghcr.io/prove2me/nrp-lean-env:v4.33.1-0df444a` (`latest` moves; pin the full tag).

## Use

```bash
docker run --rm \
  -v "$PWD/k8s/example/Sol_example.lean:/opt/prove2me_workspace/Solutions/Sol_example.lean:ro" \
  ghcr.io/prove2me/nrp-lean-env:v4.33.1-0df444a Solutions.Sol_example
```

The entrypoint is `check <module>...` (default `Solutions`). Place files as the platform does:
`Theorems/Thm_<slug>.lean`, `Definitions/Def_<name>.lean`, `Solutions/Sol_<name>.lean`.

## Build

`.github/workflows/build.yml` builds on pushes to `main` that touch `Dockerfile`, `check.sh` or the workflow,
or by hand with another toolchain and Mathlib commit. Pins are the two `ARG`s at the top of the Dockerfile.

## NRP Nautilus

`k8s/smoke-job.yaml` builds the workspace smoke test. `k8s/check-job.yaml` builds one module from a ConfigMap;
its header has the commands. Both set requests equal to limits, no retries and a 15 minute TTL.
The log ends with peak heap and mapped memory; size requests from those.
