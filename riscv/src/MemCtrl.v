`ifndef MEMCTRL
`define MEMCTRL
`include "op_map.v"

//处理从RAM中读取的东西

//读入一条指令 到Icache

//处理 LSB中 load指令
//处理 LSB中 store指令
//有load/store 就先来 一条指令分为四个周期分别处理

module MemCtrl (
    input  wire             clk, 
    input  wire             rst, 
    input  wire             rdy,
    // RAM
    input  wire             io_buffer_full,
    input  wire [ 7:0]      mem_din,// data input bus
    output reg  [ 7:0]      mem_dout,// data output bus
    output reg  [31:0]      mem_a,// address bus (only 17:0 is used) write的位置 与mem_din 无关
    output reg              mem_wr,// write/read signal (1 for write)
    
    // 读入一条指令 到Icache
    input  wire             update_ICache,//是否有空间读入指令
    input  wire [31: 0]     ICache_address,
    output reg              ICache_complete,
    output reg  [31: 0]     ICache_value,

    //上一周期的LSB发出的请求 这一周期需要处理的指令
    input  wire             update_LSB,//是否有指令等待这一周期处理
    input  wire             update_LSB_Load,//是否有Load指令等待这一周期处理
    input  wire             update_LSB_Store,//是否有Store指令等待这一周期处理
    input  wire [31: 0]     update_LSB_value,
    input  wire [5 : 0]     update_LSB_opcode_ID,
    input  wire [31: 0]     update_LSB_address,

    output reg              LSB_complete,
    output reg  [31: 0]     LSB_out_value,
    input  wire             jump_wrong
);
/*
    wire    ICache_need_read_from_MemCtrl;
    wire [31: 0]   ICache_address_MemCtrl;
    wire    MemCtrl_output_instr_valid_ICache;
    wire [31: 0]    MemCtrl_output_instr_ICache;

    //上一周期的LSB发出的请求 这一周期需要处理的指令
    wire    LSB_send_update_LoadStore_to_memctrl;//是否有指令等待这一周期处理
    wire    LSB_send_update_Load_to_memctrl;//是否有Load指令等待这一周期处理
    wire    LSB_send_update_Store_to_memctrl;//是否有Store指令等待这一周期处理
    wire [31: 0]    LSB_send_value_to_memctrl;
    wire [5 : 0]    LSB_send_LS_opcode_ID_to_memctrl;
    wire [31: 0]    LSB_send_mem_address_to_memctrl;

    wire memctrl_update_finished_to_LSB;
    wire [31: 0] memctrl_send_LS_opcode_ID_to_LSB;
*/
    reg             IO_need_Stall;
    reg  [1:0]      LSB_cycle;
    reg  [1:0]      ICache_cycle;
    reg  [31:0]     LSB_value;
    reg  [31:0]     ICache_Instr;
    reg             last_ICache_flag;
    reg  [5:0]      opcode_ID;
    always @(*) begin
        mem_a=0;
        mem_dout =0;
        mem_wr=0;
        if (rdy) begin
            if (update_LSB) begin//最最前面一个周期为了得到iobuffer
                if (update_LSB_address[17:16]!= 3 || (!IO_need_Stall && !io_buffer_full))
                begin
                    if (update_LSB_Load) begin //load
                        mem_a=update_LSB_address + LSB_cycle;
                    end
                    else begin //store
                        mem_a=update_LSB_address + LSB_cycle;
                        mem_wr=1;
                        if (LSB_cycle==2'b00) begin mem_dout=update_LSB_value[ 7: 0]; end
                        if (LSB_cycle==2'b01) begin mem_dout=update_LSB_value[15: 8]; end
                        if (LSB_cycle==2'b10) begin mem_dout=update_LSB_value[23:16]; end
                        if (LSB_cycle==2'b11) begin mem_dout=update_LSB_value[31:24]; end
                    end
                end
            end
            else begin
                mem_a=ICache_address + ICache_cycle;
            end
        end

        if (opcode_ID==`LB) begin LSB_out_value={{24{mem_din[7]}},mem_din}; end
        if (opcode_ID==`LH) begin LSB_out_value={{16{mem_din[7]}},mem_din,LSB_value[7: 0]}; end
        if (opcode_ID==`LW) begin LSB_out_value={mem_din, LSB_value[23: 0]}; end
        if (opcode_ID==`LBU) begin  LSB_out_value={24'b0, mem_din}; end
        if (opcode_ID==`LHU) begin  LSB_out_value={16'b0, mem_din, LSB_value[7:0]}; end

        ICache_value={mem_din, ICache_Instr[23: 0]};
    end

    always @(posedge clk) begin

        if (rst) begin
            ICache_complete<=0;
            LSB_complete<=0;
            IO_need_Stall<=0;
            last_ICache_flag<=1;
            LSB_cycle<=0;
            ICache_cycle<=0;
        end
        if (!rst && rdy && jump_wrong) begin
            ICache_complete<=0;
            ICache_cycle<=0;
            if (!update_LSB_Load) begin
                LSB_complete<=0; 
                LSB_cycle<=0;
                IO_need_Stall<=0;
            end
        end 
        if (!rst && rdy && (!jump_wrong || !(update_LSB_Store)))
        begin
            opcode_ID<=update_LSB_opcode_ID;

            if (update_LSB) begin
                ICache_complete<=0;
                if ((!IO_need_Stall && !io_buffer_full)) begin
                    IO_need_Stall<=1;
                    if (update_LSB_opcode_ID== `LB || update_LSB_opcode_ID== `LBU || update_LSB_opcode_ID==`SB)   LSB_complete<=1;
                    if (update_LSB_opcode_ID== `LH || update_LSB_opcode_ID== `LHU || update_LSB_opcode_ID==`SH)   LSB_cycle[0]<=-(~LSB_cycle[0]);
                    if (update_LSB_opcode_ID== `LH || update_LSB_opcode_ID== `LHU || update_LSB_opcode_ID==`SH)   LSB_complete<=(LSB_cycle[0]==1);
                    if (update_LSB_opcode_ID== `LW || update_LSB_opcode_ID==`SW)   LSB_cycle<=-(~LSB_cycle);
                    if (update_LSB_opcode_ID== `LW || update_LSB_opcode_ID==`SW)   LSB_complete<=(LSB_cycle==3);
                end else begin
                    LSB_complete<=0;
                    IO_need_Stall<=0;
                end
                
                last_ICache_flag<=0;
                
                if (LSB_cycle==1) LSB_value[ 7: 0]<=mem_din;
                if (LSB_cycle==2) LSB_value[15: 8]<=mem_din;
                if (LSB_cycle==3) LSB_value[23:16]<=mem_din; 
                
            end else if (update_ICache) begin
                LSB_complete<=0;
                ICache_complete<=(ICache_cycle==3);

                IO_need_Stall<=1;
                last_ICache_flag<=1;
                ICache_cycle<=-(~ICache_cycle);
            end
            else begin
                ICache_complete<=0;
                LSB_complete<=0;

                last_ICache_flag<=0;;
                IO_need_Stall<=0;
            end

            if (last_ICache_flag) begin//由于无法在*中处理 同时update_ICache 和 update_lsb会出错
                case (ICache_cycle)
                    2'b01: ICache_Instr[ 7: 0]<=mem_din;
                    2'b10: ICache_Instr[15: 8]<=mem_din;
                    2'b11: ICache_Instr[23:16]<=mem_din;
                endcase
            end
        end
    end

endmodule
`endif