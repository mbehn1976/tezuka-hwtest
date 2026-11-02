`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 0, valid_in = 0, en0 = 1, en1 = 0, zero_count = 0;
    reg [15:0] I0 = 0, Q0 = 0;
    wire [15:0] a0, a1, b0, b1;
    wire av, bv, af, bf, abs, bbs, ae1, ae2, be1, be2;
    cs12_8mux_old o(.clk(clk), .rst_n(rst_n), .I0(I0), .Q0(Q0), .valid_in(valid_in), .Enable0(en0), .Enable1(en1),
        .zero_count(zero_count), .data_out0(a0), .data_out1(a1), .valid_out(av), .burst_sync(abs), .frame_start(af),
        .Enable_O1(ae1), .Enable_O2(ae2));
    cs12_8mux n(.clk(clk), .rst_n(rst_n), .I0(I0), .Q0(Q0), .valid_in(valid_in), .Enable0(en0), .Enable1(en1),
        .zero_count(zero_count), .data_out0(b0), .data_out1(b1), .valid_out(bv), .burst_sync(bbs), .frame_start(bf),
        .Enable_O1(be1), .Enable_O2(be2));
    always #5 clk = ~clk;
    integer i, cycles = 0, mism = 0, accbit13 = 0, cs8_outputs = 0, accbad = 0;
    integer truesum;
    always @(posedge clk) if (rst_n) begin
        cycles = cycles + 1;
        if (av && en0 && !en1) cs8_outputs = cs8_outputs + 1;
        if ({a0,a1,av,af,abs,ae1,ae2} !== {b0,b1,bv,bf,bbs,be1,be2} || o.err_i !== n.err_i || o.err_q !== n.err_q) begin
            mism = mism + 1;
            if (mism < 5) $display("MISMATCH cycle %0d mode %b%b I0 %h: old %h/%h/%b err %0d, new %h/%h/%b err %0d",
                cycles, en0, en1, I0, a0, a1, av, o.err_i, b0, b1, bv, n.err_i);
        end
        if (o.acc_i_w[13] !== n.acc_i_w[13]) accbit13 = accbit13 + 1;
        truesum = $signed(I0[11:0]) + n.err_i;
        if (n.acc_i_w !== truesum[13:0]) accbad = accbad + 1;
    end
    initial begin
        repeat (3) @(negedge clk); rst_n = 1;
        // full sweep of every 12-bit I and Q in CS8 mode, valid every cycle
        for (i = 0; i < 4096 * 4; i = i + 1) begin
            @(negedge clk); valid_in = 1; I0 = {{4{i[11]}}, i[11:0]}; Q0 = {{4{i[13]}}, i[13:2]};
        end
        // random stimulus, random valid, all three modes
        for (i = 0; i < 3000000; i = i + 1) begin
            @(negedge clk);
            valid_in = ($random & 3) != 0;
            I0 = $random; Q0 = $random;
            if (i % 50000 == 0) {en0, en1} = (i / 50000) % 3 == 0 ? 2'b10 : ((i / 50000) % 3 == 1 ? 2'b11 : 2'b01);
            if (i % 200000 == 0) {en0, en1} = 2'b10;
            zero_count = (en0 == 0 && en1 == 1) ? (($random & 255) == 0) : 0;
        end
        $display("cycles %0d, CS8 outputs %0d, output/state mismatches %0d, cycles where old acc_i_w[13] differed %0d, new acc_i_w != true signed sum %0d",
                 cycles, cs8_outputs, mism, accbit13, accbad);
        $finish;
    end
endmodule
