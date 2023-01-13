`include "defines.v"

module ReservationStation(
    input  wire             clk, rst, rdy, 
    input  wire             jump_wrong,                             
// 每个周期读入一条指令from decoder

    input  wire            update_Decoder_valid,                            
    input  wire [5: 0]     opcode_id,                                  
    input  wire            rs1_ready, 
    input  wire            rs2_ready,                    
    input  wire [31:0]     reg1, 
    input  wire [31:0]     reg2, 
    input  wire [31:0]     imm,                           

    input  wire [3:0]      ROB_pos,                             
  // 其他容器在上一周期是否发来更新
    input  wire            update_RS_valid,                               
    input  wire [3:0]      update_RS_ROB_pos,                                
    input  wire [31:0]     update_RS_val,                                 


    input  wire            update_LSB_Load_valid,                             
    input  wire [3:0]      update_LSB_Load_ROB_pos,                              
    input  wire [31:0]     update_LSB_Load_val,                                  


//每个周期calc一条指令，将计算出来的值传到CDB
    output reg              ALU_instr_valid,                                  
    output reg  [3:0]       ALU_ROB_pos,                                
    output reg  [31:0]      ALU_val                                  

);
    
     // ALU
    always @(*) begin
        if (ex_instr_valid) begin
            ALU_instr_valid=1;
            ALU_ROB_pos=ex_ROB_pos;
            case (ex_opcode_id)
                `ADD   : ALU_val=ex_vj + ex_vk;
                `ADDI  : ALU_val=ex_vj + ex_vk;
                `SUB   : ALU_val=ex_vj - ex_vk;
                `XOR   : ALU_val=ex_vj ^ ex_vk;
                `XORI  : ALU_val=ex_vj ^ ex_vk;
                `OR    : ALU_val=ex_vj | ex_vk;
                `ORI   : ALU_val=ex_vj | ex_vk;
                `AND   : ALU_val=ex_vj & ex_vk;
                `ANDI  : ALU_val=ex_vj & ex_vk;
                `SLL   : ALU_val=ex_vj << ex_vk[4:0];
                `SLLI  : ALU_val=ex_vj << ex_vk[4:0];
                `SRL   : ALU_val=ex_vj >> ex_vk[4:0];
                `SRLI  : ALU_val=ex_vj >> ex_vk[4:0];
                `SRA   : ALU_val=$signed(ex_vj) >> ex_vk[4:0];
                `SRAI  : ALU_val=$signed(ex_vj) >> ex_vk[4:0];
                `SLT   : ALU_val=$signed(ex_vj) < $signed(ex_vk);
                `SLTI  : ALU_val=$signed(ex_vj) < $signed(ex_vk);
                `SLTU  : ALU_val=ex_vj < ex_vk;
                `SLTIU : ALU_val=ex_vj < ex_vk;
                `BEQ   : ALU_val=ex_vj== ex_vk;
                `BNE   : ALU_val=ex_vj != ex_vk;
                `BLT   : ALU_val=$signed(ex_vj) < $signed(ex_vk);
                `BGE   : ALU_val=$signed(ex_vj) >= $signed(ex_vk);
                `BLTU  : ALU_val=ex_vj < ex_vk;
                `BGEU  : ALU_val=ex_vj >= ex_vk;
                `JALR  : ALU_val=(ex_vj + ex_vk) & ~(32'b1);
                default: ALU_val=0;
            endcase
        end
        else begin
            ALU_instr_valid=0;
            ALU_ROB_pos=0;
            ALU_val=0;
        end
    end          
    reg  [5: 0]    RS_opcode_id             [15:0];                            
    reg  [15:0]    RS_busy;                                        
    reg  [31:0]    RS_vj            [15:0];                          
    reg  [31:0]    RS_vk            [15:0];                            
    reg  [15:0]    RS_qj;                                        
    reg  [15:0]    RS_qk;                                      
    reg  [3:0]     RS_ROB_pos         [15:0];                          

    reg            update_reg1_ready, update_reg2_ready;                 
    reg  [31:0]    update_reg1, update_reg2;                            

    wire [15:0]    idle=(~RS_busy) & (-(~RS_busy));                                                      

    wire [15:0]    ready_state=RS_busy & RS_qj & RS_qk;      
    wire [15:0]    ready_pos_lowbit=ready_state & (-ready_state);  
    wire           ex_instr_valid; 
    reg  [5: 0]    ex_opcode_id;                                    
    reg  [31:0]    ex_vj;
    reg  [31:0]    ex_vk;                                
    reg  [3:0]     ex_ROB_pos;                         
    assign ex_instr_valid=ready_pos_lowbit != 0;

    always @(*) begin
        ex_opcode_id=0;
        ex_vj=0;
        ex_vk=0;
        ex_ROB_pos=0;
        for (i=0; i < 16; i=i + 1)
            if (ready_pos_lowbit[i])
            begin
                ex_opcode_id=RS_opcode_id[i];
                ex_vj=RS_vj[i];
                ex_vk=RS_vk[i];
                ex_ROB_pos=RS_ROB_pos[i];
            end

        if (!rs1_ready) begin
            if (update_RS_valid && update_RS_ROB_pos== reg1[3:0]) begin
                update_reg1_ready=1;
                update_reg1=update_RS_val;
            end
            else if (update_LSB_Load_valid && update_LSB_Load_ROB_pos== reg1[3:0])begin
                update_reg1_ready=1;
                update_reg1=update_LSB_Load_val;
            end
            else begin
                update_reg1_ready=rs1_ready;
                update_reg1=reg1;
            end
        end
        else begin
            update_reg1_ready=rs1_ready;
            update_reg1=reg1;
        end
        
        if (!rs2_ready) begin
            if (update_RS_valid && update_RS_ROB_pos== reg2[3:0]) begin
                update_reg2_ready=1;
                update_reg2=update_RS_val;
            end
            else if (update_LSB_Load_valid && update_LSB_Load_ROB_pos== reg2[3:0])begin
                update_reg2_ready=1;
                update_reg2=update_LSB_Load_val;
            end
            else begin
                update_reg2_ready=rs2_ready;
                update_reg2=reg2;
            end
        end
        else begin
            update_reg2_ready=rs2_ready;
            update_reg2=reg2;
        end
    end
    
    integer i;
    always @(posedge clk) begin
        if (rst || jump_wrong) begin
            RS_busy<=0;
        end

        if (!rst && rdy && !jump_wrong)
        begin
            if (update_Decoder_valid) begin
                for (i=0; i < 16; i=i + 1)
                if (idle[i])
                begin
                    RS_busy[i]<=1;
                    RS_opcode_id[i]<=opcode_id;
                    RS_ROB_pos[i]<=ROB_pos;
                    RS_vj[i]<=update_reg1;
                    RS_qj[i]<=update_reg1_ready;
    
                    if (opcode_id== `JALR || (!opcode_id[5] && !opcode_id[0] && opcode_id != `SUB)) begin
                        RS_vk[i]<=imm;
                        RS_qk[i]<=1;    
                    end
                    else begin
                        RS_vk[i]<=update_reg2;
                        RS_qk[i]<=update_reg2_ready;
                    end    
                end
            end

            if (ready_pos_lowbit) begin
                for (i=0; i < 16; i=i + 1)
                    if (ready_pos_lowbit[i])
                        RS_busy[i]<=0;
            end

            for (i=0; i < 16; i=i + 1)
            if (RS_busy[i]) begin
                if (update_RS_valid && !RS_qj[i] && RS_vj[i][3:0]== update_RS_ROB_pos) begin
                    RS_qj[i]<=1;
                    RS_vj[i]<=update_RS_val;
                end
                if (update_LSB_Load_valid && !RS_qj[i] && RS_vj[i][3:0]== update_LSB_Load_ROB_pos) begin
                    RS_qj[i]<=1;
                    RS_vj[i]<=update_LSB_Load_val;
                end

                if (update_RS_valid && !RS_qk[i] && RS_vk[i][3:0]== update_RS_ROB_pos) begin
                    RS_qk[i]<=1;
                    RS_vk[i]<=update_RS_val;
                end
                if (update_LSB_Load_valid && !RS_qk[i] && RS_vk[i][3:0]== update_LSB_Load_ROB_pos) begin
                    RS_qk[i]<=1;
                    RS_vk[i]<=update_LSB_Load_val;
                end
            end
        end
    end

   
endmodule
