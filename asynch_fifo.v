`timescale 1ns / 1ps

//==============================================================================
// ASYNCHRONOUS FIFO DESIGN
//==============================================================================
module asynch_fifo (
    // 1. Port Declaration
    input reset,
    input wr_clk,
    input rd_clk,
    input wr_enb,
    input rd_enb,
    input [15:0] fifo_din,
    
    output reg [15:0] fifo_dout,
    output full,
    output empty
);

    // 2. Internal Registers
    // Memory Array (Depth = 16, Width = 16)
    reg [15:0] mem[0:15];
    
    // Binary Pointers (5 bits to track full/empty conditions for 16 deep FIFO)
    reg [4:0] wr_ptr_bin;
    reg [4:0] rd_ptr_bin;
    
    // Gray Pointers
    reg [4:0] wr_ptr_gray;
    reg [4:0] rd_ptr_gray;
    
    // Synchronizer Registers (2-stage Flip-Flops for Cross Clock Domain)
    reg [4:0] rd_gray_sync1, rd_gray_sync2;
    reg [4:0] wr_gray_sync1, wr_gray_sync2;

    // 3. Next Pointer Logic
    wire [4:0] wr_bin_next;
    wire [4:0] wr_gray_next;
    wire [4:0] rd_bin_next;
    wire [4:0] rd_gray_next;
    
    // Look-ahead calculation for next write binary and gray pointers
    assign wr_bin_next  = wr_ptr_bin + 5'd1;
    assign wr_gray_next = wr_bin_next ^ (wr_bin_next >> 1);
    
    // Look-ahead calculation for next read binary and gray pointers
    assign rd_bin_next  = rd_ptr_bin + 5'd1;
    assign rd_gray_next = rd_bin_next ^ (rd_bin_next >> 1);

    // 4. Write Logic
    always @(posedge wr_clk or posedge reset) begin
        if (reset) begin
            wr_ptr_bin  <= 5'd0;
            wr_ptr_gray <= 5'd0;
        end 
        else if (wr_enb && !full) begin
            mem[wr_ptr_bin[3:0]] <= fifo_din; // Lower 4 bits map to 0-15 memory index
            wr_ptr_bin           <= wr_bin_next;
            wr_ptr_gray          <= wr_gray_next;
        end
    end

    // 5. Read Logic
    always @(posedge rd_clk or posedge reset) begin
        if (reset) begin
            rd_ptr_bin  <= 5'd0;
            rd_ptr_gray <= 5'd0;
            fifo_dout   <= 16'd0;
        end 
        else if (rd_enb && !empty) begin
            fifo_dout   <= mem[rd_ptr_bin[3:0]]; // Lower 4 bits map to 0-15 memory index
            rd_ptr_bin  <= rd_bin_next;
            rd_ptr_gray <= rd_gray_next;
        end
    end

    // 6. Synchronizer Logic
    // Passing Read Pointer (Gray) into Write Clock Domain
    always @(posedge wr_clk or posedge reset) begin
        if (reset) begin
            rd_gray_sync1 <= 5'd0;
            rd_gray_sync2 <= 5'd0;
        end else begin
            rd_gray_sync1 <= rd_ptr_gray;
            rd_gray_sync2 <= rd_gray_sync1;
        end
    end

    // Passing Write Pointer (Gray) into Read Clock Domain
    always @(posedge rd_clk or posedge reset) begin
        if (reset) begin
            wr_gray_sync1 <= 5'd0;
            wr_gray_sync2 <= 5'd0;
        end else begin
            wr_gray_sync1 <= wr_ptr_gray;
            wr_gray_sync2 <= wr_gray_sync1;
        end
    end

    // 7. Empty Logic
    // FIFO is empty if the local read gray pointer matches synchronized write gray pointer
    assign empty = (rd_ptr_gray == wr_gray_sync2);

    // 8. Full Logic
    // FIFO is full if the MSB and MSB-1 are inverted, while the rest of the bits match
    assign full = (wr_ptr_gray == {~rd_gray_sync2[4], ~rd_gray_sync2[3], rd_gray_sync2[2:0]});

endmodule