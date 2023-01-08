`ifndef REGFILE
`define REGFILE
`include "op_map.v"

//相当于 PPCA reg

module RegFile (
    input  wire              clk,
    input  wire              rst,
    input  wire              rdy,
//一个周期处理一次 decoder里 （rd代表在reg中编号）知道rd 返回reg状态 (通过CDB传递)
    input  wire [ 4: 0]     rs1,
    input  wire [ 4: 0]     rs2,
    output reg             reg1_ready,
    output reg             reg2_ready,
    output reg [31: 0]     reg1,
    output reg [31: 0]     reg2,

    output reg [ 3: 0]     reg1_reorder_ROB_pos, //to ROB
    output reg [ 3: 0]     reg2_reorder_ROB_pos,


//一个周期处理 ROB一次 commit
    input  wire             commit_valid,
    input  wire [ 3: 0]     commit_ROB_pos,
    input  wire [ 4: 0]     commit_rd,
    input  wire [31: 0]     commit_val,
//一个周期处理一条指令进入ROB （update）
    input  wire             update_valid,
    input  wire [ 3: 0]     update_ROB_pos,
    input  wire [ 4: 0]     update_rd,

    input  wire             jump_wrong
);

    reg  [31: 0]    Reg_reg     [31: 0];
    reg  [ 3: 0]    Reg_reorder [31: 0];
    reg  [31: 0]Reg_busy ; //(1还未被commit 0commit完了)
    always @(*) begin
        reg1_ready=1-Reg_busy[rs1];
        reg2_ready=1-Reg_busy[rs2];
        reg1=Reg_reg[rs1];
        reg2=Reg_reg[rs2];
        reg1_reorder_ROB_pos=Reg_reorder[rs1];
        reg2_reorder_ROB_pos=Reg_reorder[rs2];
    end
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            Reg_busy<=0;
            for (i = 0; i < 32; i = i + 1) Reg_reg[i]<=0;
        end
        else begin
            if (jump_wrong) begin
                Reg_busy<=0;
            end
            else if (rdy) begin
            //处理 commit
                if (commit_valid && commit_rd) begin
                    Reg_reg[commit_rd]<=commit_val;
                    Reg_busy[commit_rd]<=!(Reg_reorder[commit_rd]==commit_ROB_pos && update_rd!=commit_rd);  
                end
            //处理刚刚进入ROB的指令
                if (update_valid && update_rd) begin
                    Reg_busy[update_rd]<=1;
                    Reg_reorder[update_rd]<=update_ROB_pos;
                end
            end
        end
    end

endmodule
`endif