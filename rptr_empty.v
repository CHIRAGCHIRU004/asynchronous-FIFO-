// =============================================================================
// File        : rptr_empty.v
// Description : Generates the read-address binary pointer, its Gray-coded
//               equivalent (for safe CDC), and the "empty" flag by comparing
//               the read pointer against the synchronized write pointer.
//               Empty is detected when the next read Gray pointer equals the
//               synchronized write Gray pointer exactly.
// =============================================================================

module rptr_empty #(
    parameter ASIZE = 4
)(
    input                   rclk,
    input                   rrst_n,
    input                   rinc,             // read-enable request
    input      [ASIZE:0]    wptr_rclk,        // synchronized write pointer (Gray)

    output reg [ASIZE-1:0]  raddr,            // binary address into memory
    output reg [ASIZE:0]    rptr_gray,        // Gray read pointer (to sync into wclk domain)
    output reg              rempty
);

    reg  [ASIZE:0] rbin;
    wire [ASIZE:0] rbin_next;
    wire [ASIZE:0] rgray_next;
    wire           rempty_next;

    // ------------------------------------------------------------------
    // Binary pointer advance
    // ------------------------------------------------------------------
    assign rbin_next  = rbin + (rinc & ~rempty);
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;   // binary -> Gray

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin      <= 0;
            rptr_gray <= 0;
        end else begin
            rbin      <= rbin_next;
            rptr_gray <= rgray_next;
        end
    end

    always @* raddr = rbin[ASIZE-1:0];

    // ------------------------------------------------------------------
    // Empty flag: next read pointer (Gray) equals write pointer (Gray)
    // ------------------------------------------------------------------
    assign rempty_next = (rgray_next == wptr_rclk);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n)
            rempty <= 1'b1;
        else
            rempty <= rempty_next;
    end

endmodule
