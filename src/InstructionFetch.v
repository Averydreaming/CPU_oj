`include "defines.v"

module InstructionFetch (
    input  wire             clk, rst, rdy, 

    // ROB
    input  wire             jump_wrong,
    input  wire [31: 0]     jump_wrong_to_pc, 
    input  wire             SB_commit, 
    
    // Decoder
    input  wire             Decoder_not_ready_accept, 
    output wire             Instr_valid_Decoder, 
    output wire [31: 0]     Instr_Decoder, 
    output reg              Instr_isjump, 
    output reg  [31: 0]     Instr_jump_wrong_to_pc, 
    
    // ICache
    input  wire             Instr_valid, 
    input  wire [31: 0]     Instr, 
    output reg  [31: 0]     next_pc
);


    wire [ 6: 0]    opcode=Instr[6:0];
    reg  [31: 0]    pc;
    assign Instr_valid_Decoder=Instr_valid;
    assign Instr_Decoder=Instr;
    reg  [31: 0]    imm;
    reg  [ 1: 0]    BHT     [511:0];
    reg  [10:2]    jumppc    [15:0];
    reg  [3:0]     front, rear;

    always @(*) begin
        imm = (opcode==7'd23)? {Instr[31:12], 12'b0} : (opcode==7'd55) ? {Instr[31:12], 12'b0}  : (opcode ==7'd103)?{{20{Instr[31]}}, Instr[31:20]}   :    (opcode==7'd111) ? {{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21]} << 1   :   {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8]} << 1   ;
    end


    always @(*) begin
        if (!Instr_valid || Decoder_not_ready_accept) begin
            next_pc=pc;
            Instr_isjump=0;
            Instr_jump_wrong_to_pc=pc; 
        end
        else begin
            next_pc=pc+4; Instr_isjump=(4==imm); Instr_jump_wrong_to_pc=pc+imm;
            if (opcode==`JALOP) begin next_pc=pc+imm; Instr_jump_wrong_to_pc=pc+4; end    
            if (opcode==`LUIOP) begin next_pc=pc+4; Instr_jump_wrong_to_pc=imm; end    
            if (opcode==`JALROP) begin next_pc=pc+4;  Instr_jump_wrong_to_pc=pc+4; end    
            if (opcode==`BRANCHOP  && BHT[pc[10:2]][1])  begin next_pc=pc+imm; Instr_isjump=1; Instr_jump_wrong_to_pc=pc+4; end
            if (opcode==`BRANCHOP  && !BHT[pc[10:2]][1]) begin next_pc=pc+4; Instr_isjump=0; Instr_jump_wrong_to_pc=pc+imm; end
        end
    end

    integer i;
    always @(posedge clk) begin
     
        if (rst) begin
            pc<=0;
            front<=0;
            rear<=0;
            for (i=0;i<512; i=i+1) BHT[i]<=1;
        end else if (rdy) begin
            if (jump_wrong) begin
                 pc<=jump_wrong_to_pc;
                 if (SB_commit) begin
                    if(BHT[jumppc[front]]==0)begin BHT[jumppc[front]]<=1; end
                    if(BHT[jumppc[front]]==1)begin BHT[jumppc[front]]<=2; end
                    if(BHT[jumppc[front]]==2)begin BHT[jumppc[front]]<=1; end
                    if(BHT[jumppc[front]]==3)begin BHT[jumppc[front]]<=2; end
                 end
                front<=0;
                rear<=0;
            end 
            if (!jump_wrong) begin
                if (!Decoder_not_ready_accept && Instr_valid) begin
                    if (opcode==`JALOP  || (opcode==`BRANCHOP && BHT[pc[10:2]][1])) pc<=pc+imm; else pc<=pc+4;
                    if (opcode==`BRANCHOP ) begin  rear<=-(~rear);  jumppc[rear]<=pc[13:2]; end
                end
                 if (SB_commit) begin
                    front<=-(~front);
                    if(BHT[jumppc[front]]==1)begin BHT[jumppc[front]]<=0; end
                    if(BHT[jumppc[front]]==2)begin BHT[jumppc[front]]<=3; end
                   end
            end 
        end
end
  
endmodule