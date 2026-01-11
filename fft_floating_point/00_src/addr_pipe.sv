`timescale 1ns/1ps
(* keep_hierarchy = "yes" *)
module addr_pipe #(
    parameter int LAT = 7
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       v_in,
    input  logic [2:0] a_in,
    input  logic [2:0] b_in,
    output logic       v_out,
    output logic [2:0] a_out,
    output logic [2:0] b_out
);
    logic [LAT-1:0] v;
    logic [2:0] a[LAT-1:0], b[LAT-1:0];
    genvar i;
    generate
        for (i=0; i<LAT; i++) begin : G_AP
            if (i==0) begin
                dffr #(.W(1))  dv (.clk(clk), .rst_n(rst_n), .d(v_in),   .q(v[i]));
                dffr #(.W(3))  da (.clk(clk), .rst_n(rst_n), .d(a_in),   .q(a[i]));
                dffr #(.W(3))  db (.clk(clk), .rst_n(rst_n), .d(b_in),   .q(b[i]));
            end else begin
                dffr #(.W(1))  dv (.clk(clk), .rst_n(rst_n), .d(v[i-1]), .q(v[i]));
                dffr #(.W(3))  da (.clk(clk), .rst_n(rst_n), .d(a[i-1]), .q(a[i]));
                dffr #(.W(3))  db (.clk(clk), .rst_n(rst_n), .d(b[i-1]), .q(b[i]));
            end
        end
    endgenerate
    assign v_out = v[LAT-1];
    assign a_out = a[LAT-1];
    assign b_out = b[LAT-1];
endmodule