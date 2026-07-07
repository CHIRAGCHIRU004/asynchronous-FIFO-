// =============================================================================
// File        : sync_r2w.v
// Description : 2-flop (double) synchronizer that safely brings the Gray-coded
//               read pointer from the read clock domain into the write clock
//               domain. Using Gray code ensures only one bit changes per
//               increment, so metastability on a single bit cannot corrupt
//               more than one bit of the synchronized value.
// =============================================================================

module sync_r2w #(
    parameter ASIZE = 4
)(
    input                   wclk,
    input                   wrst_n,
    input      [ASIZE:0]    rptr_gray,   // Gray-coded read pointer (source domain)
    output reg [ASIZE:0]    rptr_wclk    // synchronized into write clock domain
);

    reg [ASIZE:0] rptr_meta;

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            {rptr_wclk, rptr_meta} <= 0;
        end else begin
            {rptr_wclk, rptr_meta} <= {rptr_meta, rptr_gray};
        end
    end

endmodule
