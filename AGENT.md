# Agent Notes

- Shell scripts in this project target Bash 5. Use Bash 5 syntax where it keeps the code simpler and clearer.
- `bin/` is split by where the script runs: `bin/host/` is the host CLI (`install.sh` copies it to `/usr/local/bin`), `bin/container/` is baked into the image (`Dockerfile` copies it to `~/.local/bin`), and `bin/dev/` is local tooling that ships nowhere. `bin/host/omaterm` sources its siblings (`omaterm-limits`, `omaterm-templates`, `omaterm-op`) by directory, so they must travel together.
- Run the tests with `test/run` (runs every `test/*-test` suite); shared assertions live in `test/helpers`.
