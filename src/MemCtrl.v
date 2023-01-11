`include "defines.v"

module MemCtrl (
    input  wire             clk, rst, rdy, 
    input  wire             jump_wrong,                                  //
    // ICache
    input  wire             update_ICache, 
    input  wire [31: 0]     ICache_address, 
    output reg              ICache_complete, 
    output reg  [31: 0]     ICache_value, 

    // LSB
    input  wire             update_LSB, 
    input  wire [31: 0]     update_LSB_value, 
    input  wire [ 2: 0]     update_LSB_insty, 
    input  wire [31: 0]     update_LSB_address, 
    output reg              LSB_complete, 
    output reg  [31: 0]     LSB_out_value, 

    // RAM
    input  wire             io_buffer_full, 
    input  wire [ 7:0]      mem_din,	                            	// data input bus
    output reg  [ 7:0]      mem_dout,	                            	// data output bus
    output reg  [31:0]      mem_a,		                              	// address bus (only 17:0 is used)
    output reg              mem_wr 		                            	// write/read signal (1 for write)
);


    reg             IO_need_Stall;
    reg  [ 1: 0]    LSB_cycle, ICache_cycle;
    reg  [31: 0]    LSB_value, ICache_Instr;
    reg             last_is_IC;
    reg  [ 2: 0]    last_ICache_flag;
    wire            is_IO=update_LSB_address[17:16] == 2'b11;

    always @(*) begin
        if (rdy) begin
            mem_wr =0;
            if (update_LSB) begin
                if (is_IO && (IO_need_Stall || io_buffer_full)) begin
                    mem_a=0;
                    mem_dout=0;
                    mem_wr=0;
                end
                else begin 
                    if (!update_LSB_insty[2] || !update_LSB_insty[1:0]) begin
                        mem_a=update_LSB_address + LSB_cycle;
                        mem_dout=0;
                        mem_wr =0;
                    end
                    else begin
                        mem_a=update_LSB_address + LSB_cycle;
                        case (LSB_cycle)
                            2'b00: mem_dout=update_LSB_value[ 7: 0];
                            2'b01: mem_dout=update_LSB_value[15: 8];
                            2'b10: mem_dout=update_LSB_value[23:16];
                            2'b11: mem_dout=update_LSB_value[31:24];
                        endcase
                        mem_wr=1;
                    end
                end 
            end
            else begin
                mem_a=ICache_address + ICache_cycle;
                mem_dout=0;
                mem_wr =0;
            end

            end
        else begin
            mem_a=0;
            mem_dout=0;
            mem_wr=0;
        end

        case (last_ICache_flag)
            `LB : LSB_out_value={{24{mem_din[7]}}, mem_din};
            `LH : LSB_out_value={{16{mem_din[7]}}, mem_din, LSB_value[7: 0]};
            `LW : LSB_out_value={mem_din, LSB_value[23: 0]};
            `LBU: LSB_out_value={24'b0, mem_din};
            `LHU: LSB_out_value={16'b0, mem_din, LSB_value[7:0]};
            default: LSB_out_value=1'b0;
        endcase

        ICache_value={mem_din, ICache_Instr[23: 0]};
        
    end

    reg [31: 0] debug_now;
    always @(posedge clk) begin
        debug_now <= debug_now + 1;
        
        if (rst)
            debug_now <= 0;

        if (rst) begin
            ICache_complete <=0;
            LSB_complete <=0;
            IO_need_Stall <=0;
            last_is_IC <= 1;
            LSB_cycle <= 0;
            ICache_cycle <= 0;
        end 
        else if (!rdy) begin
            
        end 
        else if (jump_wrong) begin
            ICache_complete <=0;
            ICache_cycle <= 0;
            if (!update_LSB || !(update_LSB_insty == `SB || update_LSB_insty == `SH || update_LSB_insty == `SW)) begin
                LSB_complete <=0; 
                LSB_cycle <= 0;
                IO_need_Stall <=0;
            end
        end
        
        if (!rst && rdy && (!jump_wrong || (update_LSB && update_LSB_insty[2] && update_LSB_insty[1:0] != 0)))
        begin
            last_ICache_flag <= update_LSB_insty;
            
            if (update_LSB) begin
                case (LSB_cycle)
                    2'b01: LSB_value[ 7: 0] <= mem_din;
                    2'b10: LSB_value[15: 8] <= mem_din;
                    2'b11: LSB_value[23:16] <= mem_din;
                endcase

                if ((!IO_need_Stall && !io_buffer_full) || !is_IO)
                begin
                    case (update_LSB_insty)
                        `LB: begin
                            LSB_complete <= 1;
                            IO_need_Stall <= 1;
                        end 
                        `LH: begin
                            LSB_complete <= LSB_cycle[0] == 1'b1;
                            LSB_cycle[0] <= -(~LSB_cycle[0]);
                            IO_need_Stall <= 1;
                        end
                        `LW: begin
                            LSB_complete <= LSB_cycle == 2'b11;
                            LSB_cycle <= -(~LSB_cycle);
                            IO_need_Stall <= 1;
                        end
                        `LBU: begin
                            LSB_complete <= 1;
                            IO_need_Stall <= 1;
                        end
                        `LHU: begin
                            LSB_complete <= LSB_cycle[0] == 1'b1;
                            LSB_cycle[0] <= -(~LSB_cycle[0]);
                            IO_need_Stall <= 1;
                        end
                        `SB: begin
                            LSB_complete <= 1;
                            IO_need_Stall <= 1;
                        end
                        `SH: begin
                            LSB_complete <= LSB_cycle[0] == 1'b1;
                            LSB_cycle[0] <= -(~LSB_cycle[0]);
                            IO_need_Stall <= 1;
                        end
                        `SW: begin
                            LSB_complete <= LSB_cycle == 2'b11;
                            LSB_cycle <= -(~LSB_cycle);
                            IO_need_Stall <= 1;
                        end
                    endcase
                end
                else begin
                    LSB_complete <=0;
                    IO_need_Stall <=0;
                end
                ICache_complete <=0;
                last_is_IC <=0;
            end
            else if (update_ICache) begin
                ICache_complete <= ICache_cycle == 2'b11;
                IO_need_Stall <= 1;
                last_is_IC <= 1;
                ICache_cycle <= -(~ICache_cycle);
                LSB_complete <=0;
            end
            else begin
                ICache_complete <=0;
                LSB_complete <=0;
                last_is_IC <=0;;
                IO_need_Stall <=0;
            end

            if (last_is_IC) begin
                case (ICache_cycle)
                    2'b01: ICache_Instr[ 7: 0] <= mem_din;
                    2'b10: ICache_Instr[15: 8] <= mem_din;
                    2'b11: ICache_Instr[23:16] <= mem_din;
                endcase
            end
        end 
    end

endmodule