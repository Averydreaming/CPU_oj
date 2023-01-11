`include "defines.v"

module Decoder (
    input  wire             clk, 
    input  wire             rst, 
    input  wire             rdy, 
    input  wire             jump_wrong, 

    // InstFetch
    input  wire             update_instr_valid, 
    input  wire             update_instr_isjump, 
    input  wire [31: 0]     update_instr, 
    input  wire [31: 0]     update_instr_jump_wrong_to_pc, 
    output wire             Decoder_not_ready_accept, 

    // RegFile
    input  wire             Reg_rs1_ready, 
    input  wire             Reg_rs2_ready, 
    input  wire [31: 0]     Reg_reg1,
    input  wire [31: 0]     Reg_reg2, 
    output reg  [ 4: 0]     Reg_rs1,
    output reg  [ 4: 0]     Reg_rs2, 

    // CDB
    output reg  [ 4: 0]     rd, 
    output reg  [ 5: 0]     opcode_id, 
    output wire             rs1_ready,
    output wire             rs2_ready, 
    output wire [31: 0]     reg1,
    output wire [31: 0]     reg2, 
    output reg  [31: 0]     imm, 

    // LSB
    output reg              Decoder_update_LSB, 
    output wire [ 2: 0]     insty_LSB, 

    // ROB
    input  wire             ROB_full,
    input  wire             LSB_full, 
    input  wire             ROB_rs1_ready, 
    input  wire             ROB_rs2_ready, 
    input  wire [31: 0]     ROB_reg1,
    input  wire [31: 0]     ROB_reg2, 
    output reg              Decoder_update_ROB, 
    output reg              ROB_instr_isjump, 
    output reg  [31: 0]     ROB_instr_jump_wrong_to_pc, 

    // RS
    output reg              Decoder_update_RS
);

    // CDB
    assign rs1_ready = Reg_rs1_ready ? 1 : ROB_rs1_ready;
    assign rs2_ready = Reg_rs2_ready ? 1 : ROB_rs2_ready;
    assign reg1 = Reg_rs1_ready ? Reg_reg1 : ROB_reg1;
    assign reg2 = Reg_rs2_ready ? Reg_reg2 : ROB_reg2;
    assign Decoder_not_ready_accept = ROB_full | LSB_full;

    // LSB
    assign insty_LSB = opcode_id[2:0];

    reg  [31: 0]    debug_now;
    reg  [31: 0]    instr;
    wire [ 6: 0]    opcode = instr[6:0];
    always @(*) begin
        if (Decoder_update_ROB) begin
            Decoder_update_LSB = (opcode == 7'd3 || opcode == 7'd35);

            rd = (opcode == 7'd99 || opcode == 7'd35) ? 0 : instr[11:7];
            Reg_rs1 = (opcode == 7'd111 || opcode == 7'd55 || opcode == 7'd23) ? 0 : instr[19:15];
            Reg_rs2 = (opcode == 7'd99 || opcode == 7'd35 || opcode == 7'd51) ? instr[24:20] : 0;
            case (opcode)
                7'd3 : begin
                    case (instr[14:12])
                        3'b001: opcode_id = `LH;
                        3'b010: opcode_id = `LW;
                        3'b100: opcode_id = `LBU;
                        3'b101: opcode_id = `LHU; 
                        3'b000: opcode_id = `LB;
                        default: opcode_id = 0;
                    endcase
                    imm = {{20{instr[31]}}, instr[31:20]};

                    Decoder_update_RS = 0;
                end
                7'd35 : begin
                    case (instr[14:12])
                        3'b000: opcode_id = `SB;
                        3'b001: opcode_id = `SH;
                        3'b010: opcode_id = `SW;
                        default: opcode_id = 0;
                    endcase
                    imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
                    Decoder_update_RS = 0;
                end
                7'd19 : begin
                    case (instr[14:12])
                        3'b000: opcode_id = `ADDI; 
                        3'b100: opcode_id = `XORI;
                        3'b110: opcode_id = `ORI;
                        3'b111: opcode_id = `ANDI;
                        3'b001: opcode_id = `SLLI;
                        3'b101: opcode_id = (instr[30] ? `SRAI : `SRLI);
                        3'b010: opcode_id = `SLTI;
                        3'b011: opcode_id = `SLTIU;
                        default: opcode_id = 0;
                    endcase
                    imm = (instr[14:12] == 1 || instr[14:12] == 5) ? {27'b0, instr[24:20]} : {{20{instr[31]}}, instr[31:20]};
                    Decoder_update_RS = 1;
                end
                7'd51 : begin
                    case (instr[14:12])
                        3'b000: opcode_id = (instr[30] ? `SUB : `ADD);
                        3'b100: opcode_id = `XOR;
                        3'b110: opcode_id = `OR;
                        3'b111: opcode_id = `AND;
                        3'b001: opcode_id = `SLL;
                        3'b101: opcode_id = (instr[30] ? `SRA : `SRL);
                        3'b010: opcode_id = `SLT;
                        3'b011: opcode_id = `SLTU;
                        default: opcode_id = 0;
                    endcase
                    imm = 0;
                    Decoder_update_RS = 1;
                end
                7'd99 : begin
                    case (instr[14:12])
                        3'b000: opcode_id = `BEQ;
                        3'b001: opcode_id = `BNE;
                        3'b100: opcode_id = `BLT;
                        3'b101: opcode_id = `BGE;
                        3'b110: opcode_id = `BLTU;
                        3'b111: opcode_id = `BGEU;
                        default: opcode_id = 0;
                    endcase
                    imm = {{20{instr[31]}}, instr[7], instr[31:25], instr[11:8]} << 1; 
                    Decoder_update_RS = 1;
                end
                7'd55 : begin
                    imm = instr[31:12] << 12;
                    opcode_id = `LUI;
                    Decoder_update_RS = 0;
                end
                7'd23 : begin
                    imm = instr[31:12] << 12;
                    opcode_id = `AUIPC;
                    Decoder_update_RS = 0;
                end
                7'd111 : begin
                    imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21]} << 1;
                    opcode_id = `JAL;
                    Decoder_update_RS = 0;
                end
                7'd103 : begin
                    imm = {{20{instr[31]}}, instr[31:20]};
                    opcode_id = `JALR;
                    Decoder_update_RS = 1;
                end
                default: begin
                    imm = 0;
                    opcode_id = 0;
                    Decoder_update_RS = 0;
                end
            endcase
        end
        else begin
            Decoder_update_LSB = 0;
            Decoder_update_RS = 0;
            rd = 0;
            Reg_rs1 = 0;
            Reg_rs2 = 0;
            opcode_id = 0;
            imm = 0;
        end
    end

    always @(posedge clk) begin
        if (rst || jump_wrong || !update_instr_valid || ROB_full || LSB_full) begin
            Decoder_update_ROB <= 0;
            instr <= 0;
            ROB_instr_isjump <= 0;
            ROB_instr_jump_wrong_to_pc <= 0;
        end
        else if (!rdy) begin
            
        end
        else begin
            Decoder_update_ROB <= 1;
            ROB_instr_isjump <= update_instr_isjump;
            ROB_instr_jump_wrong_to_pc <= update_instr_jump_wrong_to_pc;
            instr <= update_instr;
        end
    end
    
endmodule