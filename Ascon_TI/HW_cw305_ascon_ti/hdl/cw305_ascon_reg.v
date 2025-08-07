/* 
ChipWhisperer Artix Target - Example of connections between example registers
and rest of system.

Copyright (c) 2020, NewAE Technology Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted without restriction. Note that modules within
the project may have additional restrictions, please carefully inspect
additional licenses.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of NewAE Technology Inc.
*/

/* 
Modified by Security Pattern 2025 
*/

`default_nettype none
`timescale 1ns / 1ps
`include "cw305_ascon_defines.v"

module cw305_reg_ascon #(
   parameter pADDR_WIDTH = 21,
   parameter pBYTECNT_SIZE = 8,
   parameter pDONE_EDGE_SENSITIVE = 1,
   parameter pDATA_WIDTH = 128,
   parameter pKEY_WIDTH = 128,
   parameter pCORE_WIDTH = 64,
   parameter pCRYPT_TYPE = 5,
   parameter pCRYPT_REV = 1,
   parameter pIDENTIFY = 8'hc0
)(

// Interface to cw305_usb_reg_fe:
   input  wire                                  usb_clk,
   input  wire                                  crypto_clk,
   input  wire                                  reset_i,
   input  wire [pADDR_WIDTH-pBYTECNT_SIZE-1:0]  reg_address,     // Address of register
   input  wire [pBYTECNT_SIZE-1:0]              reg_bytecnt,     // Current byte count
   output reg  [7:0]                            read_data,       //
   input  wire [7:0]                            write_data,      //
   input  wire                                  reg_read,        // Read flag. One clock cycle AFTER this flag is high
                                                                 // valid data must be present on the read_data bus
   input  wire                                  reg_write,       // Write flag. When high on rising edge valid data is
                                                                 // present on write_data
   input  wire                                  reg_addrvalid,   // Address valid flag

// from top:
   input  wire                                  exttrigger_in,

// register inputs:
   input  wire                                  I_out_word,
   input  wire                                  I_tagout_word,
   input  wire                                  I_ready,  /* Crypto core ready. Tie to '1' if not used. */
   input  wire                                  I_done,   /* Crypto done. Can be high for one crypto_clk cycle or longer. */
   input  wire                                  I_busy,   /* Crypto busy. */
   input  wire [11:0]                           w_addr,
   input  wire                                  w_en,

// register outputs:
   output reg  [4:0]                            O_clksettings,
   output reg                                   O_user_led,
   output reg [pCORE_WIDTH-1:0]                 O_kin_word,
   output reg [pCORE_WIDTH-1:0]                 O_nin_word,
   output reg [pCORE_WIDTH-1:0]                 O_adin_word,
   output reg [pCORE_WIDTH-1:0]                 O_ptin_word,
   output wire                                  O_start
);

   reg  [7:0]                   reg_read_data;
   reg                          reg_crypt_go_pulse;
   wire                         reg_crypt_go_pulse_crypt;
   reg                          busy_usb;
   reg                          done_r;
   wire                         done_pulse;
   wire                         crypt_go_pulse;
   reg                          go_r;
   reg                          go;
   wire [31:0]                  buildtime;

   reg  [pDATA_WIDTH-1:0]      reg_din0;
   reg  [pDATA_WIDTH-1:0]      reg_din1;
   reg  [pDATA_WIDTH-1:0]      reg_din2;
   reg  [pDATA_WIDTH-1:0]      reg_din3;
   reg  [pDATA_WIDTH-1:0]      reg_rin0;
   reg  [pDATA_WIDTH-1:0]      reg_rin1;
   reg  [pDATA_WIDTH-1:0]      reg_rin2;
   reg  [pDATA_WIDTH-1:0]      reg_rin3;
   reg  [pDATA_WIDTH-1:0]      reg_rin4;
   reg  [pDATA_WIDTH-1:0]      reg_rin5;
   reg  [pDATA_WIDTH-1:0]      reg_rin6;
   reg  [pDATA_WIDTH-1:0]      reg_rin7;
   reg  [pDATA_WIDTH-1:0]      reg_rin8;
   reg  [pDATA_WIDTH-1:0]      reg_rin9;
   reg  [pDATA_WIDTH-1:0]      reg_rinA;
   reg  [pDATA_WIDTH-1:0]      reg_rinB;
   reg  [pDATA_WIDTH-1:0]      reg_rinC;
   reg  [pDATA_WIDTH-1:0]      reg_rinD;
   reg  [pDATA_WIDTH-1:0]      reg_rinE;
   reg  [pDATA_WIDTH-1:0]      reg_rinF;
   reg  [pDATA_WIDTH-1:0]      reg_dout0;
   reg  [pDATA_WIDTH-1:0]      reg_dout1;

   (* ASYNC_REG = "TRUE" *) reg  [pDATA_WIDTH-1:0] reg_kin_crypt;
   (* ASYNC_REG = "TRUE" *) reg  [pDATA_WIDTH-1:0] reg_nin_crypt;
   (* ASYNC_REG = "TRUE" *) reg  [pDATA_WIDTH-1:0] reg_adin_crypt;
   (* ASYNC_REG = "TRUE" *) reg  [pDATA_WIDTH-1:0] reg_ptin_crypt;
   (* ASYNC_REG = "TRUE" *) reg  [pDATA_WIDTH-1:0] reg_dout;
   (* ASYNC_REG = "TRUE" *) reg  [pDATA_WIDTH-1:0] reg_tagout;
   (* ASYNC_REG = "TRUE" *) reg  [4*pDATA_WIDTH-1:0] reg_r_kin_crypt;
   (* ASYNC_REG = "TRUE" *) reg  [4*pDATA_WIDTH-1:0] reg_r_nin_crypt;
   (* ASYNC_REG = "TRUE" *) reg  [4*pDATA_WIDTH-1:0] reg_r_adin_crypt;
   (* ASYNC_REG = "TRUE" *) reg  [4*pDATA_WIDTH-1:0] reg_r_ptin_crypt;

   (* ASYNC_REG = "TRUE" *) reg  [1:0] go_pipe;
   (* ASYNC_REG = "TRUE" *) reg  [1:0] busy_pipe;


   always @(posedge crypto_clk) begin
       done_r <= I_done & pDONE_EDGE_SENSITIVE;
   end
   assign done_pulse = I_done & ~done_r;

   always @(posedge crypto_clk) begin
       reg_kin_crypt  <= reg_din0;
       reg_nin_crypt  <= reg_din1;
       reg_adin_crypt <= reg_din2;
       reg_ptin_crypt <= reg_din3;
       reg_r_kin_crypt  <= {reg_rinC, reg_rin8, reg_rin4, reg_rin0};
       reg_r_nin_crypt  <= {reg_rinD, reg_rin9, reg_rin5, reg_rin1};
       reg_r_adin_crypt <= {reg_rinE, reg_rinA, reg_rin6, reg_rin2};
       reg_r_ptin_crypt <= {reg_rinF, reg_rinB, reg_rin7, reg_rin3};
       O_kin_word  <= { reg_r_kin_crypt[(128*4-1)-(4*w_addr) +: 4],  reg_kin_crypt[127-w_addr +: 1]};
       O_nin_word  <= { reg_r_nin_crypt[(128*4-1)-(4*w_addr) +: 4],  reg_nin_crypt[127-w_addr +: 1]};
       O_adin_word <= {reg_r_adin_crypt[(128*4-1)-(4*w_addr) +: 4], reg_adin_crypt[127-w_addr +: 1]};
       O_ptin_word <= {reg_r_ptin_crypt[(128*4-1)-(4*w_addr) +: 4], reg_ptin_crypt[127-w_addr +: 1]};
       if (w_en) begin
          reg_dout[127-w_addr +: 1] <= I_out_word;
          reg_tagout[127-w_addr +: 1] <= I_tagout_word;
       end
   end

   always @(posedge usb_clk) begin
       reg_dout0 <= reg_dout[ pDATA_WIDTH-1 :  0];
       reg_dout1 <= reg_tagout[ pDATA_WIDTH-1 :  0];
   end

   assign O_start = crypt_go_pulse || reg_crypt_go_pulse_crypt;

   //////////////////////////////////
   // read logic:
   //////////////////////////////////

   always @(*) begin
      if (reg_addrvalid && reg_read) begin
         case (reg_address)
            `REG_CLKSETTINGS:    reg_read_data = O_clksettings;
            `REG_USER_LED:       reg_read_data = O_user_led;
            `REG_CRYPT_TYPE:     reg_read_data = pCRYPT_TYPE;
            `REG_CRYPT_REV:      reg_read_data = pCRYPT_REV;
            `REG_IDENTIFY:       reg_read_data = pIDENTIFY;
            `REG_CRYPT_GO_START: reg_read_data = busy_usb;
            `REG_CRYPT_DIN0:     reg_read_data = reg_din0[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DIN1:     reg_read_data = reg_din1[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DIN2:     reg_read_data = reg_din2[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DIN3:     reg_read_data = reg_din3[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RIN0:     reg_read_data = reg_rin0[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RIN1:     reg_read_data = reg_rin1[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RIN2:     reg_read_data = reg_rin2[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RIN3:     reg_read_data = reg_rin3[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RIN4:     reg_read_data = reg_rin4[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RIN5:     reg_read_data = reg_rin5[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RIN6:     reg_read_data = reg_rin6[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RIN7:     reg_read_data = reg_rin7[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RIN8:     reg_read_data = reg_rin8[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RIN9:     reg_read_data = reg_rin9[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RINA:     reg_read_data = reg_rinA[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RINB:     reg_read_data = reg_rinB[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RINC:     reg_read_data = reg_rinC[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RIND:     reg_read_data = reg_rinD[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RINE:     reg_read_data = reg_rinE[reg_bytecnt*8 +: 8];
            `REG_CRYPT_RINF:     reg_read_data = reg_rinF[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUT0:    reg_read_data = reg_dout0[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUT1:    reg_read_data = reg_dout1[reg_bytecnt*8 +: 8];
            default:             reg_read_data = 0;
         endcase
      end
      else
         reg_read_data = 0;
   end

   // Register output read data to ease timing. If you need read data one clock
   // cycle earlier, simply remove this stage:
   always @(posedge usb_clk)
      read_data <= reg_read_data;

   //////////////////////////////////
   // write logic (USB clock domain):
   //////////////////////////////////
   always @(posedge usb_clk) begin
      if (reset_i) begin
         O_clksettings <= 0;
         O_user_led <= 0;
         reg_crypt_go_pulse <= 1'b0;
      end

      else begin
         if (reg_addrvalid && reg_write) begin
            case (reg_address)
               `REG_CLKSETTINGS:    O_clksettings <= write_data;
               `REG_USER_LED:       O_user_led <= write_data;
               `REG_CRYPT_DIN0:     reg_din0[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DIN1:     reg_din1[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DIN2:     reg_din2[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DIN3:     reg_din3[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RIN0:     reg_rin0[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RIN1:     reg_rin1[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RIN2:     reg_rin2[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RIN3:     reg_rin3[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RIN4:     reg_rin4[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RIN5:     reg_rin5[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RIN6:     reg_rin6[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RIN7:     reg_rin7[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RIN8:     reg_rin8[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RIN9:     reg_rin9[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RINA:     reg_rinA[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RINB:     reg_rinB[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RINC:     reg_rinC[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RIND:     reg_rinD[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RINE:     reg_rinE[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_RINF:     reg_rinF[reg_bytecnt*8 +: 8] <= write_data;
            endcase
         end
         // REG_CRYPT_GO_START register is special: writing it creates a pulse. Reading it gives you the "busy" status.
         if ( (reg_addrvalid && reg_write && (reg_address == `REG_CRYPT_GO_START)) )
            reg_crypt_go_pulse <= 1'b1;
         else
            reg_crypt_go_pulse <= 1'b0;
      end
   end

   always @(posedge crypto_clk) begin
      {go_r, go, go_pipe} <= {go, go_pipe, exttrigger_in};
   end
   assign crypt_go_pulse = go & !go_r & !O_user_led;

   cdc_pulse U_go_pulse (
      .reset_i       (reset_i),
      .src_clk       (usb_clk),
      .src_pulse     (reg_crypt_go_pulse),
      .dst_clk       (crypto_clk),
      .dst_pulse     (reg_crypt_go_pulse_crypt)
   );

   always @(posedge usb_clk)
      {busy_usb, busy_pipe} <= {busy_pipe, I_busy};


   assign buildtime = 0;


endmodule

`default_nettype wire
