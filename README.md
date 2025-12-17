## An attempt at some of AoC 2025 in raw ARM64 assembly

If you look at the Makefile you'll see that libSystem is actually linked but I'm not using any of the libc stuff, linking static binaries on MacOS seems to just be an enormous pain.

Also if for some reason you want to run anything, I'm on MacOS (for now) and since I'm not using any of the wrappers in libSystem for syscall related stuff, no guarantees that anything will work since Apple doesn't guarantee the consistency of syscall codes between OS releases.

Thanks Apple!! 🥰
