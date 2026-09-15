module rv32_muldiv (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        req_valid,
  output logic        req_ready,
  input  logic [2:0]  req_op,
  input  logic [31:0] req_lhs,
  input  logic [31:0] req_rhs,
  output logic        rsp_valid,
  input  logic        rsp_ready,
  output logic [31:0] rsp_result
);
  typedef enum logic [1:0] {IDLE, ITERATE, FINALIZE, RESPONSE} state_t;
  state_t state_q;

  logic [2:0]  op_q;
  logic [31:0] lhs_q, rhs_q;
  logic [31:0] multiplier_q;
  logic [63:0] multiplicand_q, product_q;
  logic [31:0] dividend_q, divisor_q, quotient_q;
  logic [32:0] remainder_q;
  logic [5:0]  iteration_q;
  logic        result_negative_q, remainder_negative_q;
  logic        divide_special_q;
  logic [31:0] divide_special_result_q;
  logic [31:0] result_q;

  wire is_division = op_q[2];
  assign req_ready = state_q == IDLE;
  assign rsp_valid = state_q == RESPONSE;
  assign rsp_result = result_q;

  function automatic logic [31:0] magnitude(input logic [31:0] value);
    magnitude = value[31] ? (~value + 1'b1) : value;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
`ifdef RV32_BUG_M_STALE_RESET
      state_q <= RESPONSE;
`else
      state_q <= IDLE;
`endif
      op_q <= '0;
      lhs_q <= '0;
      rhs_q <= '0;
      multiplier_q <= '0;
      multiplicand_q <= '0;
      product_q <= '0;
      dividend_q <= '0;
      divisor_q <= '0;
      quotient_q <= '0;
      remainder_q <= '0;
      iteration_q <= '0;
      result_negative_q <= 1'b0;
      remainder_negative_q <= 1'b0;
      divide_special_q <= 1'b0;
      divide_special_result_q <= '0;
      result_q <= '0;
    end else begin
      unique case (state_q)
        IDLE: if (req_valid) begin
          logic lhs_signed, rhs_signed;
          logic [31:0] lhs_mag, rhs_mag;
          lhs_signed = (req_op == 3'd1) || (req_op == 3'd2) ||
                       (req_op == 3'd4) || (req_op == 3'd6);
          rhs_signed = (req_op == 3'd1) || (req_op == 3'd4) || (req_op == 3'd6)
`ifdef RV32_BUG_MULHSU_SIGNEDNESS
                       || (req_op == 3'd2)
`endif
                       ;
          lhs_mag = (lhs_signed && req_lhs[31]) ? magnitude(req_lhs) : req_lhs;
          rhs_mag = (rhs_signed && req_rhs[31]) ? magnitude(req_rhs) : req_rhs;
          op_q <= req_op;
          lhs_q <= req_lhs;
          rhs_q <= req_rhs;
          multiplier_q <= rhs_mag;
          multiplicand_q <= {32'b0, lhs_mag};
          product_q <= '0;
          dividend_q <= lhs_mag;
          divisor_q <= rhs_mag;
          quotient_q <= '0;
          remainder_q <= '0;
          iteration_q <= '0;
          result_negative_q <= (lhs_signed && req_lhs[31]) ^ (rhs_signed && req_rhs[31]);
          remainder_negative_q <= lhs_signed && req_lhs[31];
          divide_special_q <= req_op[2] && ((req_rhs == 0) ||
              ((req_op == 3'd4 || req_op == 3'd6) &&
               req_lhs == 32'h8000_0000 && req_rhs == 32'hffff_ffff));
          if (req_rhs == 0)
            divide_special_result_q <= (req_op < 3'd6) ? 32'hffff_ffff : req_lhs;
          else
            divide_special_result_q <= (req_op < 3'd6) ? 32'h8000_0000 : 32'h0000_0000;
          state_q <= ITERATE;
        end

        ITERATE: begin
          if (is_division) begin
            logic [32:0] shifted_remainder;
            shifted_remainder = {remainder_q[31:0], dividend_q[31]};
            dividend_q <= {dividend_q[30:0], 1'b0};
            if (shifted_remainder >= {1'b0, divisor_q}) begin
              remainder_q <= shifted_remainder - {1'b0, divisor_q};
              quotient_q <= {quotient_q[30:0], 1'b1};
            end else begin
              remainder_q <= shifted_remainder;
              quotient_q <= {quotient_q[30:0], 1'b0};
            end
          end else begin
            if (multiplier_q[0]) product_q <= product_q + multiplicand_q;
            multiplier_q <= {1'b0, multiplier_q[31:1]};
            multiplicand_q <= multiplicand_q << 1;
          end
          if (iteration_q == 6'd31) state_q <= FINALIZE;
          else iteration_q <= iteration_q + 1'b1;
        end

        FINALIZE: begin
          logic [63:0] signed_product;
          logic [31:0] signed_quotient, signed_remainder;
          signed_product = result_negative_q ? (~product_q + 1'b1) : product_q;
          signed_quotient = result_negative_q ? (~quotient_q + 1'b1) : quotient_q;
          signed_remainder = remainder_negative_q ? (~remainder_q[31:0] + 1'b1) : remainder_q[31:0];
`ifdef RV32_BUG_M_DIV_ROUND
          if (result_negative_q) signed_quotient = signed_quotient - 1'b1;
`endif
`ifdef RV32_BUG_M_REM_SIGN
          signed_remainder = remainder_q[31:0];
`endif
          if (divide_special_q) begin
`ifdef RV32_BUG_M_DIV_ZERO
            result_q <= (rhs_q == 0) ? (divide_special_result_q ^ 1'b1) : divide_special_result_q;
`elsif RV32_BUG_M_DIV_OVERFLOW
            result_q <= (lhs_q == 32'h8000_0000 && rhs_q == 32'hffff_ffff) ?
                        (divide_special_result_q + 1'b1) : divide_special_result_q;
`else
            result_q <= divide_special_result_q;
`endif
          end
          else unique case (op_q)
            3'd0: result_q <= product_q[31:0];
`ifdef RV32_BUG_M_HIGH_PRODUCT
            3'd1, 3'd2: result_q <= signed_product[63:32] ^ 1'b1;
`else
            3'd1, 3'd2: result_q <= signed_product[63:32];
`endif
            3'd3: result_q <= product_q[63:32];
            3'd4, 3'd5: result_q <= signed_quotient;
            3'd6, 3'd7: result_q <= signed_remainder;
            default: result_q <= '0;
          endcase
          state_q <= RESPONSE;
        end

        RESPONSE: if (rsp_ready) state_q <= IDLE;
        default: state_q <= IDLE;
      endcase
    end
  end

`ifdef FORMAL
  always_ff @(posedge clk) if (rst_n) begin
    if ($past(rsp_valid && !rsp_ready)) begin
      a_result_stable: assert (rsp_valid && $stable(rsp_result));
    end
    if (req_valid && !req_ready) begin
      a_no_accept_when_busy: assert (state_q != IDLE);
    end
  end
`endif
endmodule
