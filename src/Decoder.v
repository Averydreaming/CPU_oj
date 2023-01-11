`include "defines.v"

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
    output wire [ 2: 0]     insty_LSB, 
    output reg              Decoder_update_ROB,
    output reg              ROB_instr_isjump,
    output reg  [31: 0]     ROB_instr_jump_wrong_to_pc,

    output reg              Decoder_update_RS,
    input  wire             jump_wrong
);


    assign Decoder_not_ready_accept=ROB_full | LSB_full;
    assign insty_LSB=opcode_id[2:0];

    reg  [31: 0]    instr;
    wire [ 6: 0]    opcode=instr[6:0];
    always @(*) begin
        if (Decoder_update_ROB) begin
           
            rd=(opcode==7'd99 || opcode==7'd35) ? 0 : instr[11:7];
            Reg_rs1=(opcode==7'd111 || opcode==7'd55 || opcode==7'd23) ? 0 : instr[19:15];
            Reg_rs2=(opcode==7'd99 || opcode==7'd35 || opcode==7'd51) ? instr[24:20] : 0;
                if (opcode==7'b0000011) begin
                    case (instr[14:12])
                        3'b001: opcode_id=`LH;
                        3'b010: opcode_id=`LW;
                        3'b100: opcode_id=`LBU;
                        3'b101: opcode_id=`LHU; 
                        3'b000: opcode_id=`LB;
                        default: opcode_id=0;
                    endcase
                    imm={{20{instr[31]}}, instr[31:20]};
                end
                if (opcode==7'b0100011)  begin
                    case (instr[14:12])
                        3'b000: opcode_id=`SB;
                        3'b001: opcode_id=`SH;
                        3'b010: opcode_id=`SW;
                        default: opcode_id=0;
                    endcase
                    imm={{20{instr[31]}}, instr[31:25], instr[11:7]};
                end
                if (opcode==7'b0010011)   begin
                    case (instr[14:12])
                        3'b000: opcode_id=`ADDI; 
                        3'b100: opcode_id=`XORI;
                        3'b110: opcode_id=`ORI;
                        3'b111: opcode_id=`ANDI;
                        3'b001: opcode_id=`SLLI;
                        3'b101: opcode_id=(instr[30] ? `SRAI : `SRLI);
                        3'b010: opcode_id=`SLTI;
                        3'b011: opcode_id=`SLTIU;
                        default: opcode_id=0;
                    endcase
                    imm=(instr[14:12]==1 || instr[14:12]==5) ? {27'b0, instr[24:20]} : {{20{instr[31]}}, instr[31:20]};
                end
                if (opcode==7'b0110011)  begin
                    case (instr[14:12])
                        3'b000: opcode_id=(instr[30] ? `SUB : `ADD);
                        3'b100: opcode_id=`XOR;
                        3'b110: opcode_id=`OR;
                        3'b111: opcode_id=`AND;
                        3'b001: opcode_id=`SLL;
                        3'b101: opcode_id=(instr[30] ? `SRA : `SRL);
                        3'b010: opcode_id=`SLT;
                        3'b011: opcode_id=`SLTU;
                        default: opcode_id=0;
                    endcase
                    imm=0;
                end
                if (opcode==7'b1100011)  begin
                    case (instr[14:12])
                        3'b000: opcode_id=`BEQ;
                        3'b001: opcode_id=`BNE;
                        3'b100: opcode_id=`BLT;
                        3'b101: opcode_id=`BGE;
                        3'b110: opcode_id=`BLTU;
                        3'b111: opcode_id=`BGEU;
                        default: opcode_id=0;
                    endcase
                    imm={{20{instr[31]}}, instr[7], instr[31:25], instr[11:8]} << 1; 
                end
                if (opcode==7'b0110111)   begin
                    imm=instr[31:12] << 12;
                    opcode_id=`LUI;
                end
                if (opcode==7'b0010111)  begin
                    imm=instr[31:12] << 12;
                    opcode_id=`AUIPC;
                end
               if (opcode== 7'b1101111)  begin
                    imm={{12{instr[31]}}, instr[19:12], instr[20], instr[30:21]} << 1;
                    opcode_id=`JAL;
                end
                if (opcode== 7'b1100111)  begin
                    imm={{20{instr[31]}}, instr[31:20]};
                    opcode_id=`JALR;
                end
            Decoder_update_LSB=(opcode==7'd3 || opcode==7'd35);
            Decoder_update_RS= (opcode==7'd19 || opcode==7'd99 || opcode== 7'd51  ||opcode== 7'd103);
           
        end
        else begin
            Decoder_update_LSB=0;
            Decoder_update_RS=0;
            rd=0;
            Reg_rs1=0;
            Reg_rs2=0;
            opcode_id=0;
            imm=0;
        end
    end
    always @(*) begin
         if (Reg_rs1_ready) rs1_ready=1; else rs1_ready=ROB_rs1_ready;
         if (Reg_rs1_ready) reg1=Reg_reg1; else reg1=ROB_reg1;
         if (Reg_rs2_ready) rs2_ready=1; else rs2_ready=ROB_rs2_ready;
         if (Reg_rs2_ready) reg2=Reg_reg2; else reg2=ROB_reg2;
    end
    always @(posedge clk) begin
        if (rst || jump_wrong || !update_instr_valid || ROB_full || LSB_full) begin
            Decoder_update_ROB<=0;
            instr<=0;
            ROB_instr_isjump<=0;
            ROB_instr_jump_wrong_to_pc<=0;
        end
        else if (rdy) begin
            Decoder_update_ROB<=1;
            ROB_instr_isjump<=update_instr_isjump;
            ROB_instr_jump_wrong_to_pc<=update_instr_jump_wrong_to_pc;
            instr<=update_instr;
        end
    end
    
endmodule