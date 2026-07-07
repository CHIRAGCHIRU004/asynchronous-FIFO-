`timescale 1ns/1ps
// =============================================================================
// File        : async_fifo_tb.v
// Description : Self-checking testbench for the parameterized asynchronous
//               FIFO. Two independent, free-running clocks with unrelated
//               periods emulate a real multi-clock system. A software
//               reference queue tracks expected data so every value read out
//               of the DUT is checked against the value that should come out
//               next.
//
//               Coverage:
//                 1. Reset behavior (wfull=0, rempty=1)
//                 2. Overflow  - write into a full FIFO, verify no corruption
//                 3. Underflow - read from an empty FIFO, verify no corruption
//                 4. Boundary / pointer wraparound - many randomized
//                    back-to-back writes & reads that wrap the pointers
//                    several times around the buffer
// =============================================================================

module async_fifo_tb;

    // ------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------
    localparam DSIZE = 8;
    localparam ASIZE = 4;
    localparam DEPTH = 1 << ASIZE;

    // ------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------
    reg              wclk, wrst_n, winc;
    reg  [DSIZE-1:0] wdata;
    wire             wfull;

    reg              rclk, rrst_n, rinc;
    wire [DSIZE-1:0] rdata;
    wire             rempty;

    integer error_count;
    integer write_count, read_count;

    // ------------------------------------------------------------------
    // Reference model (software golden queue)
    // ------------------------------------------------------------------
    reg [DSIZE-1:0] ref_q [0:4095];
    integer ref_head, ref_tail, ref_count;

    task ref_push(input [DSIZE-1:0] d);
        begin
            ref_q[ref_tail] = d;
            ref_tail = (ref_tail + 1) % 4096;
            ref_count = ref_count + 1;
        end
    endtask

    task ref_pop(output [DSIZE-1:0] d);
        begin
            d = ref_q[ref_head];
            ref_head = (ref_head + 1) % 4096;
            ref_count = ref_count - 1;
        end
    endtask

    // ------------------------------------------------------------------
    // DUT instantiation
    // ------------------------------------------------------------------
    async_fifo #(
        .DSIZE (DSIZE),
        .ASIZE (ASIZE)
    ) dut (
        .wclk   (wclk),
        .wrst_n (wrst_n),
        .winc   (winc),
        .wdata  (wdata),
        .wfull  (wfull),

        .rclk   (rclk),
        .rrst_n (rrst_n),
        .rinc   (rinc),
        .rdata  (rdata),
        .rempty (rempty)
    );

    // ------------------------------------------------------------------
    // Independent, free-running, asynchronous clocks
    // ------------------------------------------------------------------
    initial wclk = 0;
    always  #5  wclk = ~wclk;     // 100 MHz write clock

    initial rclk = 0;
    always  #7  rclk = ~rclk;     // ~71.4 MHz read clock (unrelated period)

    // ------------------------------------------------------------------
    // Write-side monitor: whatever the DUT actually accepts gets pushed
    // into the reference model. Sampling here sees pre-update (NBA) values
    // of wfull, matching exactly what the DUT's own write gating used.
    // ------------------------------------------------------------------
    always @(posedge wclk) begin
        if (wrst_n && winc && !wfull) begin
            ref_push(wdata);
            write_count = write_count + 1;
        end
    end

    // ------------------------------------------------------------------
    // Read-side monitor / checker: whatever the DUT actually reads gets
    // popped from the reference model and compared against rdata.
    // ------------------------------------------------------------------
    reg [DSIZE-1:0] expected_data;
    always @(posedge rclk) begin
        if (rrst_n && rinc && !rempty) begin
            ref_pop(expected_data);
            read_count = read_count + 1;
            if (expected_data !== rdata) begin
                error_count = error_count + 1;
                $display("[%0t] ERROR: data mismatch. expected=%0h got=%0h (read #%0d)",
                          $time, expected_data, rdata, read_count);
            end
        end
    end

    // ------------------------------------------------------------------
    // Underflow guard (whitebox check): if the DUT is empty, its internal
    // binary read pointer must not advance even if rinc is asserted.
    // ------------------------------------------------------------------
    always @(posedge rclk) begin
        if (rrst_n && rempty && rinc) begin
            if (dut.u_rptr_empty.rbin_next !== dut.u_rptr_empty.rbin) begin
                error_count = error_count + 1;
                $display("[%0t] ERROR: read pointer advanced while FIFO was empty (underflow)", $time);
            end
        end
    end

    // ------------------------------------------------------------------
    // Random stimulus helpers
    // ------------------------------------------------------------------
    reg [DSIZE-1:0] wdata_seed;

    task automatic drive_write(input want_write);
        begin
            @(negedge wclk);
            winc  = want_write;
            wdata = wdata_seed;
            if (want_write) wdata_seed = wdata_seed + 1;
        end
    endtask

    task automatic drive_read(input want_read);
        begin
            @(negedge rclk);
            rinc = want_read;
        end
    endtask

    integer i;

    initial begin
        // ---------------- Init ----------------
        error_count  = 0;
        write_count  = 0;
        read_count   = 0;
        ref_head     = 0;
        ref_tail     = 0;
        ref_count    = 0;
        wdata_seed   = 8'h01;

        winc   = 0;
        rinc   = 0;
        wdata  = 0;
        wrst_n = 0;
        rrst_n = 0;

        // Hold reset for a few cycles of each clock, released at slightly
        // different times to emulate real independent-domain resets.
        #23  wrst_n = 1;
        #31  rrst_n = 1;

        // ---------------- Phase 0: reset sanity ----------------
        @(posedge wclk);
        if (wfull !== 1'b0) begin
            error_count = error_count + 1;
            $display("ERROR: wfull not deasserted after reset");
        end
        @(posedge rclk);
        if (rempty !== 1'b1) begin
            error_count = error_count + 1;
            $display("ERROR: rempty not asserted after reset");
        end
        $display("[%0t] Phase 0 (reset) complete.", $time);

        // ---------------- Phase 1: overflow test ----------------
        // Hold reads off, hammer writes well past DEPTH, confirm wfull
        // asserts and only DEPTH words are ever accepted.
        rinc = 0;
        for (i = 0; i < DEPTH + 8; i = i + 1)
            drive_write(1'b1);
        drive_write(1'b0);

        @(posedge wclk);
        if (wfull !== 1'b1) begin
            error_count = error_count + 1;
            $display("ERROR: wfull did not assert after overflow attempt");
        end
        if (write_count !== DEPTH) begin
            error_count = error_count + 1;
            $display("ERROR: expected exactly %0d accepted writes before full, got %0d",
                      DEPTH, write_count);
        end
        $display("[%0t] Phase 1 (overflow) complete. accepted_writes=%0d wfull=%0b",
                  $time, write_count, wfull);

        // ---------------- Phase 2: drain & underflow test ----------------
        // Drain the FIFO completely, then keep asserting rinc while empty.
        for (i = 0; i < DEPTH + 8; i = i + 1)
            drive_read(1'b1);
        drive_read(1'b0);

        @(posedge rclk);
        if (rempty !== 1'b1) begin
            error_count = error_count + 1;
            $display("ERROR: rempty did not assert after full drain");
        end
        if (read_count !== DEPTH) begin
            error_count = error_count + 1;
            $display("ERROR: expected exactly %0d reads to drain FIFO, got %0d",
                      DEPTH, read_count);
        end
        $display("[%0t] Phase 2 (underflow) complete. total_reads=%0d rempty=%0b",
                  $time, read_count, rempty);

        // ---------------- Phase 3: boundary / wraparound stress ----------------
        // Randomized concurrent writer/reader for many transactions, forcing
        // the pointers around the buffer multiple times.
        fork
            begin : writer
                integer n;
                for (n = 0; n < 500; n = n + 1) begin
                    drive_write($random % 4 != 0);  // ~75% write activity
                end
                drive_write(1'b0);
            end
            begin : reader
                integer n;
                for (n = 0; n < 500; n = n + 1) begin
                    drive_read($random % 3 != 0);   // ~66% read activity
                end
                drive_read(1'b0);
            end
        join

        // Let things settle, then drain whatever remains so the reference
        // model empties out and every remaining word gets checked.
        repeat (5) @(posedge wclk);
        while (ref_count > 0) begin
            drive_read(1'b1);
        end
        drive_read(1'b0);
        repeat (10) @(posedge rclk);

        $display("[%0t] Phase 3 (boundary/wraparound) complete. total_writes=%0d total_reads=%0d",
                  $time, write_count, read_count);

        // ---------------- Summary ----------------
        if (ref_count !== 0) begin
            error_count = error_count + 1;
            $display("ERROR: reference model not empty at end of test (ref_count=%0d)", ref_count);
        end

        $display("=====================================================");
        if (error_count == 0)
            $display("TEST PASSED: %0d writes / %0d reads, 0 mismatches.", write_count, read_count);
        else
            $display("TEST FAILED: %0d error(s) detected.", error_count);
        $display("=====================================================");

        $finish;
    end

    // Safety timeout
    initial begin
        #200000;
        $display("ERROR: TESTBENCH TIMEOUT");
        $finish;
    end

endmodule
