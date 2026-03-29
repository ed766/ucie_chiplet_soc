package rv32_tb_pkg;
  localparam int RV32_DATA_MEM_WORDS = 64;
  localparam int RV32_MAX_PROGRAM_LEN = 256;

  typedef enum logic [3:0] {
    RV32_OP_UNKNOWN,
    RV32_OP_ADD,
    RV32_OP_SUB,
    RV32_OP_ADDI,
    RV32_OP_BEQ,
    RV32_OP_LW,
    RV32_OP_SW,
    RV32_OP_EBREAK
  } rv32_op_e;

  typedef struct packed {
    logic [31:0] instr;
    logic [31:0] pc;
    logic [31:0] next_pc;
    logic        wb_valid;
    logic [4:0]  wb_rd;
    logic [31:0] wb_data;
    logic        mem_valid;
    logic        mem_write;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
    logic        branch_taken;
    logic        illegal_instr;
    logic        halted;
  } rv32_trace_txn_t;

  function automatic logic [4:0] rv32_rs1(input logic [31:0] instr_word);
    rv32_rs1 = instr_word[19:15];
  endfunction

  function automatic logic [4:0] rv32_rs2(input logic [31:0] instr_word);
    rv32_rs2 = instr_word[24:20];
  endfunction

  function automatic logic [4:0] rv32_rd(input logic [31:0] instr_word);
    rv32_rd = instr_word[11:7];
  endfunction

  function automatic logic signed [31:0] rv32_imm_i(input logic [31:0] instr_word);
    rv32_imm_i = $signed({{20{instr_word[31]}}, instr_word[31:20]});
  endfunction

  function automatic logic signed [31:0] rv32_imm_s(input logic [31:0] instr_word);
    rv32_imm_s = $signed({{20{instr_word[31]}}, instr_word[31:25], instr_word[11:7]});
  endfunction

  function automatic logic signed [31:0] rv32_imm_b(input logic [31:0] instr_word);
    rv32_imm_b = $signed({{19{instr_word[31]}}, instr_word[31], instr_word[7],
                          instr_word[30:25], instr_word[11:8], 1'b0});
  endfunction

  function automatic rv32_op_e rv32_decode_op(input logic [31:0] instr_word);
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    begin
      opcode = instr_word[6:0];
      funct3 = instr_word[14:12];
      funct7 = instr_word[31:25];
      rv32_decode_op = RV32_OP_UNKNOWN;
      case (opcode)
        7'b0110011: begin
          if ((funct3 == 3'b000) && (funct7 == 7'b0000000)) begin
            rv32_decode_op = RV32_OP_ADD;
          end else if ((funct3 == 3'b000) && (funct7 == 7'b0100000)) begin
            rv32_decode_op = RV32_OP_SUB;
          end
        end
        7'b0010011: begin
          if (funct3 == 3'b000) begin
            rv32_decode_op = RV32_OP_ADDI;
          end
        end
        7'b1100011: begin
          if (funct3 == 3'b000) begin
            rv32_decode_op = RV32_OP_BEQ;
          end
        end
        7'b0000011: begin
          if (funct3 == 3'b010) begin
            rv32_decode_op = RV32_OP_LW;
          end
        end
        7'b0100011: begin
          if (funct3 == 3'b010) begin
            rv32_decode_op = RV32_OP_SW;
          end
        end
        7'b1110011: begin
          if (instr_word == 32'h0010_0073) begin
            rv32_decode_op = RV32_OP_EBREAK;
          end
        end
        default: begin
          rv32_decode_op = RV32_OP_UNKNOWN;
        end
      endcase
    end
  endfunction

  function automatic logic rv32_is_halt(input logic [31:0] instr_word);
    rv32_is_halt = (rv32_decode_op(instr_word) == RV32_OP_EBREAK);
  endfunction

  function automatic int unsigned rv32_lcg_advance(input int unsigned state);
    rv32_lcg_advance = (state * 32'd1664525) + 32'd1013904223;
  endfunction

  function automatic logic [31:0] rv32_add(input logic [4:0] rd, input logic [4:0] rs1, input logic [4:0] rs2);
    rv32_add = {7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011};
  endfunction

  function automatic logic [31:0] rv32_sub(input logic [4:0] rd, input logic [4:0] rs1, input logic [4:0] rs2);
    rv32_sub = {7'b0100000, rs2, rs1, 3'b000, rd, 7'b0110011};
  endfunction

  function automatic logic [31:0] rv32_addi(input logic [4:0] rd, input logic [4:0] rs1, input logic signed [11:0] imm12);
    rv32_addi = {imm12[11:0], rs1, 3'b000, rd, 7'b0010011};
  endfunction

  function automatic logic [31:0] rv32_lw(input logic [4:0] rd, input logic [4:0] rs1, input logic signed [11:0] imm12);
    rv32_lw = {imm12[11:0], rs1, 3'b010, rd, 7'b0000011};
  endfunction

  function automatic logic [31:0] rv32_sw(input logic [4:0] rs1, input logic [4:0] rs2, input logic signed [11:0] imm12);
    rv32_sw = {imm12[11:5], rs2, rs1, 3'b010, imm12[4:0], 7'b0100011};
  endfunction

  function automatic logic [31:0] rv32_beq(input logic [4:0] rs1, input logic [4:0] rs2, input logic signed [12:0] imm13);
    rv32_beq = {imm13[12], imm13[10:5], rs2, rs1, 3'b000, imm13[4:1], imm13[11], 7'b1100011};
  endfunction

  function automatic logic [31:0] rv32_ebreak();
    rv32_ebreak = 32'h0010_0073;
  endfunction

  function automatic logic [31:0] rv32_nop();
    rv32_nop = 32'h0000_0013;
  endfunction

  function automatic string rv32_op_name(input rv32_op_e op);
    case (op)
      RV32_OP_ADD:    rv32_op_name = "ADD";
      RV32_OP_SUB:    rv32_op_name = "SUB";
      RV32_OP_ADDI:   rv32_op_name = "ADDI";
      RV32_OP_BEQ:    rv32_op_name = "BEQ";
      RV32_OP_LW:     rv32_op_name = "LW";
      RV32_OP_SW:     rv32_op_name = "SW";
      RV32_OP_EBREAK: rv32_op_name = "EBREAK";
      default:        rv32_op_name = "UNKNOWN";
    endcase
  endfunction
endpackage
