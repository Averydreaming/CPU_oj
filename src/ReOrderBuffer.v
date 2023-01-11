`include "defines.v"

module  ReOrderBuffer (
     input  wire              clk,
    input  wire              rst,
    input  wire              rdy,

    // 每个周期 从 decoder 读入一条指令，更新 ROB R[rd] reorder
    input  wire             instr_valid,
    input  wire [4:0]       rd,  // 目标寄存器
    input  wire [5:0]       opcode_ID,  // opcode_ID
    input  wire [31:0]      instr_jump_wrong_to_pc,
    input  wire             is_jump,

    output wire              update_ROB_valid,// to RegFile 新的指令写入寄存器
    output wire [3:0]        update_ROB_pos,
    output wire [4:0]        update_ROB_rd,
    //完善decoder指令信息, 每个周期 从 decoder 读入一条指令，进行rename
    input  wire [3:0]       rs1_ROB_pos,
    input  wire [3:0]       rs2_ROB_pos, 
    output wire              rs1_ready,
    output wire              rs2_ready,
    output wire [31:0]       reg1,
    output wire [31:0]       reg2,



    //每个周期 commit 一条指令
    output wire              commit_valid,// to RegFile 是否 commit 了一条指令写寄存器
    output wire [3:0]        commit_ROB_pos,
    output wire [4:0]        commit_dest,
    output wire [31:0]       commit_value,

    //处理 RS/LSB 改变产生的影响
    input  wire             RS_update,                              
    input  wire [3:0]       RS_ROB_pos,                                 
    input  wire [31:0]      RS_val,

    input  wire             LSB_Load_update,//LSB是否更新处理了load指令
    input  wire [3:0]       LSB_Load_ROB_pos,
    input  wire [31:0]      LSB_Load_val,
    output wire             commit_store,
    //一些细节信息
   
    output reg              jump_wrong,
    output reg  [31:0]      jump_wrong_to_pc,
    output reg              SB_commit,
    output wire              ROB_FULL,
    output reg  [3:0]       front,
    output reg  [3:0]       rear    
);

    reg             full;                                         

    reg  [15:0]    ready;                                           
    reg  [15:0]    isjump;                                       
    reg  [31:0]    val        [15:0];                              
    reg  [4:0]     dest       [15:0];                               
    reg  [5:0]     inst       [15:0];                                

    reg             jalr_flag;                                      
    reg  [4:0]      jalr_idx;                                           
    reg  [31:0]     jalr_pc;                                           


    integer i;

    always @(posedge clk) begin
        

        if (rst || jump_wrong) begin
            jump_wrong <=0;
            SB_commit <=0;
            jump_wrong_to_pc<=0;
            full <=0;
            front<=0;
            rear<=0;
            jalr_flag <=0;
            jalr_idx<=0;
            jalr_pc<=0; 
            ready<=0;
        end
        else if (!rdy) begin
            
        end
        else begin
            full<=ready[front] ? (full && instr_valid)  : (full || (instr_valid && (front == (-(~rear)))));

            if (instr_valid) begin
                rear<=-(~rear);
                ready[rear]<=(opcode_ID == `SB || opcode_ID == `SH || opcode_ID == `SW || opcode_ID == `JAL || opcode_ID == `LUI || opcode_ID == `AUIPC);
                isjump[rear]<=is_jump;
                val[rear]<=instr_jump_wrong_to_pc;
                dest[rear]<=rd;
                inst[rear]<=opcode_ID;

                if (opcode_ID == `JALR && jalr_flag ==0) begin
                    jalr_flag<=1;
                    jalr_idx<=rear;
                    jalr_pc<=0; 
                end
            end
            

            if (full || front != rear) begin
                if (ready[front]) begin
                    front<=-(~front);
                end

                if (inst[front] == `JALR) begin
                    SB_commit <=0;

                    if (ready[front]) begin
                        jump_wrong<=1;
                        jump_wrong_to_pc<=jalr_pc;
                    end
                    
                    if (RS_update && RS_ROB_pos == front) begin
                        jump_wrong<=1;
                        jump_wrong_to_pc<=RS_val;
                    end
                end
                else if (inst[front][5] && inst[front] != `JAL) begin
                    SB_commit<=ready[front] || (RS_update && RS_ROB_pos == front && isjump[front] != RS_val[0]);

                    if (ready[front] && isjump[front]) begin
                        jump_wrong<=1;
                        jump_wrong_to_pc<=val[front];
                    end

                    if (RS_update && RS_ROB_pos == front && isjump[front] != RS_val[0]) begin
                        jump_wrong<=1;
                        jump_wrong_to_pc<=val[front];
                    end
                end
                else begin
                    SB_commit <=0;
                end
            end
            else begin
                SB_commit <=0;
            end

            if (RS_update) begin
                ready[RS_ROB_pos]<=1;
                if (inst[RS_ROB_pos][5] && !inst[RS_ROB_pos][4]) begin
                    isjump[RS_ROB_pos]<=isjump[RS_ROB_pos] != RS_val[0];
                end 
                else begin
                    val[RS_ROB_pos]<=RS_val;
                end
                
                if (RS_ROB_pos == jalr_idx && inst[RS_ROB_pos] == `JALR) begin
                    jalr_pc<=RS_val;
                end
            end

            if (LSB_Load_update) begin
                ready[LSB_Load_ROB_pos]<=1;
                val[LSB_Load_ROB_pos]<=LSB_Load_val;
            end
        end
    end
    
    assign ROB_FULL=ready[front] ? (full && instr_valid)  : (full || (instr_valid && (front == (-(~rear)))));

    assign rs1_ready=ready[rs1_ROB_pos];
    assign rs2_ready=ready[rs2_ROB_pos];
    assign reg1=ready[rs1_ROB_pos] ? val[rs1_ROB_pos] : rs1_ROB_pos;
    assign reg2=ready[rs2_ROB_pos] ? val[rs2_ROB_pos] : rs2_ROB_pos;

    
    assign update_ROB_valid=instr_valid ? (rd != 0) :0;
    assign update_ROB_pos=rear;
    assign update_ROB_rd=rd;

    assign commit_store=(full || front != rear) && (inst[front] == `SB || inst[front] == `SH || inst[front] == `SW);
    assign commit_valid=(full || front != rear) && ready[front] && (!inst[front][5] || inst[front] == `JAL || inst[front] == `JALR);
    assign commit_ROB_pos=front;
    assign commit_dest=dest[front];
    assign commit_value=val[front];

endmodule