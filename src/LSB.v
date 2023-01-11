`include "defines.v"

module LoadStoreBuffer(
    input  wire             clk, rst, rdy, 
    input  wire             jump_wrong,                                   // 跳转错误

    // CDB
    output wire             Load_instr_valid, 
    output wire [3:0]       Load_ROB_pos, 
    output wire [31:0]      Load_val, 

    // Decoder
    input  wire             update_Decoder_valid, 
    input  wire [ 2: 0]     insty, 
    input  wire             rs1_ready, rs2_ready, 
    input  wire [31:0]      reg1, reg2, imm, 
    output wire             LSB_FULL, 

    // ROB
    input  wire [3:0]       ROB_pos,
    input  wire [3:0]       ROB_front,  
    input  wire             store_is_commit, 

    // RS
    input  wire             update_RS_valid, 
    input  wire [3:0]       update_RS_ROB_pos, 
    input  wire [31:0]      update_RS_val, 

    // MemCtrl
    input  wire              memctrl_update_finished, 
    input  wire [31: 0]      memctrl_update_value, 
    output wire              update_LoadStore, 
    output wire [ 2: 0]      LS_insty, 
    output wire [31: 0]      mem_address, 
    output wire [31: 0]      LS_value 
);
   reg             LSB_full;
    reg  [3:0]      LSB_front, LSB_rear, commit_amount;

    reg  [ 2: 0]    LSB_insty         [15:0];
    reg  [15:0]    LSB_rs1_ready, LSB_rs2_ready, LSB_commit;
    reg  [31:0]    LSB_reg1        [15:0];
    reg  [31:0]    LSB_reg2        [15:0];
    reg  [31:0]    LSB_imm     [15:0];
    reg  [3:0]     LSB_ROB_pos     [15:0];
 
    reg             update_reg1_ready, update_reg2_ready;                      
    reg  [31:0]    update_reg1, update_reg2;   


    reg             memctrl_update_valid, next_memctrl_update_valid;
    wire [31: 0]    address, next_address;



    assign address=LSB_reg1[LSB_front] + LSB_imm[LSB_front];
    assign next_address=LSB_reg1[-(~LSB_front)] + LSB_imm[-(~LSB_front)];

    assign LSB_FULL=memctrl_update_finished ? (LSB_full && update_Decoder_valid) : (LSB_full || (update_Decoder_valid && (LSB_front == (-(~LSB_rear)))));

    assign Load_instr_valid=memctrl_update_finished && !(LSB_insty[LSB_front][2] && LSB_insty[LSB_front][1:0] != 0);
    assign Load_ROB_pos=LSB_ROB_pos[LSB_front];
    assign Load_val=memctrl_update_value;

    assign update_LoadStore=memctrl_update_finished ? next_memctrl_update_valid : memctrl_update_valid;
    assign LS_insty=memctrl_update_finished ? LSB_insty[-(~LSB_front)] : LSB_insty[LSB_front];
    assign mem_address=memctrl_update_finished ? next_address : address;
    assign LS_value=memctrl_update_finished ? LSB_reg2[-(~LSB_front)] : LSB_reg2[LSB_front];

    always @(*) begin
        if ((LSB_full || LSB_front != LSB_rear) && LSB_rs1_ready[LSB_front] && LSB_rs2_ready[LSB_front] && rdy) begin
            if (LSB_insty[LSB_front] == `SB || LSB_insty[LSB_front] == `SH || LSB_insty[LSB_front] == `SW) 
                memctrl_update_valid=LSB_commit[LSB_front];
            else
                memctrl_update_valid=(address[17:16] == 2'b11) ? (LSB_ROB_pos[LSB_front] == ROB_front && !jump_wrong) : 1;
        end
        else 
            memctrl_update_valid=0;

        if ((LSB_full || LSB_front != LSB_rear) && -(~LSB_front) != LSB_rear && LSB_rs1_ready[-(~LSB_front)] && LSB_rs2_ready[-(~LSB_front)] && rdy) begin
            if (LSB_insty[-(~LSB_front)] == `SB || LSB_insty[-(~LSB_front)] == `SH || LSB_insty[-(~LSB_front)] == `SW) 
                next_memctrl_update_valid=LSB_commit[-(~LSB_front)];
            else
                next_memctrl_update_valid=(next_address[17:16] == 2'b11) ? (LSB_ROB_pos[-(~LSB_front)] == ROB_front && !jump_wrong) : 1;
        end
        else 
            next_memctrl_update_valid=0;
    end

    integer i;
                     

    always @(*) begin
        if (!rs1_ready) begin
            if (update_RS_valid && update_RS_ROB_pos == reg1[3:0]) begin
                update_reg1_ready=1;
                update_reg1=update_RS_val;
            end
            else if (Load_instr_valid && Load_ROB_pos == reg1[3:0])begin
                update_reg1_ready=1;
                update_reg1=Load_val;
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
            if (update_RS_valid && update_RS_ROB_pos == reg2[3:0]) begin
                update_reg2_ready=1;
                update_reg2=update_RS_val;
            end
            else if (Load_instr_valid && Load_ROB_pos == reg2[3:0])begin
                update_reg2_ready=1;
                update_reg2=Load_val;
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

    always @(posedge clk) begin
        if (rst) begin
            LSB_full <= 0;
            LSB_front <= 0;
            LSB_rear <= 0;
            commit_amount <= 0;
            LSB_rs1_ready <= 0;
            LSB_rs2_ready <= 0;
            LSB_commit <= 0;
        end
        else if (!rdy) begin
            
        end
        else if (jump_wrong) begin
            LSB_full <= !memctrl_update_finished && commit_amount == 16;
            LSB_rear <= LSB_front + commit_amount + (memctrl_update_finished && !(LSB_insty[LSB_front][2] && LSB_insty[LSB_front][1:0] != 0)); 
            
            if (memctrl_update_finished)
                LSB_front <= -(~LSB_front);
            commit_amount <= commit_amount - (memctrl_update_finished && LSB_insty[LSB_front][2] && LSB_insty[LSB_front][1:0] != 0);
        end 

        if (!rst && rdy && !jump_wrong)
        begin
            LSB_full <= memctrl_update_finished ? (LSB_full && update_Decoder_valid) : (LSB_full || (update_Decoder_valid && (LSB_front == (-(~LSB_rear)))));

            if (update_Decoder_valid) begin
                LSB_rear <= -(~LSB_rear);
                LSB_rs1_ready[LSB_rear] <= update_reg1_ready;
                LSB_rs2_ready[LSB_rear] <= update_reg2_ready;
                LSB_ROB_pos[LSB_rear] <= ROB_pos;
                LSB_commit[LSB_rear] <= 0;
                LSB_insty[LSB_rear] <= insty;
                LSB_reg1[LSB_rear] <= update_reg1;
                LSB_reg2[LSB_rear] <= update_reg2;
                LSB_imm[LSB_rear] <= imm;
            end

            if (memctrl_update_finished)
                LSB_front <= -(~LSB_front);

            commit_amount <= commit_amount - (memctrl_update_finished && LSB_insty[LSB_front][2] && LSB_insty[LSB_front][1:0] != 0) + store_is_commit;

            if (store_is_commit) begin
                LSB_commit[LSB_front + commit_amount] <= 1;
            end
            
            for (i=0; i < 16; i=i + 1)
            if (LSB_full || i != LSB_rear)
            begin
                if (update_RS_valid && !LSB_rs1_ready[i] && LSB_reg1[i][3:0] == update_RS_ROB_pos) begin
                    LSB_rs1_ready[i] <= 1;
                    LSB_reg1[i] <= update_RS_val;
                end
                if (Load_instr_valid && !LSB_rs1_ready[i] && LSB_reg1[i][3:0] == Load_ROB_pos) begin
                    LSB_rs1_ready[i] <= 1;
                    LSB_reg1[i] <= Load_val;
                end

                if (update_RS_valid && !LSB_rs2_ready[i] && LSB_reg2[i][3:0] == update_RS_ROB_pos) begin
                    LSB_rs2_ready[i] <= 1;
                    LSB_reg2[i] <= update_RS_val;
                end
                if (Load_instr_valid && !LSB_rs2_ready[i] && LSB_reg2[i][3:0] == Load_ROB_pos) begin
                    LSB_rs2_ready[i] <= 1;
                    LSB_reg2[i] <= Load_val;
                end
            end
        end
    end
endmodule