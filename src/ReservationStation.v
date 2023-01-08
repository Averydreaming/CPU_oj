`ifndef RS
`define RS
`include "op_map.v"

//1、每个周期calc一条指令
//2、每个周期读入一条指令
//3.其他容器在上一周期更新
module ReservationStation(
    input  wire            clk,
    input  wire            rst,
    input  wire            rdy,
    // 每个周期读入一条指令from decoder
    input  wire            update_Decoder_valid,
    input  wire [5:0]      opcode_id,
    input  wire            reg1_ready,
    input  wire            reg2_ready,
    input  wire [31:0]     reg1,
    input  wire [31:0]     reg2,
    input  wire [31:0]     imm,
    input  wire [3:0]      ROB_pos,

    //每个周期calc一条指令，将计算出来的值传到CDB
    output reg            ex_instr_valid,
    output reg  [5:0]     ex_opcode_id,
    output reg  [31:0]    ex_vj,
    output reg  [31:0]    ex_vk,
    output reg  [31:0]    ex_A,
    output reg  [3:0]     ex_ROB_pos,

    // 其他容器在上一周期是否发来更新
    input  wire           update_RS_valid,                                
    input  wire [3:0]     update_RS_ROB_pos,                                 
    input  wire [31:0]    update_RS_val,

    input  wire           update_LSB_Load_valid,
    input  wire [3:0]     update_LSB_Load_ROB_pos,
    input  wire [31:0]    update_LSB_Load_val



);
    reg [5:0]      update_opcode_id;             
    reg            update_reg1_ready;
    reg            update_reg2_ready;                   // reg1，reg2 是否已经拿到值
    reg [31:0]     update_reg1;
    reg [31:0]     update_reg2;
    reg [31:0]     update_imm;
    reg [3:0]      update_ROB_pos;


    reg  [5:0]     RS_opcode_id[31:0];                            
    reg  [31:0]    RS_busy;                                               
    reg  [31:0]    RS_vj                [31:0];    
    reg  [31:0]    RS_vk                [31:0];                           
    reg  [31:0]    RS_qj,RS_qk;
    reg  [31:0]    RS_imm              [31:0];
    reg  [3:0]     RS_ROB_pos          [31:0];

    wire   ex_valid;                                      
    assign ex_valid=((~RS_busy) != 0);   

    wire  [31:0]    ready_ex;
    assign ready_ex=RS_busy & RS_qj & RS_qk;
    reg  [5:0]     ex_pos; 

    
    always @(*) begin
    //每个周期calc一条指令
        if (ready_ex==0) begin
            ex_instr_valid=0;
            ex_opcode_id=0;
            ex_vj=0;
            ex_vk=0;
            ex_A=0;
            ex_ROB_pos=0;
        end
        else 
        begin 
            for (i=31; i >=0; i=i - 1)
                if (ready_ex[i])
                begin
                    ex_pos=i;
                end
            ex_opcode_id=RS_opcode_id[ex_pos];
            ex_vj=RS_vj[ex_pos];
            ex_vk=RS_vk[ex_pos];
            ex_A=RS_imm[ex_pos];
            ex_ROB_pos=RS_ROB_pos[ex_pos];
        end




    //用这一周期LSB_Load和RS产生的update这一周期要插入的新指令
        update_opcode_id=opcode_id;
        update_reg1_ready=reg1_ready;
        update_reg2_ready=reg2_ready;
        update_reg1=reg1;
        update_reg2=reg2;
        update_imm=imm;
        update_ROB_pos=ROB_pos;
        if (update_RS_valid && !update_reg1_ready && update_reg1[3:0] == update_RS_ROB_pos) begin
            update_reg1[3:0]=update_RS_val; update_reg1_ready=1;
        end
        else if (update_LSB_Load_valid && !update_reg1_ready && update_reg1[3:0] == update_LSB_Load_ROB_pos) begin
                    update_reg1[3:0]=update_LSB_Load_val; update_reg1_ready=1;
        end


        if (update_RS_valid && !update_reg2_ready && update_reg2[3:0] == update_RS_ROB_pos) begin
            update_reg2[3:0]=update_RS_val; update_reg2_ready=1;
        end
        else if (update_LSB_Load_valid && !update_reg2_ready && update_reg2[3:0] == update_LSB_Load_ROB_pos) begin
            update_reg2[3:0]=update_LSB_Load_val; update_reg2_ready=1;
        end

    end
    
    integer i;
    always @(posedge clk) begin
        //将这一周期的新指令放入下一周期的RS
        if (rst) begin RS_busy <= 0;end
        if (!rst && rdy)
        begin
            if (update_Decoder_valid) begin
                for (i=0; i < 31; i=i + 1)
                if (!RS_busy[i])
                begin
                    RS_busy[i] <= 1;
                    RS_opcode_id[i] <= update_opcode_id;
                    RS_ROB_pos[i] <= update_ROB_pos;
                    RS_vj[i] <= update_reg1;
                    RS_qj[i] <= update_reg1_ready;
    
                    if (opcode_id == `JALR || (!opcode_id[5] && !opcode_id[0] && opcode_id != `SUB)) begin //处理立即数
                        RS_imm[i] <= imm;
                        RS_vk[i] <= 0;
                        RS_qk[i] <=1;
                    end
                    else begin
                        RS_vk[i] <= update_reg2;
                        RS_imm[i] <= 0;
                        RS_qk[i] <= update_reg2_ready;
                    end    
                end
            end
             //用这一周期LSB_Load和RS产生的update更新下一周期的RS
            RS_busy[ex_pos]=1;
            for (i=0; i < 32; i=i + 1)
            if (RS_busy[i]) begin
                if (update_RS_valid && !RS_qj[i] && RS_vj[i][3:0] == update_RS_ROB_pos) begin
                    RS_vj[i] <= update_RS_val; RS_qj[i] <= 1;
                    end
                if (update_RS_valid && !RS_qk[i] && RS_vk[i][3:0] == update_RS_ROB_pos) begin
                    RS_vk[i] <= update_RS_val; RS_qk[i] <= 1;
                    end
                if (update_LSB_Load_valid && !RS_qj[i] && RS_vj[i][3:0] == update_LSB_Load_ROB_pos) begin
                    RS_vj[i] <= update_LSB_Load_val; RS_qj[i] <= 1;
                    end
                if (update_LSB_Load_valid && !RS_qk[i] && RS_vk[i][3:0] == update_LSB_Load_ROB_pos) begin
                    RS_vk[i] <= update_LSB_Load_val; RS_qk[i] <= 1;
                    end
            end 

        end
    end

endmodule
`endif