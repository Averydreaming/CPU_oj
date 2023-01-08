`ifndef ALU
`define ALU
`include "op_map.v"

//calc a instr in RS to CDB
module ALU(
    input  wire             clk,
    input  wire             rst,
    input  wire             rdy,
    //from RS
    input  wire             instr_valid,
    input  wire [5:0]       opcode_id,
    input  wire [31:0]      vj,
    input  wire [31:0]      vk,
    input  wire [31:0]      A,
    input  wire [3:0]       ROB_pos,
    //to RS
    output reg              ALU_instr_valid,
    output reg  [3:0]       ALU_ROB_pos,
    output reg  [31:0]      ALU_val

);

    always @(*) begin
        ALU_instr_valid = instr_valid;
        if (instr_valid)  ALU_ROB_pos=ROB_pos; else ALU_ROB_pos=0;
        if (instr_valid) begin
            case (opcode_id)
                `ADD:ALU_val=vj+vk; 
                `SUB:ALU_val=vj-vk; 
                `SLL:ALU_val=vj<<(vk[4:0]); 
                `SLT:ALU_val=($signed(vj)<$signed(vk)); 
                `SLTU:ALU_val=(vj<vk); 
                `XOR:ALU_val=vj^vk;
                `SRL:ALU_val=vj>>(vk[4:0]); 
                `SRA:ALU_val=$signed(vj)>>(vk[4:0]); 
                `OR:ALU_val=vj|vk; 
                `AND:ALU_val=vj&vk; 
                `JALR:ALU_val=(vj+A)& ~(32'b1);
                `ADDI:ALU_val=vj+vk; 
                `SLTI:ALU_val=($signed(vj)<$signed(A)); 
                `SLTIU:ALU_val=(vj<A); 
                `XORI:ALU_val=vj^A; 
                `ORI:ALU_val=vj|A; 
                `ANDI:ALU_val=vj&A; 
                `SLLI:ALU_val=vj<<A; 
                `SRLI:ALU_val=vj>>A; 
                `SRAI:ALU_val=$signed(vj)>>A; 
                `BEQ:ALU_val=(vj==vk); 
                `BNE:ALU_val=(vj!=vk); 
                `BLT:ALU_val=($signed(vj)<$signed(vk)); 
                `BGE:ALU_val=($signed(vj)>=$signed(vk)); 
                `BLTU:ALU_val=(vj<vk); 
                `BGEU:ALU_val=(vj>=vk); 
                default: ALU_val=0;
            endcase
        end
        else ALU_val=0;
    end 
endmodule
`endif