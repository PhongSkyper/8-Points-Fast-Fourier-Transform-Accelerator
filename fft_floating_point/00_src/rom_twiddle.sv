`timescale 1ns/1ps
module rom_twiddle (
    input  logic [1:0] i_addr,
    output logic [31:0] o_wr, o_wi,
    output logic        o_is_mj // 1 nếu -j
);
    always_comb begin
        case (i_addr)
            2'd0: begin o_wr=32'h3f800000; o_wi=32'h00000000; o_is_mj=1'b0; end // W0
            2'd1: begin o_wr=32'h3f3504f3; o_wi=32'hbf3504f3; o_is_mj=1'b0; end // W1
            2'd2: begin o_wr=32'h00000000; o_wi=32'hbf800000; o_is_mj=1'b1;  end // W2
            2'd3: begin o_wr=32'hbf3504f3; o_wi=32'hbf3504f3; o_is_mj=1'b0; end // W3
            default: begin o_wr=32'h3f800000; o_wi=32'h00000000; o_is_mj=1'b0; end
        endcase
    end
endmodule