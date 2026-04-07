LibreLane/OpenLane2 configuration for the `soc_chiplet_top` dual-die system.
Run it from the LibreLane Nix shell:

```
/nix/var/nix/profiles/default/bin/nix-shell --pure <librelane-root>/shell.nix
cd <librelane-root>
librelane \
  --pdk-root <sky130-pdk-root> \
  <repo-root>/chiplet_extension/openlane/chiplet/config.json
```

Adjust the PDK path to match your local installation or provide `--pdk sky130A`
if you have a standard LibreLane environment setup. The config uses
`soc_chiplet_top.sdc` and a relaxed `CLOCK_PERIOD` (200 ns) for exploratory
runs; tighten as needed for timing closure.
