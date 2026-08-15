# FPGA SPI Protocol + SAR ADC (Simulation)

Behavioral Verilog implementation of an SPI master/slave link and an N-bit
Successive-Approximation-Register (SAR) ADC, integrated together to model
how a host FPGA would read digitized sensor data from an SPI-output ADC.
Built and verified in Xilinx Vivado (XSIM).
## Why this exists

Real SPI ADC chips (MCP3008, ADS7x, etc.) hand back digitized samples over
a serial link that a host FPGA has to shift in correctly. This project
builds both halves from scratch — the ADC's successive-approximation core
and the SPI transport — and wires them together so the full path
(analog input → SAR conversion → SPI shift-out → host capture) can be
verified in simulation before ever touching real silicon.

## Architecture

1. `start_conv` triggers `sar_adc`, which runs SAMPLE → CONVERT (one bit
   per clock, MSB first) → DONE, driving `dac_code` out to a behavioral
   DAC/comparator model that lives in the testbench (`real`-valued `Vin`,
   `VREF`, `VDAC`, with `comp_out = (Vin >= VDAC)`).
2. On `eoc`, the result is latched and handed to `spi_slave.tx_data`.
3. A couple of clocks later, `spi_master` automatically starts an SPI
   Mode 0 transfer to read that byte back.
4. `spi_master.rx_data` becomes `adc_value_spi` — the same number that
   came out of the ADC, now delivered end-to-end over SPI, letting the
   testbench check both values agree.



## Module summaries

| Module               | Role                                                                 |
|-----------------------|-----------------------------------------------------------------------|
| `sar_adc`             | N-bit SAR conversion FSM: IDLE → SAMPLE → CONVERT (N cycles) → DONE |
| `spi_clock_divider`   | Produces a 1-clock-wide `tick` every SPI half-period, only while enabled |
| `spi_master`          | Drives an 8-bit Mode 0 (CPOL=0, CPHA=0) transfer, MSB first          |
| `spi_slave`           | Mode 0 slave with 3-stage synchronizers on SCLK/CS/MOSI for safe CDC across boards |
| `adc_spi_top`         | Glue logic: latches ADC output into the slave's `tx_data`, auto-fires the master read |

## SPI protocol details

- **Mode 0** (CPOL = 0, CPHA = 0): data is set up before the first clock
  edge, changed on falling edges, sampled on rising edges.
- **Bit order:** MSB first, on both master and slave.
- **Frame size:** fixed 8 bits per transfer.
- CS is asserted for the duration of one byte and released between
  transfers; the slave starts a new transfer only on a detected falling
  edge of CS (not just a low level), to avoid re-triggering on stale CS
  state.

## Running the simulation in Vivado

1. Add all `.v` files above to a Vivado simulation fileset.
2. Set **`adc_spi_tb`** as the simulation top (or `sar_adc_tb` /
   `spi_loopback_top` if you want to test the ADC or the SPI link in
   isolation) — only one testbench can be top at a time.
3. Launch simulation. **Important:** the default XSIM run window is only
   1000 ns, which is not long enough to finish all three SPI-integrated
   test cases. Either:
   - Type `run -all` in the Tcl console, or
   - Set **Simulation Settings → Simulation → `xsim.simulate.runtime`**
     to `-all` (or a few thousand ns) before launching.
4. Watch the console output — each test prints the direct ADC output and
   the value read back over SPI, and explicitly reports a match/mismatch.

### Expected results (`VREF = 5.0 V`, N = 8)

| Test | Vin (V) | Expected code (dec) | Expected code (bin) |
|------|---------|----------------------|-----------------------|
| 1    | 2.5     | 128                  | `10000000`            |
| 2    | 1.0     | ~51                  | `00110011`            |
| 3    | 4.0     | ~204                 | `11001100`            |

`adc_dout` and `adc_value_spi` should match on every test.

## Design notes / known limitations

- The DAC and comparator are **behavioral only** (real-number arithmetic
  in the testbench) — there is no settling-time model. A real hardware
  SAR front-end would need a wait state per bit to let the analog signal
  settle before the comparator decision is latched.
- `spi_master` / `spi_slave` are fixed at 8 bits wide; `sar_adc`'s `N`
  parameter should stay at 8 unless the SPI modules are also widened.
- Default `CLK_FREQ = 100 MHz`, `SPI_FREQ = 10 MHz` gives only a 10:1
  ratio. This works in simulation, but for a real cross-board link, a
  lower `SPI_FREQ` (e.g. `CLK_FREQ/20` or slower) is recommended to give
  the slave's input synchronizers more margin.
- No sample-and-hold is modeled — the testbench keeps `Vin` constant for
  the duration of each conversion.

