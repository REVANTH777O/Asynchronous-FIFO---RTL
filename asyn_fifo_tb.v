module tb_asynch_fifo();

    // Inputs to UUT
    reg reset;
    reg wr_clk;
    reg rd_clk;
    reg wr_enb;
    reg rd_enb;
    reg [15:0] fifo_din;

    // Outputs from UUT
    wire [15:0] fifo_dout;
    wire full;
    wire empty;
    
    // Loop variable
    integer i;

    // Instantiate Unit Under Test (UUT)
    asynch_fifo uut (
        .reset(reset),
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .wr_enb(wr_enb),
        .rd_enb(rd_enb),
        .fifo_din(fifo_din),
        .fifo_dout(fifo_dout),
        .full(full),
        .empty(empty)
    );

    // Generate 100 MHz Write Clock (Period = 10ns -> Toggle every 5ns)
    always begin
        #5 wr_clk = ~wr_clk;
    end

    // Generate 4 MHz Read Clock (Period = 250ns -> Toggle every 125ns)
    always begin
        #125 rd_clk = ~rd_clk;
    end

    // Test Stimulus
    initial begin
        // Initialize Inputs
        wr_clk   = 0;
        rd_clk   = 0;
        reset    = 1;
        wr_enb   = 0;
        rd_enb   = 0;
        fifo_din = 0;

        // Apply Reset for 300ns (Ensures both clock domains catch the reset)
        #10;
        reset = 0;
        #10;
        
        $display("--- Starting Asynchronous FIFO Verification ---");
        
        // --- TEST 1: Write 16 consecutive known values to fill the FIFO ---
        @(posedge wr_clk);
        for(i = 1; i <= 16; i = i + 1) begin
            wr_enb   = 1;
            fifo_din = i * 10; // Values: 10, 20, 30... 160
            @(posedge wr_clk);
        end
        wr_enb = 0; // Turn off write enable
        
        // Wait a few cycles for synchronization delay to update the Full Flag
        repeat(5) @(posedge wr_clk);
        if (full) 
            $display("[SUCCESS] FIFO is FULL as expected.");
        else 
            $display("[ERROR] FIFO failed to report FULL flag.");

        // --- TEST 2: Read back the 16 values ---
        @(posedge rd_clk);
        for(i = 1; i <= 16; i = i + 1) begin
            rd_enb = 1;
            @(posedge rd_clk);
            $display("At time %t: Read Data = %d", $time, fifo_dout);
        end
        rd_enb = 0; // Turn off read enable

        // Wait a few cycles for synchronization delay to update the Empty Flag
        repeat(5) @(posedge rd_clk);
        if (empty) 
            $display("[SUCCESS] FIFO is EMPTY as expected.");
        else 
            $display("[ERROR] FIFO failed to report EMPTY flag.");

        $display("--- Verification Completed ---");
        $finish;
    end

endmodule