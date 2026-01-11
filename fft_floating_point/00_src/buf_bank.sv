`timescale 1ns/1ps
// 8x32 reg-bank, 2 cổng ghi (load, wb_a/b) và 3 cổng đọc (A, B, OUT)

module buf_bank (
    input  logic        clk,
    input  logic        rst_n,
    // load port
    input  logic        load_en,
    input  logic [2:0]  load_addr,
    input  logic [31:0] load_re,
    input  logic [31:0] load_im,
    // writeback ports (ưu tiên tuần tự: load -> wb_a -> wb_b)
    input  logic        wb_en_a,
    input  logic [2:0]  wb_addr_a,
    input  logic [31:0] wb_re_a,
    input  logic [31:0] wb_im_a,
    input  logic        wb_en_b,
    input  logic [2:0]  wb_addr_b,
    input  logic [31:0] wb_re_b,
    input  logic [31:0] wb_im_b,
    // read ports
    input  logic [2:0]  rd_addr_a,
    input  logic [2:0]  rd_addr_b,
    input  logic [2:0]  rd_addr_out,
    output logic [31:0] rd_re_a,
    output logic [31:0] rd_im_a,
    output logic [31:0] rd_re_b,
    output logic [31:0] rd_im_b,
    output logic [31:0] rd_re_out,
    output logic [31:0] rd_im_out
);
    logic [31:0] mem_re[0:7], mem_im[0:7];
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0;i<8;i++) begin mem_re[i] <= 32'd0; mem_im[i] <= 32'd0; end
        end else begin
            if (load_en) begin
                mem_re[load_addr] <= load_re;
                mem_im[load_addr] <= load_im;
            end
            if (wb_en_a) begin
                mem_re[wb_addr_a] <= wb_re_a;
                mem_im[wb_addr_a] <= wb_im_a;
            end
            if (wb_en_b) begin
                mem_re[wb_addr_b] <= wb_re_b;
                mem_im[wb_addr_b] <= wb_im_b;
            end
        end
    end
    assign rd_re_a   = mem_re[rd_addr_a];
    assign rd_im_a   = mem_im[rd_addr_a];
    assign rd_re_b   = mem_re[rd_addr_b];
    assign rd_im_b   = mem_im[rd_addr_b];
    assign rd_re_out = mem_re[rd_addr_out];
    assign rd_im_out = mem_im[rd_addr_out];
endmodule