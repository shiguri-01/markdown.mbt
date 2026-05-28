---
name: profile-workflow
description: Profile and improve this MoonBit library using the repository's profiling workflow. Use when asked to measure parser/rendering performance, inspect hot functions, compare before/after optimization results, run wasm-gc or native profiling, or interpret summaries produced by just prof-wasm-gc, just prof-native, or moon-pprof.
---

# Profile Workflow

Use `just prof*` as the profiling interface. Produce pprof files, identify expensive Markdown parser/rendering code, make focused improvements, and verify behavior.

## Usual Commands

Use the backend-specific commands:

```sh
just prof-wasm-gc
just prof-native
```

Use these for existing profile files:

```sh
just prof-summary /tmp/markdown-mbt-wasm-gc.pb.gz
just prof-diff /tmp/before.pb.gz /tmp/after.pb.gz
```

## Workload

The profiling workload is `bench/profile`. It is fixed and argument-free so the same workload can run under wasm-gc and native profiling.

If the workload is too short, too noisy, or no longer representative, update `bench/profile/main.mbt` instead of adding ad hoc profiling commands. After changing it, run:

```sh
nix develop .#default -c moon -C bench fmt
nix develop .#default -c moon -C bench check
nix develop .#default -c moon -C bench info
```

## Analysis Loop

1. Capture a baseline:

   ```sh
   just prof-wasm-gc /tmp/before-wasm-gc.pb.gz /tmp/before-wasm-gc.json
   just prof-native /tmp/before-native.pb.gz /tmp/before-native.perf.data /tmp/before-native.perf.txt
   ```

2. Read the summary first. Prioritize frames under `shiguri::markdown::...`.

3. Treat runtime frames as clues:

   - `array::...`, `StringBuilder::...`, and string copy frames usually point to allocation/copy pressure in callers.
   - `moonbit_incref_inlined`, `moonbit_decref_inlined`, and `moonbit_drop_object` point to ownership/refcount pressure.
   - Use caller context before changing code; do not optimize a runtime frame in isolation.

4. Make one focused library change.

5. Recapture:

   ```sh
   just prof-wasm-gc /tmp/after-wasm-gc.pb.gz /tmp/after-wasm-gc.json
   just prof-native /tmp/after-native.pb.gz /tmp/after-native.perf.data /tmp/after-native.perf.txt
   ```

6. Compare:

   ```sh
   just prof-diff /tmp/before-wasm-gc.pb.gz /tmp/after-wasm-gc.pb.gz
   just prof-diff /tmp/before-native.pb.gz /tmp/after-native.pb.gz
   ```

## Choosing Signals

- Compare `wasm-gc` and `native` when evaluating an optimization.
- If only one signal is needed, prefer `wasm-gc` for quick iteration.
- Treat low native sample counts as directional; rerun before drawing conclusions.
- Do not make public API changes for a profiling improvement unless the user asked for an API change.

## Validation

After any optimization, run the normal correctness checks:

```sh
just check
just test
nix develop .#default -c moon info
nix develop .#default -c moon fmt
```

Review `pkg.generated.mbti` diffs. No public API diff is expected for most performance work.

## Reporting

Report:

- commands run
- pprof output paths
- total time and sample count
- top relevant `shiguri::markdown::...` frames
- before/after change from `prof-diff`, if measured
- validation commands and any remaining caveats
