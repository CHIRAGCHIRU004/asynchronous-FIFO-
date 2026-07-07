// =============================================================================
// File        : fifo_mem.v
// Description : Simple dual-port RAM used as the storage element for the
//               asynchronous FIFO. Write port is clocked by wclk, read port
//               is asynchronous (combinational read) which is standard for
//               the classic Cummings-style async FIFO architecture.
// =============================================================================

module fifo_mem #(
    parameter DSIZE = 8,   // data width
    parameter ASIZE = 4    // address width -> depth = 2^ASIZE
)(
    input                   wclk,
    input                   wclk_en,
    input                   wfull,
    input      [ASIZE-1:0]  waddr,
    input      [DSIZE-1:0]  wdata,

    input      [ASIZE-1:0]  raddr,
    output     [DSIZE-1:0]  rdata
);

    localparam DEPTH = 1 << ASIZE;

    reg [DSIZE-1:0] mem [0:DEPTH-1];

    assign rdata = mem[raddr];

    always @(posedge wclk) begin
        if (wclk_en && !wfull)
            mem[waddr] <= wdata;
    end

endmodule
