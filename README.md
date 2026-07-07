# Scalable Asynchronous FIFO for Multi-Clock Systems

A parameterized, dual-clock asynchronous FIFO written in Verilog, targeting
reliable data transfer across independent clock domains (CDC). Built and
verified with a self-checking testbench in Icarus Verilog / Vivado.

## Highlights

- **Gray-coded pointers** for both write and read addresses, guaranteeing
  only a single bit toggles per pointer increment — the key property that
  makes multi-bit synchronization safe across clock domains.
- **2-flop (double) synchronizers** on both the read→write and write→read
  paths to reduce the probability of metastability propagating into logic.
- **Fully parameterized**: data width (`DSIZE`) and FIFO depth (`2^ASIZE`)
  are set at instantiation time.
- **Standard full/empty detection** (Cummings-style): full is detected by
  comparing the next write pointer against the synchronized read pointer
  with the two MSBs inverted; empty is detected by direct equality of the
  next read pointer against the synchronized write pointer.
- **Self-checking testbench** with a software reference (golden) queue that
  verifies every word written is read back in order, with zero corruption,
  across:
  - Reset behavior
  - **Overflow** (writing into a full FIFO)
  - **Underflow** (reading from an empty FIFO)
  - **Boundary / pointer wraparound** under randomized, concurrent,
    independently-clocked read/write traffic

## Repository Structure

```
async-fifo-cdc/
├── rtl/
│   ├── async_fifo.v      # Top-level FIFO (instantiates everything below)
│   ├── fifo_mem.v        # Dual-port storage (registered write, async read)
│   ├── wptr_full.v       # Write pointer, Gray conversion, full-flag logic
│   ├── rptr_empty.v      # Read pointer, Gray conversion, empty-flag logic
│   ├── sync_r2w.v        # 2-flop synchronizer: read ptr -> write clock domain
│   └── sync_w2r.v        # 2-flop synchronizer: write ptr -> read clock domain
├── tb/
│   └── async_fifo_tb.v   # Self-checking testbench
└── README.md
```

## Interface

```verilog
async_fifo #(
    .DSIZE(8),   // data width
    .ASIZE(4)    // address width -> depth = 2^ASIZE = 16
) fifo_inst (
    .wclk   (wclk),    .wrst_n (wrst_n),
    .winc   (winc),    .wdata  (wdata),   .wfull  (wfull),

    .rclk   (rclk),    .rrst_n (rrst_n),
    .rinc   (rinc),    .rdata  (rdata),   .rempty (rempty)
);
```

| Signal   | Direction | Domain | Description                       |
|----------|-----------|--------|------------------------------------|
| `wclk`   | in        | write  | Write clock                        |
| `wrst_n` | in        | write  | Active-low write-domain reset      |
| `winc`   | in        | write  | Write request                      |
| `wdata`  | in        | write  | Write data                         |
| `wfull`  | out       | write  | FIFO full flag                     |
| `rclk`   | in        | read   | Read clock                         |
| `rrst_n` | in        | read   | Active-low read-domain reset       |
| `rinc`   | in        | read   | Read request                       |
| `rdata`  | out       | read   | Read data                          |
| `rempty` | out       | read   | FIFO empty flag                    |

## Running the Testbench (Icarus Verilog)

```bash
iverilog -g2005 -o fifo_sim tb/async_fifo_tb.v rtl/*.v
vvp fifo_sim
```

Expected output ends with:

```
TEST PASSED: <N> writes / <N> reads, 0 mismatches.
```

## Running in Vivado

1. Create a new RTL project and add all files under `rtl/` as design sources.
2. Add `tb/async_fifo_tb.v` as a simulation-only source.
3. Set `async_fifo_tb` as the top module for the Simulation fileset.
4. Run Behavioral Simulation; the transcript will report the same
   `TEST PASSED` / `TEST FAILED` summary.

## Design Notes: Why Gray Code + 2-Flop Synchronizers?

A binary pointer can have multiple bits change simultaneously on increment
(e.g. `0111 -> 1000`). If that multi-bit transition is sampled by an
unrelated clock mid-toggle, different bits can be captured on either side
of the transition, producing a wildly incorrect intermediate value. Gray
code guarantees exactly one bit changes per increment, so a synchronizer
that catches a pointer mid-transition can only ever be off by the single
bit that was changing — which resolves to either the pointer's old or new
value, never garbage. The 2-flop synchronizer chain then gives any
resulting metastability a full clock period to resolve before the value is
used by downstream full/empty comparison logic.

## Latency & Synchronization Behavior

Because pointers must cross two flip-flop stages before they're visible in
the opposite clock domain, full/empty flags are inherently a few cycles
"pessimistic" — i.e., `wfull`/`rempty` may report the FIFO as fuller/emptier
than the absolute instant it changed, but never the reverse. This is the
correct and safe direction for CDC: the FIFO will never claim it's safe to
write into a full buffer or read from an empty one. Designers should size
`ASIZE` with enough margin above the expected burst-size delta between the
two clock domains to avoid false backpressure from this synchronization
latency.
