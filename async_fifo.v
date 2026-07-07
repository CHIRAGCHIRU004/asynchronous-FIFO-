// =============================================================================
// File        : async_fifo.v
// Description : Top-level parameterized dual-clock asynchronous FIFO.
//               - Configurable data width (DSIZE) and depth (2^ASIZE)
//               - Gray-coded pointers for safe clock-domain crossing (CDC)
//               - 2-flop synchronizers to minimize metastability risk
//               - Standard Cummings-style full/empty generation
// =============================================================================

module async_fifo #(
    parameter DSIZE = 8,   // data width
    parameter ASIZE = 4    // address width -> FIFO depth = 2^ASIZE
)(
    // Write (producer) clock domain
    input                   wclk,
    input                   wrst_n,
    input                   winc,       // write request
    input      [DSIZE-1:0]  wdata,
    output                  wfull,

    // Read (consumer) clock domain
    input                   rclk,
    input                   rrst_n,
    input                   rinc,       // read request
    output     [DSIZE-1:0]  rdata,
    output                  rempty
);

    wire [ASIZE:0]   wptr_gray, rptr_gray;
    wire [ASIZE:0]   wptr_rclk, rptr_wclk;
    wire [ASIZE-1:0] waddr, raddr;

    // ------------------------------------------------------------------
    // Synchronizers: cross Gray-coded pointers between clock domains
    // ------------------------------------------------------------------
    sync_r2w #(.ASIZE(ASIZE)) u_sync_r2w (
        .wclk       (wclk),
        .wrst_n     (wrst_n),
        .rptr_gray  (rptr_gray),
        .rptr_wclk  (rptr_wclk)
    );

    sync_w2r #(.ASIZE(ASIZE)) u_sync_w2r (
        .rclk       (rclk),
        .rrst_n     (rrst_n),
        .wptr_gray  (wptr_gray),
        .wptr_rclk  (wptr_rclk)
    );

    // ------------------------------------------------------------------
    // Write-side pointer & full-flag generation
    // ------------------------------------------------------------------
    wptr_full #(.ASIZE(ASIZE)) u_wptr_full (
        .wclk       (wclk),
        .wrst_n     (wrst_n),
        .winc       (winc),
        .rptr_wclk  (rptr_wclk),
        .waddr      (waddr),
        .wptr_gray  (wptr_gray),
        .wfull      (wfull)
    );

    // ------------------------------------------------------------------
    // Read-side pointer & empty-flag generation
    // ------------------------------------------------------------------
    rptr_empty #(.ASIZE(ASIZE)) u_rptr_empty (
        .rclk       (rclk),
        .rrst_n     (rrst_n),
        .rinc       (rinc),
        .wptr_rclk  (wptr_rclk),
        .raddr      (raddr),
        .rptr_gray  (rptr_gray),
        .rempty     (rempty)
    );

    // ------------------------------------------------------------------
    // Dual-port storage
    // ------------------------------------------------------------------
    fifo_mem #(.DSIZE(DSIZE), .ASIZE(ASIZE)) u_fifo_mem (
        .wclk       (wclk),
        .wclk_en    (winc),
        .wfull      (wfull),
        .waddr      (waddr),
        .wdata      (wdata),
        .raddr      (raddr),
        .rdata      (rdata)
    );

endmodule
