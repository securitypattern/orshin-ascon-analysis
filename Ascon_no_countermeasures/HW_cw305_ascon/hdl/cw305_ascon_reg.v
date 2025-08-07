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
   parameter pCRYPT_TYPE = 5,
   parameter pCRYPT_REV = 1,
   parameter pIDENTIFY = 8'had
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
   input  wire [31:0]                           I_out_word,
   input  wire                                  I_ready,  /* Crypto core ready. Tie to '1' if not used. */
   input  wire                                  I_done,   /* Crypto done. Can be high for one crypto_clk cycle or longer. */
   input  wire                                  I_busy,   /* Crypto busy. */
   input  wire [7:0]                            w_addr,
   input  wire                                  w_en,

// register outputs:
   output reg  [4:0]                            O_clksettings,
   output reg                                   O_user_led,
   output reg [31:0]                            O_sin_word,
   output reg [31:0]                            O_pin_word,
   output wire                                  O_init,
   output wire                                  O_start
);

   reg  [7:0]                   reg_read_data;
   reg                          reg_crypt_go_pulse;
   wire                         reg_crypt_go_pulse_crypt;
   reg                          reg_crypt_go_init_pulse;
   wire                         reg_crypt_go_init_pulse_crypt;
   reg                          busy_usb;
   reg                          done_r;
   wire                         done_pulse;
   wire                         crypt_go_pulse;
   wire                         crypt_go_init_pulse;
   reg                          go_r;
   reg                          go;
   wire [31:0]                  buildtime;

   // reg  [pDATA_WIDTH-1:0] reg_dout;
   // reg  [pDATA_WIDTH-1:0] reg_din;
   reg  [pDATA_WIDTH-1:0]      reg_din0;
   reg  [pDATA_WIDTH-1:0]      reg_din1;
   reg  [pDATA_WIDTH-1:0]      reg_din2;
   reg  [pDATA_WIDTH-1:0]      reg_din3;
   reg  [pDATA_WIDTH-1:0]      reg_din4;
   reg  [pDATA_WIDTH-1:0]      reg_din5;
   reg  [pDATA_WIDTH-1:0]      reg_din6;
   reg  [pDATA_WIDTH-1:0]      reg_din7;
   reg  [pDATA_WIDTH-1:0]      reg_din8;
   reg  [pDATA_WIDTH-1:0]      reg_din9;
   reg  [pDATA_WIDTH-1:0]      reg_dinA;
   reg  [pDATA_WIDTH-1:0]      reg_dinB;
   reg  [pDATA_WIDTH-1:0]      reg_dinC;
   reg  [pDATA_WIDTH-1:0]      reg_dinD;
   reg  [pDATA_WIDTH-1:0]      reg_dinE;
   reg  [pDATA_WIDTH-1:0]      reg_dinF;
   reg  [pDATA_WIDTH-1:0]      reg_dout0;
   reg  [pDATA_WIDTH-1:0]      reg_dout1;
   reg  [pDATA_WIDTH-1:0]      reg_dout2;
   reg  [pDATA_WIDTH-1:0]      reg_dout3;
   reg  [pDATA_WIDTH-1:0]      reg_dout4;
   reg  [pDATA_WIDTH-1:0]      reg_dout5;
   reg  [pDATA_WIDTH-1:0]      reg_dout6;
   reg  [pDATA_WIDTH-1:0]      reg_dout7;
   reg  [pDATA_WIDTH-1:0]      reg_dout8;
   reg  [pDATA_WIDTH-1:0]      reg_dout9;
   reg  [pDATA_WIDTH-1:0]      reg_doutA;
   reg  [pDATA_WIDTH-1:0]      reg_doutB;
   reg  [pDATA_WIDTH-1:0]      reg_doutC;
   reg  [pDATA_WIDTH-1:0]      reg_doutD;
   reg  [pDATA_WIDTH-1:0]      reg_doutE;
   reg  [pDATA_WIDTH-1:0]      reg_doutF;

   (* ASYNC_REG = "TRUE" *) reg  [pDATA_WIDTH*16-1:0] reg_din_crypt;
   (* ASYNC_REG = "TRUE" *) reg  [pDATA_WIDTH*16-1:0] reg_dout;

   (* ASYNC_REG = "TRUE" *) reg  [1:0] go_pipe;
   (* ASYNC_REG = "TRUE" *) reg  [1:0] busy_pipe;


   always @(posedge crypto_clk) begin
       done_r <= I_done & pDONE_EDGE_SENSITIVE;
   end
   assign done_pulse = I_done & ~done_r;

   always @(posedge crypto_clk) begin
       reg_din_crypt <= {reg_dinF, reg_dinE, reg_dinD, reg_dinC, reg_dinB, reg_dinA, reg_din9, reg_din8, reg_din7, reg_din6, reg_din5, reg_din4, reg_din3, reg_din2, reg_din1, reg_din0};
       O_sin_word <= reg_din_crypt[w_addr*32 +: 32];
       O_pin_word <= reg_din_crypt[w_addr*32 +: 32];
       if (w_en)
          reg_dout[w_addr*32 +: 32] <= I_out_word;
   end

   always @(posedge usb_clk) begin
       reg_dout0 <= reg_dout[ 1*pDATA_WIDTH-1 :  0*pDATA_WIDTH];
       reg_dout1 <= reg_dout[ 2*pDATA_WIDTH-1 :  1*pDATA_WIDTH];
       reg_dout2 <= reg_dout[ 3*pDATA_WIDTH-1 :  2*pDATA_WIDTH];
       reg_dout3 <= reg_dout[ 4*pDATA_WIDTH-1 :  3*pDATA_WIDTH];
       reg_dout4 <= reg_dout[ 5*pDATA_WIDTH-1 :  4*pDATA_WIDTH];
       reg_dout5 <= reg_dout[ 6*pDATA_WIDTH-1 :  5*pDATA_WIDTH];
       reg_dout6 <= reg_dout[ 7*pDATA_WIDTH-1 :  6*pDATA_WIDTH];
       reg_dout7 <= reg_dout[ 8*pDATA_WIDTH-1 :  7*pDATA_WIDTH];
       reg_dout8 <= reg_dout[ 9*pDATA_WIDTH-1 :  8*pDATA_WIDTH];
       reg_dout9 <= reg_dout[10*pDATA_WIDTH-1 :  9*pDATA_WIDTH];
       reg_doutA <= reg_dout[11*pDATA_WIDTH-1 : 10*pDATA_WIDTH];
       reg_doutB <= reg_dout[12*pDATA_WIDTH-1 : 11*pDATA_WIDTH];
       reg_doutC <= reg_dout[13*pDATA_WIDTH-1 : 12*pDATA_WIDTH];
       reg_doutD <= reg_dout[14*pDATA_WIDTH-1 : 13*pDATA_WIDTH];
       reg_doutE <= reg_dout[15*pDATA_WIDTH-1 : 14*pDATA_WIDTH];
       reg_doutF <= reg_dout[16*pDATA_WIDTH-1 : 15*pDATA_WIDTH];
   end

   assign O_start = crypt_go_pulse || reg_crypt_go_pulse_crypt;
   assign O_init = reg_crypt_go_init_pulse_crypt;
   // assign O_sin_word = reg_din_crypt[w_addr*32 +: 32];
   // assign O_pin_word = reg_din_crypt[w_addr*32 +: 32];

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
            `REG_CRYPT_DIN4:     reg_read_data = reg_din4[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DIN5:     reg_read_data = reg_din5[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DIN6:     reg_read_data = reg_din6[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DIN7:     reg_read_data = reg_din7[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DIN8:     reg_read_data = reg_din8[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DIN9:     reg_read_data = reg_din9[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DINA:     reg_read_data = reg_dinA[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DINB:     reg_read_data = reg_dinB[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DINC:     reg_read_data = reg_dinC[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DIND:     reg_read_data = reg_dinD[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DINE:     reg_read_data = reg_dinE[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DINF:     reg_read_data = reg_dinF[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUT0:    reg_read_data = reg_dout0[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUT1:    reg_read_data = reg_dout1[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUT2:    reg_read_data = reg_dout2[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUT3:    reg_read_data = reg_dout3[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUT4:    reg_read_data = reg_dout4[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUT5:    reg_read_data = reg_dout5[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUT6:    reg_read_data = reg_dout6[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUT7:    reg_read_data = reg_dout7[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUT8:    reg_read_data = reg_dout8[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUT9:    reg_read_data = reg_dout9[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUTA:    reg_read_data = reg_doutA[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUTB:    reg_read_data = reg_doutB[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUTC:    reg_read_data = reg_doutC[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUTD:    reg_read_data = reg_doutD[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUTE:    reg_read_data = reg_doutE[reg_bytecnt*8 +: 8];
            `REG_CRYPT_DOUTF:    reg_read_data = reg_doutF[reg_bytecnt*8 +: 8];
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
         reg_crypt_go_init_pulse <= 1'b0;
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
               `REG_CRYPT_DIN4:     reg_din4[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DIN5:     reg_din5[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DIN6:     reg_din6[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DIN7:     reg_din7[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DIN8:     reg_din8[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DIN9:     reg_din9[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DINA:     reg_dinA[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DINB:     reg_dinB[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DINC:     reg_dinC[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DIND:     reg_dinD[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DINE:     reg_dinE[reg_bytecnt*8 +: 8] <= write_data;
               `REG_CRYPT_DINF:     reg_dinF[reg_bytecnt*8 +: 8] <= write_data;
            endcase
         end
         // REG_CRYPT_GO_START register is special: writing it creates a pulse. Reading it gives you the "busy" status.
         if ( (reg_addrvalid && reg_write && (reg_address == `REG_CRYPT_GO_START)) )
            reg_crypt_go_pulse <= 1'b1;
         else
            reg_crypt_go_pulse <= 1'b0;
         if ( (reg_addrvalid && reg_write && (reg_address == `REG_CRYPT_GO_INIT)) )
            reg_crypt_go_init_pulse <= 1'b1;
         else
            reg_crypt_go_init_pulse <= 1'b0;
      end
   end

   always @(posedge crypto_clk) begin
      {go_r, go, go_pipe} <= {go, go_pipe, exttrigger_in};
   end
   assign crypt_go_pulse = go & !go_r & !O_user_led;
   assign crypt_go_init_pulse = go & !go_r & O_user_led;

   cdc_pulse U_go_pulse (
      .reset_i       (reset_i),
      .src_clk       (usb_clk),
      .src_pulse     (reg_crypt_go_pulse),
      .dst_clk       (crypto_clk),
      .dst_pulse     (reg_crypt_go_pulse_crypt)
   );
   cdc_pulse U_go_init_pulse (
      .reset_i       (reset_i),
      .src_clk       (usb_clk),
      .src_pulse     (reg_crypt_go_init_pulse),
      .dst_clk       (crypto_clk),
      .dst_pulse     (reg_crypt_go_init_pulse_crypt)
   );

   always @(posedge usb_clk)
      {busy_usb, busy_pipe} <= {busy_pipe, I_busy};


   assign buildtime = 0;


endmodule

`default_nettype wire
