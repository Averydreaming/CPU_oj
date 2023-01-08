`ifndef LSB
`define LSB
`include "op_map.v"

//1、每个周期calc一条指令
//2、每个周期读入一条指令
//store 操作要等commit之后才能操作
//load 操作在commit的时候写入寄存器
module LoadStoreBuffer(
    input  wire             clk, rst, rdy,
    // 这一周期需要处理的指令 from decoder
    input  wire            update_Decoder_valid,//是否需要处理

    input  wire [5:0]       opcode_ID, //From IF
    input  wire             reg1_ready,
    input  wire             reg2_ready,
    input  wire [31:0]      reg1,//不存在就显示在ROB中的编号
    input  wire [31:0]      reg2,
    input  wire [31:0]      imm,
    
    input  wire [3:0]       ROB_pos, //from ROB  新指令在 ROB 中的编号
    input  wire [3:0]       ROB_front,
    input  wire             store_is_commit,


    //memctrl有空时执行一条指令
    input wire              memctrl_update_finished,
    input wire [31:0]       memctrl_update_value,
    output reg [31:0]       mem_address,
    output reg [5:0]        LS_opcode_ID,
    output reg  [31:0]      LS_value,
    //load
    output reg              update_Load,
    output reg              update_Store,
    output reg              update_LoadStore,

    // 其他容器在上一周期是否发来更新
    input  wire             update_RS_valid,//from RS
    input  wire [3:0]       update_RS_ROB_pos,
    input  wire [31:0]      update_RS_val,
    //更新其他
    output reg              Load_instr_valid,
    output reg  [3:0]       Load_ROB_pos,
    output reg  [31:0]      Load_val,

    output reg              LSB_FULL,
    input  wire             jump_wrong

);

    reg            update_reg1_ready;
    reg            update_reg2_ready;
    reg [31:0]     update_reg1;
    reg [31:0]     update_reg2;
    reg [31:0]     update_imm;

    reg  [5:0]     LSB_opcode_id         [15:0];
    reg  [15:0]    LSB_rs1               [15:0];
    reg  [15:0]    LSB_rs2               [15:0];
    reg  [15:0]    LSB_rs1_ready;
    reg  [15:0]    LSB_rs2_ready;
    reg  [15:0]    LSB_commit;
    reg  [31:0]    LSB_reg1              [15:0];
    reg  [31:0]    LSB_reg2              [15:0];
    reg  [31:0]    LSB_imm               [15:0];
    reg  [3:0]     LSB_ROB_pos           [31:0];
    reg            LSB_full;
    reg  [3:0]     LSB_front;
    reg  [3:0]     LSB_rear;
    reg  [3:0]     commit_amount;
/*
    reg             full;
    reg  [`LSID]    front, rear, commit_amount;

    reg  [ 2: 0]    ins         [`LSSZ];
    reg  [`LSSZ]    val1_ready, val2_ready, iscommit;
    reg  [`RLEN]    val1        [`LSSZ];
    reg  [`RLEN]    val2        [`LSSZ];
    reg  [`RLEN]    val_imm     [`LSSZ];
    reg  [`RBID]    ROB_idx     [`LSSZ];

*/

    always @(*) begin
        update_reg1=reg1; update_reg1_ready=reg1_ready;
        if (update_RS_valid && !update_reg1_ready && update_reg1[3:0] == update_RS_ROB_pos) begin
            update_reg1=update_RS_val; update_reg1_ready=1;
        end else if (Load_instr_valid && !update_reg1_ready && update_reg1[3:0] == Load_ROB_pos) begin
            update_reg1=Load_val; update_reg1_ready=1;
        end

        update_reg2=reg2; update_reg2_ready=reg2_ready;
        if (update_RS_valid && !update_reg2_ready && update_reg2[3:0] == update_RS_ROB_pos) begin
            update_reg2=update_RS_val; update_reg2_ready=1;
        end else if (Load_instr_valid && !update_reg2_ready && update_reg2[3:0] == Load_ROB_pos) begin
            update_reg2=Load_val; update_reg2_ready=1;
        end
    end
    integer i;
    always @(posedge clk) begin
        //将这一周期的新指令放入下一周期的LSB
        if (rst)  begin
            LSB_full<=0;
            LSB_front<=0;
            LSB_rear<=0;
            LSB_rs1_ready<=0;
            LSB_rs2_ready<=0;
            commit_amount<=0;
            LSB_commit<=0;
        end
        if (!rst && rdy  && jump_wrong) begin
            LSB_full<=!memctrl_update_finished && commit_amount==16;
            LSB_rear<=LSB_front+commit_amount+(memctrl_update_finished &&  opcode_ID>=11 &&  opcode_ID<=15);//UPDATE LOAD
            if (memctrl_update_finished) LSB_front<=-(~LSB_front);
            commit_amount<=commit_amount+store_is_commit-(memctrl_update_finished &&  opcode_ID>=16 &&  opcode_ID<=18);
        end
        if (!rst && rdy && !jump_wrong)
        begin
             //memctrl执行完一条指令
            if (memctrl_update_finished) LSB_front<=-(~LSB_front);
            commit_amount<=commit_amount+store_is_commit-(memctrl_update_finished &&  opcode_ID>=16 &&  opcode_ID<=18);
            if (store_is_commit) LSB_commit[front+commit_amount]<=1;//store commit的时候LSB里面的load肯定已经执行完了
            //输入decoder中的一条指令

            if (update_Decoder_valid) begin
                LSB_rear<=-(~LSB_rear);
                LSB_rs1_ready[LSB_rear]<=update_reg1_ready;
                LSB_rs2_ready[LSB_rear]<=update_reg2_ready;
                LSB_ROB_pos[LSB_rear]<=ROB_pos;
                LSB_opcode_id[LSB_rear]<=opcode_ID;
                LSB_reg1[LSB_rear]<=update_reg1;
                LSB_reg2[LSB_rear]<=update_reg2;
                LSB_imm[LSB_rear]<=imm;
                LSB_commit[LSB_rear]<=0;
            end

            //用这一周期计算完的指令更新下一周期的LSB
            for (i = 0; i < 16; i = i + 1)
            if (LSB_full || i!=LSB_rear) begin
                if (update_RS_valid && !LSB_rs1_ready[i] && LSB_reg1[i][3:0] == update_RS_ROB_pos) begin
                LSB_reg1[i]<=update_RS_val; LSB_rs1_ready[i]<=1;
                end
                if (update_RS_valid && !LSB_rs2_ready[i] && LSB_reg2[i][3:0] == update_RS_ROB_pos) begin
                LSB_reg2[i]<=update_RS_val; LSB_rs2_ready[i]<=1;
                end
                if (Load_instr_valid && !LSB_rs1_ready[i] && LSB_reg1[i][3:0] == Load_ROB_pos) begin
                LSB_reg1[i]<=Load_val; LSB_rs1_ready[i]<=1;
                end
                if (Load_instr_valid && !LSB_rs2_ready[i] && LSB_reg2[i][3:0] == Load_ROB_pos) begin
                LSB_reg2[i]<=Load_val; LSB_rs2_ready[i]<=1;
                end
            end
        end
    end
//输出一条指令  到ROB and Memctrl
    reg  [3:0]     front;
    reg  exist_element;
    wire [31: 0]    now_address;
    always @(*) begin
        if (memctrl_update_finished) front=-(~LSB_front); else front=LSB_front;
        exist_element=(LSB_full || front!=LSB_rear);
        mem_address=LSB_reg1[front]+LSB_imm[front];
        LS_opcode_ID=LSB_opcode_id[front];
        LS_value=LSB_reg2[front];
        update_Load=0;
        update_Store=0;
        if (exist_element &&  LSB_rs1_ready[front] && LSB_rs2_ready[front] && rdy) begin
             if (LSB_opcode_id[front]>=16 &&  LSB_opcode_id[front]<=18) update_Store=LSB_commit[front];
                else update_Load=(mem_address[17:16]==3) ? (ROB_pos[front]==ROB_front && !jump_wrong) :1;
        end
        update_LoadStore=update_Load||update_Store;
    end
    always @(*) begin
        if (memctrl_update_finished  && LSB_opcode_id[LSB_front]>=11 && LSB_opcode_id[LSB_front]<=15) Load_instr_valid=1; else Load_instr_valid=0;
        Load_ROB_pos=LSB_ROB_pos[LSB_front];
        Load_val=LS_value;
    end
    always @(*) begin
       LSB_FULL=memctrl_update_finished ? (LSB_full && update_Decoder_valid) : (LSB_full || (update_Decoder_valid && (LSB_front == (-(~LSB_rear)))));
    end
endmodule
`endif