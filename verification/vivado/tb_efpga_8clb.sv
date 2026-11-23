`timescale 1ns/1ps
`default_nettype none
module tb_efpga_8clb;
    reg [7:0] ui_in = 0;
    reg [7:0] uio_in = 0;
    reg ena = 0;
    reg clk = 0;
    reg rst_n = 0;
    wire [7:0] uo_out, uio_out, uio_oe;
    reg [295:0] cfg;
    integer a;
    integer errors = 0;

    tt_um_free95_efpga8clb dut (
        .ui_in(ui_in), .uo_out(uo_out), .uio_in(uio_in),
        .uio_out(uio_out), .uio_oe(uio_oe),
        .ena(ena), .clk(clk), .rst_n(rst_n)
    );

    task pulse_fab_clk;
        begin
            #2 clk = 1'b1;
            #2 clk = 1'b0;
            #2;
        end
    endtask

    task check_eq;
        input [7:0] got;
        input [7:0] exp;
        input [255:0] what;
        begin
            if (got !== exp) begin
                $display("FAIL %0s: got %b expected %b at t=%0t", what, got, exp, $time);
                errors = errors + 1;
            end
        end
    endtask

    task set_lut;
        input integer clb_idx;
        input [15:0] truth;
        input use_ff;
        begin
            cfg[17*clb_idx +: 16] = truth;
            cfg[17*clb_idx+16] = use_ff;
        end
    endtask

    task set_s1_route;
        input integer clb_idx;
        input integer pin_idx;
        input [3:0] sel;
        begin
            cfg[136+(clb_idx*4+pin_idx)*4 +:4] = sel;
        end
    endtask

    task set_s2_route;
        input integer clb_idx;
        input integer pin_idx;
        input [3:0] sel;
        begin
            cfg[200+(clb_idx*4+pin_idx)*4 +:4] = sel;
        end
    endtask

    task set_output;
        input integer out_idx;
        input [3:0] sel;
        begin
            cfg[264+out_idx*4 +:4] = sel;
        end
    endtask

    // Send MSB first. cfg_sout before each shift is the old, outgoing MSB.
    task load_cfg;
        input [295:0] image;
        integer b;
        begin
            uio_in[0] = 1'b0; // enter programming mode
            #2;
            check_eq(uo_out, 8'h00, "outputs masked while programming");
            if (uio_out[7] !== 1'b1)
                $fatal(1, "cfg_active not asserted");
            for (b=295; b>=0; b=b-1) begin
                uio_in[1] = image[b];
                #2 uio_in[3] = 1'b1;
                #2 uio_in[3] = 1'b0;
                #1;
            end
            uio_in[1] = 1'b0;
            uio_in[0] = 1'b1; // operational mode
            #2;
            if (uio_out[7] !== 1'b0)
                $fatal(1, "cfg_active stuck high");
        end
    endtask

    task verify_readback;
        input [295:0] expected;
        integer b;
        begin
            uio_in[0] = 1'b0;
            #2;
            for (b=295; b>=0; b=b-1) begin
                if (uio_out[2] !== expected[b]) begin
                    $display("FAIL readback bit %0d", b);
                    errors = errors + 1;
                end
                // Restore the same image as it is shifted out.
                uio_in[1] = expected[b];
                #2 uio_in[3] = 1'b1;
                #2 uio_in[3] = 1'b0;
                #1;
            end
            uio_in[0] = 1'b1;
            uio_in[1] = 1'b0;
            #2;
        end
    endtask

    initial begin
        $dumpfile("efpga.vcd");
        $dumpvars(0, tb_efpga_8clb);
        // cfg_prog_n=1; fab_clk_en=1; fab_rst_n=1; ext=0.
        uio_in = 8'b0011_0001;
        #4 ena = 1'b1;
        #4 rst_n = 1'b1;
        #2;
        check_eq(uio_oe, 8'b1000_0100, "output enables");

        // TEST A: CLB0 = AND; CLB1 = XOR; CLB4 = XOR(CLB0,CLB1).
        cfg = 296'b0;
        set_lut(0, 16'h8888, 1'b0);  // in1 & in0
        set_lut(1, 16'h6666, 1'b0);  // in1 ^ in0
        set_lut(4, 16'h6666, 1'b0);
        set_s1_route(0,0,4'd0); set_s1_route(0,1,4'd1);
        set_s1_route(1,0,4'd0); set_s1_route(1,1,4'd1);
        set_s2_route(0,0,4'd9); set_s2_route(0,1,4'd10);
        set_output(0,4'd0);  // fabric output 0 <- CLB0
        set_output(1,4'd1);  // output 1 <- CLB1
        set_output(2,4'd4);  // output 2 <- CLB4
        load_cfg(cfg);
        verify_readback(cfg);
        for (a=0; a<4; a=a+1) begin
            ui_in = a;
            #2;
            check_eq(uo_out[2:0], {((a[0] & a[1]) ^ (a[0] ^ a[1])),
                                      (a[0] ^ a[1]),(a[0] & a[1])},
                     "AND XOR staged logic");
        end
        $display("TEST A: combinational LUT and Stage2 routing checked");

        // TEST B: Stage2 CLB4 FF captures XOR(ui0,ui1);
        // Stage1 CLB0 uses registered Stage2 feedback through mux code 9.
        cfg = 296'b0;
        set_lut(0, 16'hAAAA, 1'b0);  // pass LUT input[0]
        set_lut(4, 16'h6666, 1'b1);  // XOR with registered output
        set_s1_route(0,0,4'd9); // stage2 Q0, even when its bypass not selected
        set_s2_route(0,0,4'd0); set_s2_route(0,1,4'd1);
        set_output(0,4'd0);
        set_output(4,4'd4);
        load_cfg(cfg);
        uio_in[5] = 1'b0; #2;  // reset FF, preserve config
        uio_in[5] = 1'b1; #2;
        ui_in = 8'b0000_0001;
        #2 check_eq({7'b0,uo_out[0]}, 8'h00, "FF before clock");
        pulse_fab_clk();
        check_eq({7'b0,uo_out[0]}, 8'h01, "Stage2 registered feedback");
        check_eq({7'b0,uo_out[4]}, 8'h01, "Stage2 registered output");
        ui_in = 8'b0000_0011; // XOR=0 but Q should hold until next clock
        #2 check_eq({7'b0,uo_out[4]}, 8'h01, "FF state holds between clocks");
        uio_in[4] = 1'b0;
        pulse_fab_clk();
        check_eq({7'b0,uo_out[4]}, 8'h01, "FF clock enable disables updates");
        uio_in[4] = 1'b1;
        pulse_fab_clk();
        check_eq({7'b0,uo_out[4]}, 8'h00, "FF captures new XOR");
        check_eq({7'b0,uo_out[0]}, 8'h00, "feedback tracks FF update");
        $display("TEST B: FF, clock enable, reset, and feedback checked");

        // TEST C: ninth external input uio_in[6] and direct output mapping.
        cfg = 296'b0;
        set_lut(0, 16'hAAAA, 1'b0);
        set_s1_route(0, 0, 4'd8);   // use 9th input, fab_in_ext
        set_output(0, 4'd0);       // CLB0 output
        set_output(1, 4'd8);       // ui_in[0] direct bypass
        load_cfg(cfg);
        uio_in[6] = 1'b1;
        ui_in = 8'b0000_0000;
        #2 check_eq(uo_out[1:0], 8'b01, "external 9th input");
        uio_in[6] = 1'b0;
        ui_in = 8'b0000_0001;
        #2 check_eq(uo_out[1:0], 8'b10, "direct output mapping");
        $display("TEST C: ninth fabric input and output mapping checked");

        // TEST D: Reprogram the same fabric as a 4-bit up counter.
        // Stage 1 computes the next-state functions from Stage 2 Q0..Q3;
        // Stage 2 holds 4 registered counter bits.
        cfg = 296'b0;
        set_lut(0, 16'h5555, 1'b0); // next0 = ~Q0
        set_lut(1, 16'h6666, 1'b0); // next1 = Q1 XOR Q0
        set_lut(2, 16'h7878, 1'b0); // next2 = Q2 XOR (Q0 & Q1)
        set_lut(3, 16'h7F80, 1'b0); // next3 = Q3 XOR (Q0 & Q1 & Q2)
        for (a=0; a<4; a=a+1) begin
            set_s1_route(a,0,4'd9);        // feedback Q0
            if (a>=1) set_s1_route(a,1,4'd10); // Q1
            if (a>=2) set_s1_route(a,2,4'd11); // Q2
            if (a>=3) set_s1_route(a,3,4'd12); // Q3
            set_lut(a+4,16'hAAAA,1'b1); // register Stage1 combinational output
            set_s2_route(a,0,4'd9+a);   // Stage1 CLB[a]
            set_output(a,4'd4+a);      // observed Q[a]
            set_output(a+4,4'd4+a);    // duplicate 4-bit counter in upper nibble
        end
        load_cfg(cfg);
        verify_readback(cfg);
        uio_in[5] = 1'b0; #2; // reset only operational FFs
        uio_in[5] = 1'b1; #2;
        check_eq({4'b0,uo_out[3:0]},8'h00,"counter reset to zero");
        for (a=1; a<=32; a=a+1) begin
            pulse_fab_clk();
            check_eq({4'b0,uo_out[3:0]}, {4'b0,a[3:0]}, "4-bit counter and wrap");
        end
        uio_in[4] = 1'b0;
        pulse_fab_clk();
        check_eq({4'b0,uo_out[3:0]}, 8'h00, "counter frozen by clk_en");
        uio_in[4] = 1'b1;
        $display("TEST D: 4-bit counter wraparound and enable checked");

        // TEST E: 16 LUT4 addresses versus a nontrivial truth table.
        cfg = 296'b0;
        set_lut(0, 16'hA96C, 1'b0);
        for (a=0; a<4; a=a+1)
            set_s1_route(0,a,a[3:0]);
        set_output(0,4'd0);
        load_cfg(cfg);
        for (a=0; a<16; a=a+1) begin
            ui_in = a[7:0];
            #2;
            check_eq({7'b0,uo_out[0]}, ((16'hA96C >> a) & 8'h01), "LUT4 all addresses");
        end
        $display("TEST E: all LUT4 truth-table addresses checked");

        if (errors == 0) begin
            $display("PASS: all RTL directed tests (A-E) completed");
            $finish;
        end else $fatal(1, "FAIL: %0d checks failed", errors);
    end
endmodule
`default_nettype wire
