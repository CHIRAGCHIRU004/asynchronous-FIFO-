// =============================================================================
// File        : sync_w2r.v
// Description : 2-flop (double) synchronizer that safely brings the Gray-coded
//               write pointer from the write clock domain into the read
//               clock domain.
// =============================================================================

module sync_w2r #(
    parameter ASIZE = 4
)(
    input                   rclk,
    input                   rrst_n,
    input      [ASIZE:0]    wptr_gray,   // Gray-coded write pointer (source domain)
    output reg [ASIZE:0]    wptr_rclk    // synchronized into read clock domain
);

    reg [ASIZE:0] wptr_meta;

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            {wptr_rclk, wptr_meta} <= 0;
        end else begin
            {wptr_rclk, wptr_meta} <= {wptr_meta, wptr_gray};
        end
    end

endmodule
