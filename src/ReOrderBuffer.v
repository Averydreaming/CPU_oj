//每个周期 从 decoder 读入一条指令，进行rename
//处理 LSB/RS 改变产生的影响
//每个周期 commit 一条指令
`ifndef ROB
`define ROB
module ReOrderBuffer (
    input  wire              clk,
    input  wire              rst,
    input  wire              rdy,

    // 每个周期 从 decoder 读入一条指令，更新 ROB R[rd] reorder
    input  wire             instr_valid,
    input  wire [4:0]       rd,  // 目标寄存器
    input  wire [5:0]       opcode_ID,  // opcode_ID

    output reg              update_ROB_valid,// to RegFile 新的指令写入寄存器
    output reg [3:0]        update_ROB_pos,
    output reg [4:0]        update_ROB_rd,
    //完善decoder指令信息, 每个周期 从 decoder 读入一条指令，进行rename
    input  wire [3:0]       rs1_ROB_pos,
    input  wire [3:0]       rs2_ROB_pos, 
    output reg              rs1_ready,
    output reg              rs2_ready,
    output reg [31:0]       reg1,
    output reg [31:0]       reg2,



    //每个周期 commit 一条指令
    output reg              commit_valid,// to RegFile 是否 commit 了一条指令写寄存器
    output reg [3:0]        commit_ROB_pos,
    output reg [4:0]        commit_dest,
    output reg [31:0]       commit_value,

    //处理 RS/LSB 改变产生的影响
    input  wire             RS_update,                              
    input  wire [3:0]       RS_ROB_pos,                                 
    input  wire [31:0]      RS_val,

    input  wire             LSB_Load_update,//LSB是否更新处理了load指令
    input  wire [3:0]       LSB_Load_ROB_pos,
    input  wire [31:0]      LSB_Load_val,
    output wire             commit_store,
    //一些细节信息
    input wire              is_jump,
    output reg              jump_wrong,
    output reg  [31:0]      jump_wrong_to_pc,
    output reg             ROB_FULL,
    output reg  [3:0]       front,
    output reg  [3:0]       rear
);
/*

wire [3:0]   RegFile_output_reg1_ROB_pos_to_ROB;
wire [3:0]   RegFile_output_reg2_ROB_pos_to_ROB;
wire         ReOrderBuffer_commit_valid_to_RegFile;// to RegFile 是否 commit 了一条指令写寄存器
wire [3:0]   ReOrderBuffer_commit_ROB_pos_to_RegFile;
wire [4:0]   ReOrderBuffer_commit_rd_to_RegFile;
wire [31:0]  ReOrderBuffer_commit_val_to_RegFile;
wire         ReOrderBuffer_update_valid_to_RegFile;// to RegFile 新的指令写入寄存器
wire [3:0]   ReOrderBuffer_update_ROB_pos_to_RegFile;
wire [4:0]   ReOrderBuffer_update_rd_to_RegFile;
wire         ALU_instr_valid_to_CDB;
wire [3:0]   ALU_ROB_pos_to_CDB;
wire [31:0]  ALU_val_to_CDB;
wire         Load_complete_instr_valid;/LSB是否更新处理了load指令
wire [3:0]   Load_complete_ROB_pos;
wire [31:0]  Load_complete_val;
wire         ROB_commit_store;

wire[3:0]         ReOrderBuffer_front;
wire[3:0]         ReOrderBuffer_rear;
*/

    reg            full;// ROB 是否已满
    reg  [4:0]     sz;  //当前存储多少条指令
    reg  [15:0]    ready; // 是否可以 commit
    reg  [15:0]    isjump;
    reg  [15:0]    jumpwrong;
    reg  [31:0]    val         [15:0];// ROB 中储存的值
    reg  [4:0]     dest        [15:0];// 目标寄存器的编号
    reg  [5:0]     inst        [15:0];// 保存的指令

 //update reg（每个周期有一条commit一条指令）
always @(*) begin
    commit_valid=(ROB_FULL || front != rear) && ready[front];//not null and ready
    commit_ROB_pos=front;
    commit_dest=dest[front];
    commit_value=val[front];
end
//每个周期 从 decoder 读入一条指令，更新 reg ，并且进行rename 完善指令信息
always @(*) begin
    update_ROB_valid=instr_valid ? 1:0;
    update_ROB_pos=rear;
    update_ROB_rd=rd;
    rs1_ready=ready[rs1_ROB_pos];
    rs2_ready=ready[rs2_ROB_pos];
    reg1=ready[rs1_ROB_pos]?val[rs1_ROB_pos]:rs1_ROB_pos;
    reg2=ready[rs2_ROB_pos]?val[rs2_ROB_pos]:rs2_ROB_pos;
end
always @(posedge clk) begin
        if (!rst && rdy)
            begin
            if (ready[front]) ROB_FULL<=(ROB_FULL && instr_valid); else ROB_FULL<=(ROB_FULL || (instr_valid && (front == (-(~rear)))));
            //每个周期 从 decoder 读入一条指令，放到ROB
            if (instr_valid) begin
                rear<=-(~rear);
                ready[rear]<=0;
                val[rear]<=jump_wrong_to_pc;
                isjump[rear]<=is_jump;
                dest[rear]<=rd;
                inst[rear]<=opcode_ID;
                jumpwrong[rear]<=0;
            end

            if (ROB_FULL || front != rear)
                if (ready[front]) begin
                    front<=-(~front);
                    //要处理jump错的情况
                    if (opcode_ID>=5 && opcode_ID<=10) begin
                           if (ready[front] && jumpwrong[front]) begin
                                jump_wrong <= 1;
                                jump_wrong_to_pc<= val[front];
                           end
                           if (RS_update && RS_ROB_pos==front &&  isjump[front]!=RS_val[0]) begin
                                jump_wrong <= 1;
                                jump_wrong_to_pc<= val[front];
                                end
                     //
                    end
            end

            //处理 LSB/RS 改变产生的影响(主要是更新ready)
            if (RS_update) begin
                ready[RS_ROB_pos] <= 1;
                if (opcode_ID>=5 && opcode_ID<=10)//B指令
                begin
                    jumpwrong[RS_ROB_pos]<=(isjump[rear]!=RS_val[0]);
                end
                else begin
                    val[RS_ROB_pos] <= RS_val;
                end
            end

            if (LSB_Load_update) begin
                ready[LSB_Load_ROB_pos] <= 1;
                val[LSB_Load_ROB_pos] <= LSB_Load_val;
            end
        end
    end

endmodule
`endif