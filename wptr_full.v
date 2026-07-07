// =============================================================================
// File        : wptr_full.v
// Description : Generates the write-address binary pointer, its Gray-coded
//               equivalent (for safe CDC), and the "full" flag by comparing
//               the write pointer against the synchronized read pointer.
//               The full condition is detected when the next write Gray
//               pointer equals the synchronized read Gray pointer with the
//               top two MSBs inverted (standard Cummings full-detection).
// =============================================================================

module wptr_full #(
    parameter ASIZE = 4
)(
    input                   wclk,
    input                   wrst_n,
    input                   winc,             // write-enable request
    input      [ASIZE:0]    rptr_wclk,        // synchronized read pointer (Gray)

    output reg [ASIZE-1:0]  waddr,            // binary address into memory
    output reg [ASIZE:0]    wptr_gray,        // Gray write pointer (to sync into rclk domain)
    output reg              wfull
);

    reg  [ASIZE:0] wbin;
    wire [ASIZE:0] wbin_next;
    wire [ASIZE:0] wgray_next;
    wire           wfull_next;

    // ------------------------------------------------------------------
    // Binary pointer advance
    // ------------------------------------------------------------------
    assign wbin_next  = wbin + (winc & ~wfull);
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;   // binary -> Gray

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin      <= 0;
            wptr_gray <= 0;
        end else begin
            wbin      <= wbin_next;
            wptr_gray <= wgray_next;
        end
    end

    always @* waddr = wbin[ASIZE-1:0];

    // ------------------------------------------------------------------
    // Full flag: next write pointer (Gray) equals read pointer (Gray)
    // with the two MSBs inverted -> the classic wrap-around comparison.
    // ------------------------------------------------------------------
    assign wfull_next = (wgray_next == {~rptr_wclk[ASIZE:ASIZE-1], rptr_wclk[ASIZE-2:0]});

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n)
            wfull <= 1'b0;
        else
            wfull <= wfull_next;
    end

endmodule
