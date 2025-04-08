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
        fadd_2 fadd_2(x, y, z, mul, add, negp, negz, roundmode, result, flags);
        

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
                                sign = z[15]; end
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
                casez (Sm[31:20])
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
                        default: Mcnt = 12;
                endcase
        end
        // Mm = Sm << Mcnt; Me = Pe - Mcnt + 1
        assign Mm = {(Sm << Mcnt)}[30:21]; // need to truncate and drop implicit 1
        assign Me = (Mcnt!=12) ? Pe - Mcnt + 1 : 0;

        assign result = {sign, Me, Mm};
        assign flags = 4'b0000; // no flags set
endmodule