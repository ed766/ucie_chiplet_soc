LibreLane/OpenLane2 configuration for the `soc_chiplet_top` dual-die system. Run with:

```
python3 -m librelane --pdk-root ~/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af \
  /home/esgha/ucie_chiplet_soc/chiplet_extension/openlane/chiplet/config.json
```

Adjust the PDK path to match your local installation or provide `--pdk sky130A` if you have a standard LibreLane environment setup.
The config uses `soc_chiplet_top.sdc` and a relaxed `CLOCK_PERIOD` (200 ns) for exploratory runs; tighten as needed for timing closure.
