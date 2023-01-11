`include "defines.v"

module RegFile (
    input  wire             clk, rst, rdy, jump_wrong, 

    // Decoder
    input  wire [ 4: 0]     rs1, rs2, 
    output wire             reg1_ready, reg2_ready, 
    output wire [31: 0]     reg1, reg2, 

    // ROB
    input  wire             update_valid, 
    input  wire             commit_valid,  
    input  wire [ 3: 0]     update_ROB_pos, commit_ROB_pos, 
    input  wire [ 4: 0]     update_rd, commit_rd, 
    input  wire [31: 0]     commit_val, 
    output wire [ 3: 0]     reg1_reorder_ROB_pos, 
    output wire [ 3: 0]     reg2_reorder_ROB_pos
);
    reg  [31: 0]    Reg_reg     [31: 0];
    reg  [31: 0]    Reg_busy;
    reg  [ 3: 0]    Reg_reorder    [31: 0];

    assign reg1_ready=Reg_busy[rs1];
    assign reg2_ready=Reg_busy[rs2];
    assign reg1=Reg_reg[rs1];
    assign reg2=Reg_reg[rs2];
    assign reg1_reorder_ROB_pos=Reg_reorder[rs1];
    assign reg2_reorder_ROB_pos=Reg_reorder[rs2];

    integer i;
    reg [31: 0] debug_now;
    always @(posedge clk) begin
        debug_now<=debug_now + 1;
        if (rst)
            debug_now<=0;
        if (rst) begin
            Reg_busy<=~(0);
            for (i=0; i < 32; i=i + 1)
                Reg_reg[i]<=0;
        end
        else if (!rdy) begin
            
        end
        else begin
            if (jump_wrong) begin
                Reg_busy<=~(0);
            end
            else begin
                if (commit_valid && commit_rd) begin
                    Reg_reg[commit_rd]<=commit_val;
                    Reg_busy[commit_rd]<=(Reg_reorder[commit_rd] == commit_ROB_pos && commit_rd != update_rd);
                end

                if (update_valid && update_rd) begin
                    Reg_busy[update_rd] <=0;
                    Reg_reorder[update_rd]<=update_ROB_pos;
                end 
            end 
        end
        
    end
    
endmodule