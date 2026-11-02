# syntax=docker/dockerfile:1
# Lean 4.33.1 + Mathlib (platform default env) + prove2me workspace, prebuilt.
# One image, used by every proof-check Job on NRP. Build once in CI, pull many times.
#
#   docker build --build-arg MATHLIB_REV=0df444a360eaa60ab8c11dca51a86af692955474 \
#                --build-arg LEAN_TOOLCHAIN=leanprover/lean4:v4.33.1 -t nrp-lean-env .
#
FROM ubuntu:24.04

ARG LEAN_TOOLCHAIN=leanprover/lean4:v4.33.1
ARG MATHLIB_REV=0df444a360eaa60ab8c11dca51a86af692955474
ARG WORKSPACE_REPO=https://github.com/prove2me/prove2me_workspace.git

ENV DEBIAN_FRONTEND=noninteractive \
    LAKE_NO_FETCH=1 \
    ELAN_HOME=/opt/elan \
    PATH=/opt/elan/bin:/usr/local/bin:/usr/bin:/bin \
    WORKSPACE=/opt/prove2me_workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git zstd python3 jq libgmp10 \
    && rm -rf /var/lib/apt/lists/*

# 1. elan + the exact toolchain
RUN curl -sSfL https://elan.lean-lang.org/elan-init.sh \
      | sh -s -- -y --no-modify-path --default-toolchain "${LEAN_TOOLCHAIN}" \
    && lean --version

# 2. the prove2me workspace, pinned exactly as references/lean-setup.md says
RUN git clone --depth 1 "${WORKSPACE_REPO}" "${WORKSPACE}"
WORKDIR ${WORKSPACE}
RUN printf '%s\n' "${LEAN_TOOLCHAIN}" > lean-toolchain \
 && cat > lakefile.lean <<LAKE
import Lake
open Lake DSL

package «prove2me» where
  leanOptions := #[⟨\`autoImplicit, false⟩]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @
  "${MATHLIB_REV}"

lean_lib «Definitions» where
lean_lib «Theorems» where
@[default_target]
lean_lib «Solutions» where
LAKE

# 3. Mathlib: shallow-fetch the pinned commit, pull the prebuilt cache, verify with the smoke test.
#    This layer is the big one (~6 GB). It changes only when MATHLIB_REV changes.
RUN lake update \
 && lake exe cache get \
 && git -C .lake/packages/mathlib rev-parse HEAD | grep -q "^${MATHLIB_REV}" \
 && time lake build Solutions.SmokeTest \
 && rm -rf /root/.cache/mathlib \
 && du -sh .lake

# 4. tiny entrypoint: build whatever Solutions/Theorems/Definitions files were added at run time.
COPY check.sh /usr/local/bin/check
RUN chmod +x /usr/local/bin/check
ENTRYPOINT ["/usr/local/bin/check"]
