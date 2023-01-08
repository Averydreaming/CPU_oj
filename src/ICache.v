`ifndef ICACHE
`define ICACHE
`include "op_map.v"

//first finish
//相当于 instruction queue 我的理解是为了解决循环问题
//每一个周期从内存拿一条指令
//每一个周期将一条指令拿去处理
module ICache (
    input  wire              clk,
    input  wire              rst,
    input  wire              rdy,
    //每一个周期从内存拿一条指令 from Memctrl
    output reg             ICache_need_update_instr,//可以输入一条指令
    output reg [31: 0]     instr_address,
    input  wire             instr_valid, //存在输入
    input  wire [31: 0]     instr,

    //每一个周期将一条IF pc需要的指令拿去InstructionFetch处理
    input  wire [31: 0]     pc,//从InstructionFetch获取的next周期需要的instr的pc
    output reg              instr_IF_valid, 
    output reg  [31: 0]     instr_IF,

    input  wire             jump_wrong

);

  
    reg  [31: 0]    cache_IQ       [511 : 0];
    reg  [511:0]    used_IQ;
    reg  [17: 11]    tag           [511 :0];//直接 cache[PC] 空间不够
    always @(*) begin
        //每一个周期从内存拿一条指令 from Memctrl
        ICache_need_update_instr=!(used_IQ[pc[10:2]] && tag[pc[10:2]]==pc[17:11]) && !instr_valid;//当前cache中pc位置没有需要的指令 且需要指令还没有读入
        instr_address=pc;
    end
    always @(posedge clk) begin
        if (rst) begin
            used_IQ<=0;
            instr_IF_valid<=0;
        end else if (rdy) begin
              //每一个周期从内存拿一条指令 from Memctrl
            if (instr_valid) begin
                            used_IQ[pc[10:2]]<=1;
                            cache_IQ[pc[10:2]]<=instr;
                            tag[pc[10:2]]<=pc[17:11];
            end
            //返回IF需要的指令
            //遇到br进行预测，然后找pc对应的指令在不在cache里,不在的话cache从内存里取
            if (jump_wrong)  instr_IF_valid<=0;
            else begin
                if (used_IQ[pc[10:2]] && tag[pc[10:2]] == pc[17:11]) begin
                    instr_IF_valid<=1;
                    instr_IF<=cache_IQ[pc[10:2]];
                end else begin
                    instr_IF_valid<=instr_valid;
                    instr_IF<=instr;
                end
            end
        end
    end

endmodule
`endif