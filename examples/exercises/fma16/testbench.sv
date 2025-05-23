/* verilator lint_off STMTDLY */
module testbench_fma16;
  logic        clk, reset;
  logic [15:0] x, y, z, rexpected, result;
  logic [7:0]  ctrl;
  logic        mul, add, negp, negz;
  logic [1:0]  roundmode;
  logic [31:0] vectornum, errors;
  logic [75:0] testvectors[100000:0];
  logic [3:0]  flags, flagsexpected; // Invalid, Overflow, Underflow, Inexact

  // instantiate device under test
  fma16 dut(x, y, z, mul, add, negp, negz, roundmode, result, flags);

  // generate clock
  always 
    begin
      clk = 1; #5; clk = 0; #5;
    end

  // at start of test, load vectors and pulse reset
  initial
    begin
      // $readmemh("tests/fmul_0.tv", testvectors);
      // $readmemh("work/fmul_1.tv", testvectors);
      // $readmemh("work/fmul_2.tv", testvectors);
      // $readmemh("work/fadd_0.tv", testvectors);
      // $readmemh("work/fadd_1.tv", testvectors);
      // $readmemh("work/fadd_2.tv", testvectors);
      // $readmemh("work/fma_0.tv", testvectors);
      // $readmemh("work/fma_1.tv", testvectors);
      // $readmemh("work/fma_2.tv", testvectors);
      // $readmemh("tests/fma_special_rz.tv", testvectors);
      $readmemh("tests/fma_special_rm.tv", testvectors);
      // $readmemh("tests/fma_special_rne.tv", testvectors);
      // $readmemh("tests/fma_special_rp.tv", testvectors);
      // $readmemh("tests/baby_torture_rz.tv", testvectors);
      // $readmemh("tests/baby_torture.tv", testvectors);
      // $readmemh("tests/fmul_2.tv", testvectors);
      // $readmemh("tests/fadd_2.tv", testvectors);
      // $readmemh("tests/fma_2.tv", testvectors);
      // $readmemh("tests/additional_tests_2.tv", testvectors);
      // $readmemh("tests/torture.tv", testvectors);
      vectornum = 0; errors = 0;
      reset = 1; #22; reset = 0;
    end

  // apply test vectors on rising edge of clk
  always @(posedge clk)
    begin
      #1; {x, y, z, ctrl, rexpected, flagsexpected} = testvectors[vectornum];
      {roundmode, mul, add, negp, negz} = ctrl[5:0];
    end

  // check results on falling edge of clk
  always @(negedge clk)
    if (~reset) begin // skip during reset
      if (result !== rexpected & flagsexpected[1]!=1'b1  /*| flags !== flagsexpected */) begin  // check result
        $display("Error: inputs %h * %h + %h", x, y, z);
        $display("  result = %h (%h expected) flags = %b (%b expected), mul = %b, add = %b, roundmode = %b", 
          result, rexpected, flags, flagsexpected, mul, add, roundmode);
        errors = errors + 1;
      end
      vectornum = vectornum + 1;
      if (testvectors[vectornum] === 'x) begin 
        $display("%d tests completed with %d errors", 
	           vectornum, errors);
        $stop;
      end
    end
endmodule
