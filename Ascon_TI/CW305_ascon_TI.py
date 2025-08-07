#=================================================
# Copyright (c) 2025, Security Pattern
# All rights reserved.
#
#    This file is part of: Analysis of ountermeasures used to protect the Ascon algorithm.
#
#    SPDX-License-Identifier: MIT 
#=================================================
import time
from chipwhisperer.capture.targets.CW305 import CW305
import numpy as np

from chipwhisperer.logging import *

def prepare_data(data, l=16):
    data = data[:l]
    if len(data) < l:
        data += b'\x00' * (l - len(data))
    # Reverse byte order
    data = data[::-1]
    # print(f'DATA: {data.hex()}')
    return data

class CW305_ascon(CW305):

    """CW305 target object for ASCON targets.

    This class contains the public API for the CW305 hardware.
    To connect to the CW305, the easiest method is::

        import chipwhisperer as cw
        scope = cw.scope()
        target = cw.target(scope, cw.targets.CW305_ascon, 
                           bsfile=<valid FPGA bitstream file>)

    Note that connecting to the CW305_ascon includes programming the CW305 FPGA.
    For more help about CW305 settings, try help() on this CW305 submodule:

       * target.pll
    """


    _name = "ChipWhisperer CW305 (Artix-7)"


    def __init__(self):
        import chipwhisperer as cw
        super().__init__()
        self._clksleeptime = 15 # need lots of idling time
        # Verilog defines file(s):
        self.default_verilog_defines = 'cw305_ascon_defines_TI.v'
        self.default_verilog_defines_full_path =  self.default_verilog_defines
        self.registers = 55 # number of registers we expect to find
        self.bytecount_size = 8 # pBYTECNT_SIZE in Verilog
        self.target_name = 'ascon'

    def set_rand(self, data=b''):
        """Initialize the random into the ascon core.
        """
        data = prepare_data(data, 16*16)
        self.fpga_write(self.REG_CRYPT_RIN0, list(data[ 0*16: 1*16]))
        self.fpga_write(self.REG_CRYPT_RIN1, list(data[ 1*16: 2*16]))
        self.fpga_write(self.REG_CRYPT_RIN2, list(data[ 2*16: 3*16]))
        self.fpga_write(self.REG_CRYPT_RIN3, list(data[ 3*16: 4*16]))
        self.fpga_write(self.REG_CRYPT_RIN4, list(data[ 4*16: 5*16]))
        self.fpga_write(self.REG_CRYPT_RIN5, list(data[ 5*16: 6*16]))
        self.fpga_write(self.REG_CRYPT_RIN6, list(data[ 6*16: 7*16]))
        self.fpga_write(self.REG_CRYPT_RIN7, list(data[ 7*16: 8*16]))
        self.fpga_write(self.REG_CRYPT_RIN8, list(data[ 8*16: 9*16]))
        self.fpga_write(self.REG_CRYPT_RIN9, list(data[ 9*16:10*16]))
        self.fpga_write(self.REG_CRYPT_RINA, list(data[10*16:11*16]))
        self.fpga_write(self.REG_CRYPT_RINB, list(data[11*16:12*16]))
        self.fpga_write(self.REG_CRYPT_RINC, list(data[12*16:13*16]))
        self.fpga_write(self.REG_CRYPT_RIND, list(data[13*16:14*16]))
        self.fpga_write(self.REG_CRYPT_RINE, list(data[14*16:15*16]))
        self.fpga_write(self.REG_CRYPT_RINF, list(data[15*16:16*16]))
        
    def set_key(self, data=b''):
        """Initialize the key into the ascon core.
        """
        data = prepare_data(data, 16)
        self.fpga_write(self.REG_CRYPT_DIN0, list(data[  0: len(data)]))
        # print("wrote data: " + bytes(self.fpga_read(self.REG_CRYPT_DIN0, l)).hex())
        
    def set_nonce(self, data=b''):
        """Set the nonce.
        """
        data = prepare_data(data, 16)
        self.fpga_write(self.REG_CRYPT_DIN1, list(data[  0: len(data)]))
        # print("wrote data: " + bytes(self.fpga_read(self.REG_CRYPT_DIN1, l)).hex())
        
    def set_ad(self, data=b''):
        """Set the Authenticated data.
        """
        data = prepare_data(data, 16)
        self.fpga_write(self.REG_CRYPT_DIN2, list(data[  0: len(data)]))
        # print("wrote data: " + bytes(self.fpga_read(self.REG_CRYPT_DIN2, l)).hex())
        
    def set_pt(self, data=b''):
        """Set the plaintext.
        """
        data = prepare_data(data, 16)
        self.fpga_write(self.REG_CRYPT_DIN3, list(data[  0: len(data)]))
        # print("wrote data: " + bytes(self.fpga_read(self.REG_CRYPT_DIN3, l)).hex())

    def run_init(self):
        """Initialize the core.
        """
        self.fpga_write(self.REG_CRYPT_GO_INIT, [1])
        time.sleep(0.01)

    def go(self, acq=False):

        if acq is True:
             """Disable USB clock (if requested), perform encryption, re-enable clock"""
             if (self.REG_USER_LED is None):
                target_logger.error("target.REG_USER_LED unset. Have you given target a verilog defines file?")
                return

             if self.platform == 'cw305' and self.clkusbautooff:
                self.usb_clk_setenabled(False)

             if self.toggle_user_led:
                self.fpga_write(self.REG_USER_LED, [0x01])
                time.sleep(0.001)

             if self.platform == 'cw305':
                self.usb_trigger_toggle()
             else:
                # this could also be done on the cw305 but it won't take if the USB clock was turned off:
                self.fpga_write(self.REG_CRYPT_GO_START, [1])

             if self.platform == 'cw305' and self.clkusbautooff:
                time.sleep(self.clksleeptime/1000.0)
                self.usb_clk_setenabled(True)

        else:
            self.fpga_write(self.REG_CRYPT_GO_START, [1])

    def is_done(self):
        """Check if FPGA is done"""
        result = self.fpga_read(self.REG_CRYPT_GO_START, 1)[0]
        if result == 0x01:
            return False
        else:
            self.fpga_write(self.REG_USER_LED, [0])
            return True

    def get_result(self):
        l = 16
        ct  = prepare_data(self.fpga_read(self.REG_CRYPT_DOUT0, l), l)
        mac = prepare_data(self.fpga_read(self.REG_CRYPT_DOUT1, l), l)
        return bytearray(ct), bytearray(mac)

    def get_id(self):
        res = bytes(self.fpga_read(self.REG_IDENTIFY, 1))
        return res

    def run_operation(self, key=b'', nonce=b'', ad=b'', pt=b'', rnd=b'', acq=False):
        """Run an arbitrary operation.
        """
        self.run_init()
        # Data
        self.set_rand(rnd)
        self.set_key(key)
        self.set_nonce(nonce)
        self.set_ad(ad)
        self.set_pt(pt)
        self.go(acq)
        time.sleep(0.01)
        if not self.is_done():
            target_logger.warning ("Target not done yet, increase clksleeptime!")
            #let's wait a bit more, see what happens:
            i = 0
            while not self.is_done():
                i += 1
                time.sleep(0.05)
                if i > 100:
                    target_logger.warning("Target still did not finish operation!")
                    break
        res = self.get_result()
        return res


    def capture_trace(self, scope, key=b'', nonce=b'', ad=b'', pt=b'', rnd=b'', acq=True):
        """Run an operation and acquire it
        """
        self.run_init()
        # Data
        self.set_rand(rnd)
        self.set_key(key)
        self.set_nonce(nonce)
        self.set_ad(ad)
        self.set_pt(pt)
        time.sleep(0.1)

        scope.arm()
        time.sleep(0.3)

        self.go(acq)

        time.sleep(0.03)
        if acq == True:
            scope.capture()
            t = scope.get_last_trace()
        else:
            t = []

        ct, mac = self.get_result()
        data = key + nonce + ad + pt + ct + mac

        return data, t


