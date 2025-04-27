// Daniel Fajardo
// dfajardo@g.hmc.edu
// 2/8/2025

module fma16(input logic [15:0] x, y, z,
        input logic mul, add, negp, negz,
        input logic [1:0] roundmode,
        output logic [15:0] result,
        output logic [3:0] flags);

        // fmul_0 fmul_0(x, y, z, mul, add, negp, negz, roundmode, result, flags);
        // fmul_1 fmul_1(x, y, z, mul, add, negp, negz, roundmode, result, flags);
        // fmul_2 fmul_2(x, y, z, mul, add, negp, negz, roundmode, result, flags);
        // fadd_0 fadd_0(x, y, z, mul, add, negp, negz, roundmode, result, flags);
        // fadd_1 fadd_1(x, y, z, mul, add, negp, negz, roundmode, result, flags);
        // fadd_2 fadd_2(x, y, z, mul, add, negp, negz, roundmode, result, flags);
        // fma_0 fma_0(x, y, z, mul, add, negp, negz, roundmode, result, flags);
        // fma_1 fma_1(x, y, z, mul, add, negp, negz, roundmode, result, flags);
        // fma_2 fma_2(x, y, z, mul, add, negp, negz, roundmode, result, flags);
        fma_special_rz fma_special_rz(x, y, z, mul, add, negp, negz, roundmode, result, flags);

endmodule

// fmul_0 multiplies two positive half-precision floats with exponents of 0
// the two inputs will be 16 bits
// the sign bit will be 0, and the bias will be 15, ie the two inputs will be of the form 0_01111_xxxxxxxxxx
module fmul_0(input logic [15:0] x, y, z,
        input logic mul, add, negp, negz,
        input logic [1:0] roundmode,
        output logic [15:0] result,
        output logic [3:0] flags);
        logic [9:0] fx, fy;
        logic [10:0] fresult;
        logic [19:0] fxfy;
        logic [4:0] exp;

        assign fx = x[9:0];
        assign fy = y[9:0];
        // fresult = fx + fy + (fx*fy)
        assign fxfy = fx*fy;
        assign fresult = ({1'b0,fx} + {1'b0,fy}) + {1'b0,fxfy[19:10]};
        always_comb begin
                // if fc is >1, change exponent output bias to 16
                if (fresult[10]) begin
                        exp = 5'b10000;
                        result = {1'b0, exp, 1'b0, fresult[9:1]};
                end
                else begin 
                        exp = 5'b01111;
                        result = {1'b0, exp, fresult[9:0]};
                        end
        end
        assign flags = 4'b0000;       
endmodule

// fmul_1 multiplies two positive half-precision floats
// the two inputs and output will be 16 bits
module fmul_1(input logic [15:0] x, y, z,
        input logic mul, add, negp, negz,
        input logic [1:0] roundmode,
        output logic [15:0] result,
        output logic [3:0] flags);
        logic [10:0] Xm, Ym;
        logic [21:0] Pm;
        logic [9:0] Mm;
        logic [4:0] Xe, Ye, Pe, Me;

        assign Xm = {1'b1, x[9:0]};
        assign Ym = {1'b1, y[9:0]};
        assign Xe = x[14:10];
        assign Ye = y[14:10];

        
        // 1. Multiply the significands of X and Y: Pm = Xm × Ym
        assign Pm = Xm * Ym;
        // 2. Add the exponents of X and Y: Pe = Xe + Ye – bias
        assign Pe = Xe + Ye - 15;
        // 3. Determine the alignment shift count: Acnt = (Pe – Ze)
        // Acnt = Pe
        // 4. Shift the significand of Z into alignment: Am = Zm ≫ Acnt
        // Zm = 0 so not needed
        // 5. Add the aligned significands: Sm = Pm + Am
        // not needed for multiplication only
        // 6. Find the leading 1 for normalization shift: Mcnt = # of bits to shift
        // 7. Shift the result to renormalize: Mm = Sm ≪ Mcnt; Me = Pe – Mcnt
        always_comb begin
                // Special cases +0=00..00..0 -0=10..00..0 subnormal=x00000x..x +inf=0111110..0 -inf=1111110..0 NaN=x11111x..x
                if (Xe==5'b00000|Ye==5'b00000) // check for special cases
                        if (Xm==11'b100000_00000|Ym==11'b10000_00000) begin // check if input is 0
                                Mm = 10'b00000_00000;
                                Me = 5'b00000; end
                        else begin // input is subnormal
                                Mm = 10'b10000_00000;
                                Me = 5'b00000; end
                else if (Xe==5'b11111|Ye==5'b11111) // check for other special cases
                        if (Xm==11'b100000_00000|Ym==11'b10000_00000) begin // check if input is inf
                                Mm = 10'b00000_00000;
                                Me = 5'b11111; end
                        else begin // input is NaN
                                Mm = 10'b10000_00000;
                                Me = 5'b11111; end
                else if (Pm[21]) begin // check for overflow bit
                        Mm = Pm[20:11];
                        Me = Pe + 1; end // increment exponent
                else begin
                        Mm = Pm[19:10];
                        Me = Pe; end
        end
        // 8. Round the result: R = round(M)
        // 9. Handle flags and special cases: W = specialcase(R, X, Y, Z)

        assign result = {1'b0, Me, Mm}; // sign hard coded to be positive
        // identify rounding mode and determine whether to trunc or rnd based on LRT (pg 10)
        assign flags = 4'b0000; // no flags set
endmodule

// fmul_2 multiplies two signed half-precision floats
// the two inputs and output will be 16 bits
module fmul_2(input logic [15:0] x, y, z,
        input logic mul, add, negp, negz,
        input logic [1:0] roundmode,
        output logic [15:0] result,
        output logic [3:0] flags);
        logic [10:0] Xm, Ym;
        logic [21:0] Pm;
        logic [9:0] Mm;
        logic [4:0] Xe, Ye, Pe, Me;
        logic sign;

        assign Xm = {1'b1, x[9:0]};
        assign Ym = {1'b1, y[9:0]};
        assign Xe = x[14:10];
        assign Ye = y[14:10];
        assign sign = x[15] ^ y[15];

        
        // 1. Multiply the significands of X and Y: Pm = Xm × Ym
        assign Pm = Xm * Ym;
        // 2. Add the exponents of X and Y: Pe = Xe + Ye – bias
        assign Pe = Xe + Ye - 15;
        // 3. Determine the alignment shift count: Acnt = (Pe – Ze)
        // Acnt = Pe
        // 4. Shift the significand of Z into alignment: Am = Zm ≫ Acnt
        // Zm = 0 so not needed
        // 5. Add the aligned significands: Sm = Pm + Am
        // not needed for multiplication only
        // 6. Find the leading 1 for normalization shift: Mcnt = # of bits to shift
        // 7. Shift the result to renormalize: Mm = Sm ≪ Mcnt; Me = Pe – Mcnt
        always_comb begin
                // Special cases +0=00..00..0 -0=10..00..0 subnormal=x00000x..x +inf=0111110..0 -inf=1111110..0 NaN=x11111x..x
                if (Xe==5'b00000|Ye==5'b00000) // check for special cases
                        if (Xm==11'b100000_00000|Ym==11'b10000_00000) begin // check if input is 0
                                Mm = 10'b00000_00000;
                                Me = 5'b00000; end
                        else begin // input is subnormal
                                Mm = 10'b10000_00000;
                                Me = 5'b00000; end
                else if (Xe==5'b11111|Ye==5'b11111) // check for other special cases
                        if (Xm==11'b100000_00000|Ym==11'b10000_00000) begin // check if input is inf
                                Mm = 10'b00000_00000;
                                Me = 5'b11111; end
                        else begin // input is NaN
                                Mm = 10'b10000_00000;
                                Me = 5'b11111; end
                else if (Pm[21]) begin // check for overflow bit
                        Mm = Pm[20:11];
                        Me = Pe + 1; end // increment exponent
                else begin
                        Mm = Pm[19:10];
                        Me = Pe; end
        end
        // 8. Round the result: R = round(M)
        // 9. Handle flags and special cases: W = specialcase(R, X, Y, Z)

        assign result = {sign, Me, Mm}; // sign hard coded to be positive
        // identify rounding mode and determine whether to trunc or rnd based on LRT (pg 10)
        assign flags = 4'b0000; // no flags set
endmodule

// fadd_0 adds two positive half-precision floats with exponents of 0
module fadd_0(input logic [15:0] x, y, z,
        input logic mul, add, negp, negz,
        input logic [1:0] roundmode,
        output logic [15:0] result,
        output logic [3:0] flags);
        logic [10:0] Xm, Zm;
        logic [11:0] Sm;
        logic [9:0] Mm;
        logic [4:0] Xe, Ze;

        assign Xm = {1'b1, x[9:0]};
        assign Zm = {1'b1, z[9:0]};
        assign Sm = Xm + Zm; // sum will be one bit larger than inputs
        assign Mm = Sm[10:1]; // drop implicit 1

        assign result = {1'b0, 5'b10000, Mm}; // sign hard coded to be positive and exponent to be 1
        // identify rounding mode and determine whether to trunc or rnd based on LRT (pg 10)
        assign flags = 4'b0000; // no flags set
endmodule

// fadd_1 adds two positive half-precision floats
module fadd_1(input logic [15:0] x, y, z,
        input logic mul, add, negp, negz,
        input logic [1:0] roundmode,
        output logic [15:0] result,
        output logic [3:0] flags);
        logic [11:0] Xm, Zm;
        logic [11:0] Sm, Mm;
        logic [4:0] Xe, Ze, Pe, Mcnt, Me;

        assign Xm = {2'b01, x[9:0]};
        assign Zm = {2'b01, z[9:0]};
        assign Xe = x[14:10];
        assign Ze = z[14:10];

        // Pm = Xm * Ym = Xm * 1 = Xm
        // Pe = Xe + Ye = Xe + 0 = Xe (or Pe = Ze if Ze>Xe)
        assign Pe = (Xe>Ze) ? Xe : Ze;
        // Acnt = (Pe - Ze) = (Xe - Ze)
        // Am = Zm >> Acnt = Zm >> (Xe - Ze)
        // Sm = Pm + Am = Xm + Am
        // if Xe>Ze, Sm = Xm + (Zm >> (Xe - Ze)) 
        // if Xe<Ze, Sm = Zm + (Xm >> (Ze - Xe))
        always_comb begin
                if (Xe>Ze)      Sm = Xm + (Zm >> (Xe - Ze));
                else if (Xe<Ze) Sm = Zm + (Xm >> (Ze - Xe));
                else            Sm = Xm + Zm;
        // Mcnt = # bits to shift
                casez (Sm)
                        12'b1???????????: Mcnt = 0;
                        12'b01??????????: Mcnt = 1;
                        12'b001?????????: Mcnt = 2;
                        12'b0001????????: Mcnt = 3;
                        12'b00001???????: Mcnt = 4;
                        12'b000001??????: Mcnt = 5;
                        12'b0000001?????: Mcnt = 6;
                        12'b00000001????: Mcnt = 7;
                        12'b000000001???: Mcnt = 8;
                        12'b0000000001??: Mcnt = 9;
                        12'b00000000001?: Mcnt = 10;
                        12'b000000000001: Mcnt = 11;
                        default: Mcnt = 0;
                endcase
        end
        // Mm = Sm << Mcnt; Me = Pe - Mcnt + 1
        assign Mm = (Sm << Mcnt);
        assign Me = Pe - Mcnt + 1;

        assign result = {1'b0, Me, Mm[10:1]};
        assign flags = 4'b0000; // no flags set
endmodule

// fadd_2 adds two signed half-precision floats
module fadd_2(input logic [15:0] x, y, z,
        input logic mul, add, negp, negz,
        input logic [1:0] roundmode,
        output logic [15:0] result,
        output logic [3:0] flags);
        logic [31:0] Xm, Zm, Sm;
        logic [9:0] Mm;
        logic [4:0] Xe, Ze, Pe, Mcnt, Me;
        logic sub, sign;

        assign Xm = {2'b01, x[9:0], 20'b0}; // extended bitsize
        assign Zm = {2'b01, z[9:0], 20'b0};
        assign Xe = x[14:10];
        assign Ze = z[14:10];
        assign sub = x[15] ^ z[15];

        // Pm = Xm * Ym = Xm * 1 = Xm
        // Pe = Xe + Ye = Xe + 0 = Xe (or Pe = Ze if Ze>Xe)
        assign Pe = (Xe>Ze) ? Xe : Ze; // determine large exponent
        // Acnt = (Pe - Ze) = (Xe - Ze)
        // Am = Zm >> Acnt = Zm >> (Xe - Ze)
        // Sm = Pm + Am = Xm + Am
        // if Xe>Ze, Sm = Xm + (Zm >> (Xe - Ze)) 
        // if Xe<Ze, Sm = Zm + (Xm >> (Ze - Xe))
        always_comb begin
                if (sub) // need to subtract smaller from larger
                        if (Xe>Ze) begin
                                Sm = Xm - (Zm >> (Xe - Ze));
                                sign = x[15]; end
                        else if (Xe<Ze) begin
                                Sm = Zm - (Xm >> (Ze - Xe));
                                sign = z[15]; 
                                $display("Xm:%b, Zm:%b, Sm:%b", Xm, Zm, Sm);end
                        else
                                if (Xm>Zm) begin
                                        Sm = Xm - Zm;
                                        sign = x[15]; end
                                else if (Zm>Xm) begin
                                        Sm = Zm - Xm;
                                        sign = z[15]; end
                                else begin
                                        Sm = 0;
                                        sign = 0; end
                else begin
                        sign = x[15]; // sign will remain the same
                        if (Xe>Ze)      Sm = Xm + (Zm >> (Xe - Ze));
                        else if (Xe<Ze) Sm = Zm + (Xm >> (Ze - Xe));
                        else            Sm = Xm + Zm;
                        end
        // Mcnt = # bits to shift
                casez (Sm[31:19])
                        13'b1????????????: Mcnt = 0;
                        13'b01???????????: Mcnt = 1;
                        13'b001??????????: Mcnt = 2;
                        13'b0001?????????: Mcnt = 3;
                        13'b00001????????: Mcnt = 4;
                        13'b000001???????: Mcnt = 5;
                        13'b0000001??????: Mcnt = 6;
                        13'b00000001?????: Mcnt = 7;
                        13'b000000001????: Mcnt = 8;
                        13'b0000000001???: Mcnt = 9;
                        13'b00000000001??: Mcnt = 10;
                        13'b000000000001?: Mcnt = 11;
                        13'b0000000000001: Mcnt = 12;
                        default: Mcnt = 13;
                endcase
        end
        // Mm = Sm << Mcnt; Me = Pe - Mcnt + 1
        assign Mm = {(Sm << Mcnt)}[30:21]; // need to truncate and drop implicit 1
        assign Me = (Mcnt!=13) ? Pe - Mcnt + 1 : 0;

        assign result = {sign, Me, Mm};
        assign flags = 4'b0000; // no flags set
endmodule

// fma_0 performs fma on three positive half-precision floats with exponents of 0
module fma_0(input logic [15:0] x, y, z,
        input logic mul, add, negp, negz,
        input logic [1:0] roundmode,
        output logic [15:0] result,
        output logic [3:0] flags);
        logic [10:0] Xm, Ym;
        logic [21:0] Zm, Pm;
        logic [22:0] Sm;
        logic [9:0] Mm;
        logic [4:0] Xe, Ye, Ze, Me;
        logic [1:0] Mcnt;

        assign Xm = {1'b1, x[9:0]};
        assign Ym = {1'b1, y[9:0]};
        assign Zm = {2'b01, z[9:0], 10'b0};
        assign Xe = x[14:10];
        assign Ye = y[14:10];
        assign Ze = z[14:10];

        // 1. Multiply the significands of X and Y: Pm = Xm × Ym
        assign Pm = Xm * Ym;
        // 2. Add the exponents of X and Y: Pe = Xe + Ye – bias
        // Pe = Xe = Ye
        // 3. Determine the alignment shift count: Acnt = (Pe – Ze)
        // Acnt = 0
        // 4. Shift the significand of Z into alignment: Am = Zm ≫ Acnt
        // Am = Zm
        // 5. Add the aligned significands: Sm = Pm + Am
        assign Sm = Pm + Zm;
        // 6. Find the leading 1 for normalization shift: Mcnt = # of bits to shift
        // 7. Shift the result to renormalize: Mm = Sm ≪ Mcnt; Me = Pe – Mcnt
        assign Mcnt = Sm[22] ? 2'b00 : (Sm[21] ? 2'b01 : 2'b10);
        // always_comb begin $display("Sm: %b, Mcnt: %b", Sm, Mcnt); end
        assign Mm = (Mcnt[1]|Mcnt[0]) ? (Mcnt[1] ? (Sm[21:12]) : (Sm[20:11])) : (Sm[19:10]);
        assign Me = (Mcnt[0]) ? (Mcnt[1] ? 5'b10001 : 5'b10000) : 5'b01111;
        // 8. Round the result: R = round(M)
        // 9. Handle flags and special cases: W = specialcase(R, X, Y, Z)
        assign result = {1'b0, Me, Mm};
        assign flags = 4'b0000; // no flags set
endmodule

// fma_1 performs fma on three positive half-precision floats
module fma_1(input logic [15:0] x, y, z,
        input logic mul, add, negp, negz,
        input logic [1:0] roundmode,
        output logic [15:0] result,
        output logic [3:0] flags);
        logic [10:0] Xm, Ym;
        logic [21:0] Zm, Am, Pm;
        logic [21:0] Sm;
        logic [21:0] Mm;
        logic [4:0] Xe, Ye, Ze, Pe, Acnt, Mcnt, Me;

        assign Xm = {1'b1, x[9:0]};
        assign Ym = {1'b1, y[9:0]};
        assign Zm = {2'b01, z[9:0], 10'b0};
        assign Xe = x[14:10];
        assign Ye = y[14:10];
        assign Ze = z[14:10];

        // 1. Multiply the significands of X and Y: Pm = Xm × Ym
        assign Pm = Xm * Ym;
        // always_comb begin $display("Pm: %b, Zm: %b", Pm, Zm); end
        // 2. Add the exponents of X and Y: Pe = Xe + Ye – bias
        assign Pe = Xe + Ye - 15;
        always_comb begin $display("Pm: %b, Zm: %b", Pm, Zm, " Pe: %b, Ze: %b", Pe, Ze); end
        // 3. Determine the alignment shift count: Acnt = (Pe – Ze)
        // assign Acnt = (Pe - Ze)
        assign Acnt = (Pe>=Ze) ? (Pe - Ze) : (Ze - Pe);
        // 4. Shift the significand of Z into alignment: Am = Zm ≫ Acnt
        // assign Am = Zm >> Acnt;
        // 5. Add the aligned significands: Sm = Pm + Am
        // assign Sm = Pm + Am;
        assign Sm = (Pe>=Ze) ? Pm + (Zm >> Acnt) : Zm + (Pm >> Acnt);
        // 6. Find the leading 1 for normalization shift: Mcnt = # of bits to shift
        // 7. Shift the result to renormalize: Mm = Sm ≪ Mcnt; Me = Pe – Mcnt
        always_comb
                casez (Sm[21:10])
                        12'b1???????????: Mcnt = 0;
                        12'b01??????????: Mcnt = 1;
                        12'b001?????????: Mcnt = 2;
                        12'b0001????????: Mcnt = 3;
                        12'b00001???????: Mcnt = 4;
                        12'b000001??????: Mcnt = 5;
                        12'b0000001?????: Mcnt = 6;
                        12'b00000001????: Mcnt = 7;
                        12'b000000001???: Mcnt = 8;
                        12'b0000000001??: Mcnt = 9;
                        12'b00000000001?: Mcnt = 10;
                        12'b000000000001: Mcnt = 11;
                        default: Mcnt = 0;
                endcase
        // Mm = Sm << Mcnt; Me = Pe - Mcnt + 1
        assign Mm = (Sm << Mcnt);
        always_comb begin $display("Sm: %b, Mcnt: %b", Sm, Mcnt); end
        assign Me = (Pe>=Ze) ? (Pe - Mcnt + 1) : (Ze - Mcnt + 1);

        assign result = {1'b0, Me, Mm[20:11]};
        assign flags = 4'b0000; // no flags set
endmodule

// fma_2 performs fma on three signed half-precision floats
module fma_2(input logic [15:0] x, y, z,
        input logic mul, add, negp, negz,
        input logic [1:0] roundmode,
        output logic [15:0] result,
        output logic [3:0] flags);
        logic [10:0] Xm, Ym;
        logic [21:0] Zm, Am, Pm;
        logic [21:0] Sm;
        logic [21:0] Mm;
        logic [4:0] Xe, Ye, Ze, Pe, Acnt, Mcnt, Me;
        logic sub, sign;

        assign Xm = {1'b1, x[9:0]};
        assign Ym = {1'b1, y[9:0]};
        assign Zm = {2'b01, z[9:0], 10'b0};
        assign Xe = x[14:10];
        assign Ye = y[14:10];
        assign Ze = z[14:10];
        assign sub = (x[15] ^ y[15]) ^ z[15];

        // 1. Multiply the significands of X and Y: Pm = Xm × Ym
        assign Pm = Xm * Ym;
        // always_comb begin $display("Pm: %b, Zm: %b", Pm, Zm); end
        // 2. Add the exponents of X and Y: Pe = Xe + Ye – bias
        assign Pe = Xe + Ye - 15;
        // always_comb begin $display("sub: %b ", sub,"Pm: %b, Zm: %b", Pm, Zm, " Pe: %b, Ze: %b", Pe, Ze); end
        // 3. Determine the alignment shift count: Acnt = (Pe – Ze)
        // assign Acnt = (Pe - Ze)
        assign Acnt = (Pe>=Ze) ? (Pe - Ze) : (Ze - Pe);
        // 4. Shift the significand of Z into alignment: Am = Zm ≫ Acnt
        // assign Am = Zm >> Acnt;
        // 5. Add the aligned significands: Sm = Pm + Am
        // assign Sm = Pm + Am;
        //assign Sm = (Pe>=Ze) ? Pm + (Zm >> Acnt) : Zm + (Pm >> Acnt);
        always_comb begin
                if (sub) // need to subtract smaller from larger
                        if (Pe>Ze) begin
                                Sm = Pm - (Zm >> Acnt);
                                sign = (x[15] ^ y[15]); end
                        else if (Pe<Ze) begin
                                Sm = Zm - (Pm >> Acnt);
                                sign = z[15]; end
                        else
                                if (Pm>Zm) begin
                                        Sm = Pm - Zm;
                                        sign = (x[15] ^ y[15]); end
                                else if (Pm<Zm) begin
                                        Sm = Zm - Pm;
                                        sign = z[15]; end
                                else begin
                                        Sm = 0;
                                        sign = 0; end
                else begin
                        sign = z[15]; // sign will remain the same
                        if (Pe>Ze)      Sm = Pm + (Zm >> Acnt);
                        else if (Pe<Ze) Sm = Zm + (Pm >> Acnt);
                        else            Sm = Pm + Zm;
                        end
        // 6. Find the leading 1 for normalization shift: Mcnt = # of bits to shift
        // 7. Shift the result to renormalize: Mm = Sm ≪ Mcnt; Me = Pe – Mcnt
                casez (Sm[21:10])
                        12'b1???????????: Mcnt = 0;
                        12'b01??????????: Mcnt = 1;
                        12'b001?????????: Mcnt = 2;
                        12'b0001????????: Mcnt = 3;
                        12'b00001???????: Mcnt = 4;
                        12'b000001??????: Mcnt = 5;
                        12'b0000001?????: Mcnt = 6;
                        12'b00000001????: Mcnt = 7;
                        12'b000000001???: Mcnt = 8;
                        12'b0000000001??: Mcnt = 9;
                        12'b00000000001?: Mcnt = 10;
                        12'b000000000001: Mcnt = 11;
                        default: Mcnt = 0;
                endcase
        end
        // Mm = Sm << Mcnt; Me = Pe - Mcnt + 1
        assign Mm = (Sm << Mcnt);
        // always_comb begin $display("Sm: %b, Mcnt: %b", Sm, Mcnt); end
        assign Me = (Pe>=Ze) ? (Pe - Mcnt + 1) : (Ze - Mcnt + 1);

        assign result = {sign, Me, Mm[20:11]};
        assign flags = 4'b0000; // no flags set
endmodule

// fma_special_rz performs fma on three signed half-precision floats and handles special cases
module fma_special_rz(input logic [15:0] x, y, z,
        input logic mul, add, negp, negz,
        input logic [1:0] roundmode,
        output logic [15:0] result,
        output logic [3:0] flags);

        logic [15:0] Xm, Ym;
        logic [31:0] Zm, Pm, Tm, Am;
        logic [31:0] Sm;
        logic [31:0] Mm;
        logic [5:0] Xe, Ye, Ze, Pe, Acnt, Mcnt, Me, Tcnt;
        logic sub, puf, pof, sign;
        logic xzero, yzero, zzero, xinf, yinf, zinf, nan, sn; // special cases
        logic nv, of, uf, nx; // flags
        
        // check for special cases in inputs
        assign xzero = (x[14:0]==0); // check if any inputs are zero
        assign yzero = (y[14:0]==0);
        assign zzero = (z[14:0]==0);
        assign xinf = (x[14:0]==15'h7c00); // check if any inputs are infinity
        assign yinf = (y[14:0]==15'h7c00);
        assign zinf = (z[14:0]==15'h7c00);
        assign nan = (x[14:10]==5'h1f)&(x[9:0]!=0)|(y[14:10]==5'h1f)&(y[9:0]!=0)|(z[14:10]==5'h1f)&(z[9:0]!=0) // checks for any nan input
                        |(xzero&yinf&mul)|(yzero&xinf&mul)|((xinf|yinf)&zinf&((x[15]^y[15])^z[15])); // checks for invalid operations including inf*0 and inf-inf
        
        // assign mantissas and exponents
        assign Xm = xzero ? 16'b0 : {1'b1, x[9:0], 5'b0}; // assign mantissas
        assign Ym = (add&~mul)|yzero ? 16'b0 : {1'b1, y[9:0], 5'b0}; // also check if only multiply, in which y=1
        assign Zm = (zzero|(mul&~add)) ? 32'b0 : {2'b01, z[9:0], 20'b0}; // also check if only multiply, in which z=0
        assign Xe = {1'b0, x[14:10]}; // assign exponents
        assign Ye = (add&~mul) ? 6'b001111 : {1'b0, y[14:10]}; // again check if y=1
        assign Ze = (mul&~add) ? 6'b0 : {1'b0, z[14:10]}; // again check if z=0

        assign sub = (x[15] ^ y[15]) ^ z[15]; // if signs of x*y and z differ, subtraction will occur, else addition

        assign puf = (Xe + Ye) < 15; // precheck if P will have underflow
        assign Tcnt = puf ? (15 - (Xe + Ye) + 1) : 6'b0; // if P has underflow, determine shift amount to normalize Pm with Pe==0
        // 1. Multiply the significands of X and Y: Pm = Xm × Ym
        assign Tm = Xm * Ym; // temporary Pm
        always_comb begin // block for assigning Pm
                if (mul==0)             Pm = {1'b0, Xm, 15'b0}; // if no multiply, Pm = Xm
                else if (xzero|yzero)   Pm = 32'b0; // if either is 0, Pm = 0
                else if (Tm[31])        Pm = Tm >> (Tcnt+1); // if Tm has msb set, shift so that there is always a zero in msb of Pm
                else                    Pm = Tm >> Tcnt;
        end
        // 2. Add the exponents of X and Y: Pe = Xe + Ye – bias
        assign Pe = puf ? 6'b0 : ((Tm[31]) ? (Xe + Ye - 15 + 1) : (Xe + Ye - 15)); // need to check for carry bit in Pm, if set than increment Pe 

        // always_comb begin if(mul^add) $display("x: %h, y: %h, z: %h ",x,y,z,"Tcnt: %b ", Tcnt, "Pm: %b, Tm: %b, Zm: %b ", Pm,Tm,Zm,"mul: %b, add: %b",mul,add); end
        assign pof = (Pe>30&Pm!=0); // precheck if P will have overflow (only necessary if add==0)
        // always_comb begin if (x==16'h07ff&y==16'h07ff) $display("x: %h, y: %h, z: %h ",x,y,z,"sub: %b ", sub,"Pm: %b, Zm: %b", Pm, Zm, " Pe: %b, Ze: %b", Pe, Ze); end
        // 3. Determine the alignment shift count: Acnt = (Pe – Ze)
        // assign Acnt = (Pe - Ze)
        assign Acnt = (Pe>=Ze) ? (Pe - Ze) : (Ze - Pe);
        // 4. Shift the significand of Z into alignment: Am = Zm ≫ Acnt
        // assign Am = Zm >> Acnt;
        assign Am = (Pe>=Ze) ? (Zm >> Acnt) : (Pm >> Acnt);
        // 5. Add the aligned significands: Sm = Pm + Am
        // assign Sm = Pm + Am;
        always_comb begin
                if (add)
                        if (sub) // subtraction
                                if (puf) begin // if P has underflow
                                        Sm = Zm - Pm;
                                        sign = z[15];
                                end
                                else begin // otherwise compute regular subtraction
                                        if (Pe>Ze) begin // need to subtract smaller from larger
                                                Sm = Pm - Am;
                                                sign = (x[15] ^ y[15]); end
                                        else if (Pe<Ze) begin
                                                Sm = Zm - Am;
                                                sign = z[15]; end
                                        else            // same size exponent
                                                if (Pm>Zm) begin // check which mantissa is larger
                                                        Sm = Pm - Zm;
                                                        sign = (x[15] ^ y[15]); end
                                                else if (Pm<Zm) begin
                                                        Sm = Zm - Pm;
                                                        sign = z[15]; end
                                                else begin
                                                        Sm = 0;
                                                        sign = 0; end
                                end
                        else begin // addition
                                sign = z[15]; // sign will remain the same
                                if (Pe>=Ze)        Sm = Pm + Am;
                                else                    Sm = Zm + Am;
                                end
                else  begin 
                        Sm = Pm;
                        sign = x[15]^y[15]; 
                        end
        // 6. Find the leading 1 for normalization shift: Mcnt = # of bits to shift
        // 7. Shift the result to renormalize: Mm = Sm ≪ Mcnt; Me = Pe – Mcnt
                casez (Sm[31:9]) // check for leading one and determine how many shifts to put it in msb
                        23'b1??????????????????????: Mcnt = 0;
                        23'b01?????????????????????: Mcnt = 1;
                        23'b001????????????????????: Mcnt = 2;
                        23'b0001???????????????????: Mcnt = 3;
                        23'b00001??????????????????: Mcnt = 4;
                        23'b000001?????????????????: Mcnt = 5;
                        23'b0000001????????????????: Mcnt = 6;
                        23'b00000001???????????????: Mcnt = 7;
                        23'b000000001??????????????: Mcnt = 8;
                        23'b0000000001?????????????: Mcnt = 9;
                        23'b00000000001????????????: Mcnt = 10;
                        23'b000000000001???????????: Mcnt = 11;
                        23'b0000000000001??????????: Mcnt = 12;
                        23'b00000000000001?????????: Mcnt = 13;
                        23'b000000000000001????????: Mcnt = 14;
                        23'b0000000000000001???????: Mcnt = 15;
                        23'b00000000000000001??????: Mcnt = 16;
                        23'b000000000000000001?????: Mcnt = 17;
                        23'b0000000000000000001????: Mcnt = 18;
                        23'b00000000000000000001???: Mcnt = 19;
                        23'b000000000000000000001??: Mcnt = 20;
                        23'b0000000000000000000001?: Mcnt = 21;
                        23'b00000000000000000000001: Mcnt = 22;
                        default: Mcnt = 0;
                endcase
        end
        // always_comb begin $display("Sm: %b, Mcnt: %b", Sm, Mcnt); end
        always_comb if (Sm==0) begin // if mantissa is zero, after fma, assign zero output
                        Mm = 0;
                        Me = 0; end
                else begin
                        Mm = (Sm << Mcnt); // shift so that implicit one is in msb of Mm
                        Me = (puf&~add) ? 6'b0 : ((Pe>=Ze) ? (Pe - Mcnt + 1) : (Ze - Mcnt + 1)); end
        always_comb if(x==16'h87fe) $display("x: %h, y: %h, z: %h ",x,y,z, "Pm: %b, Sm: %b, Mcnt: %b, Me: %b ", Pm,Sm,Mcnt,Me,"mul: %b, add: %b",mul,add);

        // detect flags
        assign nv = nan;
        assign of = (~(nan|zinf)&((Me>=31)&(Mm!=0)))|(pof&~add) ? 1'b1 : 1'b0; // set overflow if number is greater than maxnum
        assign uf = puf&(~add); // Do not need to set underflow
        assign nx = puf|(Mm[20]|Mm[19]|Mm[18]|(|Mm[17:0])); // set inexact flag for product underflow or R|G|T|Overflow

        // assign result
        always_comb
                if (nan) result = {1'b0, 5'b11111, 10'b10000_00000};
                else if (xinf|yinf) result = {(x[15]^y[15]), 5'b11111, 10'b00000_00000};
                else if (zinf) result = z;
                else if (of) result = {sign, 5'b11110, 10'b11111_11111};
                else if (uf) result = {sign, 5'b00000, 10'b0};
                else result = {sign, Me[4:0], Mm[30:21]};
                // $display("Mcnt: %b, Sm: %b, Mm: %b", Mcnt, Sm, Mm[30:21]); end

        // assign flags
        assign flags = {nv, of, uf, nx}; // invalid, overflow, underflow, inexact
endmodule