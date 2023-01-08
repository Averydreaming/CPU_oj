`ifndef DECODER
`define DECODER
`include "op_map.v"

//相当于PPCA decoder+instruction send
module Decoder (
    input  wire              clk,
    input  wire              rst,
    input  wire              rdy,

     // decoder
     //每一周期从IF取一条指令，并在处理完后传到数据总线（CDB）上
   
    output wire             Decoder_not_ready_accept, 
    input  wire             ROB_full,
    input  wire             LSB_full,

    input  wire             update_instr_valid,
    input  wire [31:0]      update_instr,
    input  wire             update_instr_isjump,//TO SB 1 +imm 0 +4
    input  wire  [31: 0]    update_instr_jump_wrong_to_pc,


    output reg [4:0]       Reg_rs1, //输出寄存器地址 来查找位置from RegFile 用来处理这条指令的vj vk qj qk
    output reg [4:0]       Reg_rs2,

    input  wire             Reg_rs1_ready,
    input  wire             Reg_rs2_ready,
    input  wire [31: 0]     Reg_reg1,
    input  wire [31: 0]     Reg_reg2,
    

    input  wire             ROB_rs1_ready,
    input  wire             ROB_rs2_ready,
    input  wire [31: 0]     ROB_reg1,
    input  wire [31: 0]     ROB_reg2,


    //to CDB
    output reg  [4:0]       rd,
    output reg  [5:0]       opcode_id,
    output reg              rs1_ready, 
    output reg              rs2_ready, //代表寄存器目前是否有值
    output reg [31:0]       reg1,
    output reg [31:0]       reg2, //代表寄存器的值
    output reg [31:0]       imm,
 

    output reg              Decoder_update_LSB,  // 本次指令是否会更新其他容器
    output reg              Decoder_update_ROB,
    output reg              ROB_instr_isjump,
    output reg  [31: 0]     ROB_instr_jump_wrong_to_pc,

    output reg              Decoder_update_RS
);
/*
ALU_instr_valid_to_CDB),
ALU_ROB_pos_to_CDB),
ALU_val_to_CDB),
Load_complete_instr_valid),//LSB是否更新处理了load指令
Load_complete_ROB_pos),
Load_complete_val),
ROB_commit_store),


*/
    assign Decoder_not_ready_accept= ROB_full | LSB_full;
    reg  [31: 0]    instr;
    reg             instr_valid;
    wire [6:0]   op=instr[6:0];
    wire [2:0]   op1=instr[14:12];
    wire [6:0]   op2=instr[31:25];

    always @(*) begin
        if (instr_valid) begin
        // deal rd/rs1/rs2/opcode_id
            rd=instr[11:7];
            Reg_rs1=instr[19:15];
            Reg_rs2=instr[24:20];
            if (op==7'b0000011)   //Il
            begin
                case (op1)
                    3'b000: opcode_id=`LB;
                    3'b001: opcode_id=`LH;
                    3'b010: opcode_id=`LW;
                    3'b100: opcode_id=`LBU;
                    3'b101: opcode_id=`LHU;
                endcase
                imm={{20{instr[31]}},instr[31:20]};
            end
            if (op==7'b0010011)   //Io1
            begin
                case (op1)
                    3'b000: opcode_id=`ADDI;
                    3'b001: opcode_id=`SLLI;
                    3'b010: opcode_id=`SLTI;
                    3'b011: opcode_id=`SLTIU;
                    3'b100: opcode_id=`XORI;
                    3'b101: if (op2==0) opcode_id=`SRLI; else opcode_id=`SRAI;
                    3'b110: opcode_id=`ORI;
                    3'b111: opcode_id=`ANDI;
                endcase
                imm= {{20{instr[31]}},instr[31:20]};
                if (op1==3'b101 || op1==3'b001) imm={27'b0, instr[24:20]};
            end
            if (op==7'b1100011)
            begin
                case (op1)
                    3'b001: opcode_id=`BNE;
                    3'b100: opcode_id=`BLT;
                    3'b101: opcode_id=`BGE;
                    3'b110: opcode_id=`BLTU;
                    3'b111: opcode_id=`BGEU;
                endcase
            imm={{20{instr[31]}},instr[7],instr[31:25],instr[11:8]} << 1;
            end
            if (op==7'b0110011)   //R1
            begin
                case (op1)
                    3'b000: if(op2==0) opcode_id=`ADD; else opcode_id=`SUB;
                    3'b001: opcode_id=`SLL;
                    3'b010: opcode_id=`SLT;
                    3'b011: opcode_id=`SLTU;
                    3'b100: opcode_id=`XOR;
                    3'b101: if (op2==7'b0000000) opcode_id=`SRL; else opcode_id=`SRA;
                    3'b110: opcode_id=`OR;
                    3'b111: opcode_id=`AND;
                endcase
            end
            if (op==7'b0010111)   begin opcode_id=`AUIPC; imm=(instr>>12)<<12;end
            if (op==7'b0110111)   begin opcode_id=`LUI;  imm=(instr>>12)<<12;end
            if (op==7'b1101111)
            begin
                opcode_id=`JAL;
                imm = {{12{instr[31]}},instr[19:12],instr[20],instr[30:21]} << 1;
                    
            end
            if (op==7'b1100111)   begin 
                opcode_id=`JALR; imm=(instr>>20);
                imm={{20{instr[31]}},instr[31:20]};
            end
            if (op==7'b0100011)   begin
                case (op1)
                    3'b000: opcode_id=`SB;
                    3'b001: opcode_id=`SH;
                    3'b010: opcode_id=`SW;
                endcase
                imm = {{20{instr[31]}},instr[31:25],instr[11:7]};
            end
            if (opcode_id==`LUI||opcode_id==`AUIPC||opcode_id==`ADD||opcode_id==`SUB||opcode_id==`SLL||opcode_id==`SLT||opcode_id==`SLTU||opcode_id==`XOR||opcode_id==`SRL||opcode_id==`SRA||opcode_id==`OR||opcode_id==`AND||opcode_id==`ADDI||opcode_id==`SLTI||opcode_id==`SLTIU||opcode_id==`XORI||opcode_id==`ORI||opcode_id==`ANDI||opcode_id==`SLLI||opcode_id==`SRLI||opcode_id==`SRAI) begin Decoder_update_LSB=0; Decoder_update_RS=1; end
            if (opcode_id==`LB||opcode_id==`LH||opcode_id==`LW||opcode_id==`LBU||opcode_id==`LHU) begin Decoder_update_LSB=1; Decoder_update_RS=0; end
            if (opcode_id==`SB||opcode_id==`SH||opcode_id==`SW) begin Decoder_update_LSB=1; Decoder_update_RS=0; end
            if (opcode_id==`BEQ||opcode_id==`BNE||opcode_id==`BLT||opcode_id==`BGE||opcode_id==`BLTU||opcode_id==`BGEU||opcode_id==`JAL||opcode_id==`JALR) begin Decoder_update_LSB=0; Decoder_update_RS=1; end
  
        end
        else begin
            rd=0;
            Reg_rs1=0;
            Reg_rs2=0;
            opcode_id=0;
            imm=0;
            Decoder_update_LSB=0;
            Decoder_update_RS=0;
        end

    end

    always @(*) begin
         if (Reg_rs1_ready) rs1_ready=1; else rs1_ready=ROB_rs1_ready;
         if (Reg_rs1_ready) reg1=Reg_reg1; else reg1=ROB_reg1;
         if (Reg_rs2_ready) rs2_ready=1; else rs2_ready=ROB_rs2_ready;
         if (Reg_rs2_ready) reg2=Reg_reg2; else reg2=ROB_reg2;
    end
    always @(posedge clk) begin
        if (rst || !update_instr_valid || ROB_full || LSB_full) begin
            instr<=0;
            instr_valid<=0;
            Decoder_update_ROB<=0;
            ROB_instr_isjump<=0;
            ROB_instr_jump_wrong_to_pc<=0;
        end
        else if (rdy) begin
            instr<=update_instr;
            instr_valid<=1;
            Decoder_update_ROB<=1;
            ROB_instr_isjump<=update_instr_isjump;
            ROB_instr_jump_wrong_to_pc<=update_instr_jump_wrong_to_pc;
        end
    end
    
endmodule
`endif