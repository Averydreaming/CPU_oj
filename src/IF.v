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


    reg  [31: 0]    imm;
    reg  [ 1: 0]    BHT     [511:0];
    reg  [10:2]   jumppc    [15:0];
    reg  [3:0]    front, rear;

    always @(*) begin
       
        case (Instr[6:0])
            `AUIPCOP: imm={Instr[31:12], 12'b0};
            `LUIOP  : imm={Instr[31:12], 12'b0};                                 
            `JALROP : imm={{20{Instr[31]}}, Instr[31:20]};
            `JALOP  : imm={{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21]} << 1;
            default: imm={{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8]} << 1;  
        endcase
    end

    wire [ 6: 0]    opcode=Instr[6:0];
    reg  [31: 0]    pc;
    assign Instr_valid_Decoder=Instr_valid;
    assign Instr_Decoder=Instr;

    always @(*) begin
        if (!Instr_valid || Decoder_not_ready_accept) begin
            next_pc=pc;
            Instr_isjump=0;
            Instr_jump_wrong_to_pc=pc; 
        end
        else begin
            
            case (opcode)
                `BRANCHOP   : begin
                    if (BHT[pc[10:2]][1]) begin
                        next_pc=pc + imm;
                        Instr_isjump=1;
                        Instr_jump_wrong_to_pc=pc + 4;
                    end
                    else 
                    begin
                        next_pc=pc + 4;
                        Instr_isjump=0;
                        Instr_jump_wrong_to_pc=pc + imm;
                    end
                end 
                `JALOP      : begin
                    next_pc=pc + imm;
                    Instr_isjump=4 == imm;
                    Instr_jump_wrong_to_pc=pc + 4;
                end
                `JALROP     : begin
                    next_pc=pc + 4;
                    Instr_isjump=4 == imm;
                    Instr_jump_wrong_to_pc=pc + 4;
                end
                `LUIOP      : begin
                    next_pc=pc + 4;
                    Instr_isjump=4 == imm;
                    Instr_jump_wrong_to_pc=imm;
                end
                default     :  begin
                    next_pc=pc + 4;
                    Instr_isjump=4 == imm;
                    Instr_jump_wrong_to_pc=pc + imm;
                end
            endcase
        end
    end

    integer i;
    always @(posedge clk) begin
        /*
        if (rst) begin
            pc <= 0;
            for (i=0; i < 512; i=i + 1)
                BHT[i] <= 2'b01;
            front <= 0;
            rear <= 0;
        end 
        else if (!rdy) begin
            
        end
        else if (jump_wrong) begin
            pc <= jump_wrong_to_pc; 

            if (SB_commit) begin
                case (BHT[jumppc[front]])
                    2'b00 : BHT[jumppc[front]] <= 2'b01;
                    2'b01 : BHT[jumppc[front]] <= 2'b10;
                    2'b10 : BHT[jumppc[front]] <= 2'b01;
                    2'b11 : BHT[jumppc[front]] <= 2'b10;
                endcase
            end

            front <= 0;
            rear <= 0;
        end
        else if (Decoder_not_ready_accept) begin
            
        end
        else if (Instr_valid) begin
            
            case (opcode)
                `BRANCHOP   : begin
                    if (BHT[pc[10:2]][1])
                        pc <= pc + imm;
                    else 
                        pc <= pc + 4;
                end 
                `JALOP      : pc <= pc + imm;
                `JALROP     : pc <= pc + 4;
                default     : pc <= pc + 4;
            endcase

            if (opcode == `BRANCHOP) begin
                rear <= -(~rear);
                jumppc[rear] <= pc[10:2];
            end
            
        end

        if (!rst && rdy && !jump_wrong && SB_commit) begin
            front <= -(~front);
            case (BHT[jumppc[front]])
                2'b01 : BHT[jumppc[front]] <= 2'b00;
                2'b10 : BHT[jumppc[front]] <= 2'b11;
            endcase
        end*/
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
                    if (opcode==`BRANCHOP ) begin  rear<=-(~rear);  jumppc[rear] <= pc[13:2]; end
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