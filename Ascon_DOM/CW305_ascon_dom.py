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

from chipwhisperer.logging import *

def prepare_data(data, l=16):
    data = data[:l]
    if len(data) < l:
        data += b'\x00' * (l - len(data))
    return data

def merge_data(data0, data1):
    data0 = prepare_data(data0)
    data1 = prepare_data(data1)
    data = data0[0:4] + data1[0:4] + data0[4:8] + data1[4:8] + data0[8:12] + data1[8:12] + data0[12:16] + data1[12:16]
    return data

def xor_data(data):
    data0 = data[ 0: 4] + data[ 8:12] + data[16:20] + data[24:28]
    data1 = data[ 4: 8] + data[12:16] + data[20:24] + data[28:32]
    return bytes(a ^ b for a, b in zip(data0, data1))

class CW305_ascon(CW305):

    """CW305 target object for ASCON targets.

    This class contains the public API for the CW305 hardware.
    To connect to the CW305, the easiest method is:

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
        self.default_verilog_defines = 'cw305_ascon_defines_DOM.v'
        self.default_verilog_defines_full_path = self.default_verilog_defines
        self.registers = 55 # number of registers we expect to find
        self.bytecount_size = 8 # pBYTECNT_SIZE in Verilog
        self.target_name = 'ascon'

    def set_rand(self, data=b''):
        """Initialize the random into the ascon core.
        """
        data = prepare_data(data, 320*12)
        self.fpga_write(self.REG_CRYPT_RIN0, list(data[ int(0*320/8): int(1*320/8)]))
        self.fpga_write(self.REG_CRYPT_RIN1, list(data[ int(1*320/8): int(2*320/8)]))
        self.fpga_write(self.REG_CRYPT_RIN2, list(data[ int(2*320/8): int(3*320/8)]))
        self.fpga_write(self.REG_CRYPT_RIN3, list(data[ int(3*320/8): int(4*320/8)]))
        self.fpga_write(self.REG_CRYPT_RIN4, list(data[ int(4*320/8): int(5*320/8)]))
        self.fpga_write(self.REG_CRYPT_RIN5, list(data[ int(5*320/8): int(6*320/8)]))
        self.fpga_write(self.REG_CRYPT_RIN6, list(data[ int(6*320/8): int(7*320/8)]))
        self.fpga_write(self.REG_CRYPT_RIN7, list(data[ int(7*320/8): int(8*320/8)]))
        self.fpga_write(self.REG_CRYPT_RIN8, list(data[ int(8*320/8): int(9*320/8)]))
        self.fpga_write(self.REG_CRYPT_RIN9, list(data[ int(9*320/8):int(10*320/8)]))
        self.fpga_write(self.REG_CRYPT_RINA, list(data[int(10*320/8):int(11*320/8)]))
        self.fpga_write(self.REG_CRYPT_RINB, list(data[int(11*320/8):int(12*320/8)]))
        
    def set_key(self, data0=b'', data1=b''):
        """Initialize the key into the ascon core.
        """
        data = merge_data(data0, data1)
        self.fpga_write(self.REG_CRYPT_DIN0, list(data[  0: len(data)]))
        # print("wrote data: " + bytes(self.fpga_read(self.REG_CRYPT_DIN0, l)).hex())
        
    def set_nonce(self, data0=b'', data1=b''):
        """Set the nonce.
        """
        data = merge_data(data0, data1)
        self.fpga_write(self.REG_CRYPT_DIN1, list(data[  0: len(data)]))
        # print("wrote data: " + bytes(self.fpga_read(self.REG_CRYPT_DIN1, l)).hex())
        
    def set_ad(self, data0=b'', data1=b''):
        """Set the Authenticated data.
        """
        data = merge_data(data0, data1)
        self.fpga_write(self.REG_CRYPT_DIN2, list(data[  0: len(data)]))
        # print("wrote data: " + bytes(self.fpga_read(self.REG_CRYPT_DIN2, l)).hex())
        
    def set_pt(self, data0=b'', data1=b''):
        """Set the plaintext.
        """
        data = merge_data(data0, data1)
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
        l = 32
        ct  = xor_data(bytes(self.fpga_read(self.REG_CRYPT_DOUT3, l)))
        mac = xor_data(bytes(self.fpga_read(self.REG_CRYPT_DOUT4, l)))
        return ct, mac

    def get_id(self):
        res = bytes(self.fpga_read(self.REG_IDENTIFY, 1))
        return res

    def run_operation(self, key=(b'',b''), nonce=(b'',b''), ad=(b'',b''), pt=(b'',b''), rnd=b'', acq=False):
        """Run an arbitrary operation.
        """
        self.run_init()
        # Data
        self.set_rand(rnd)
        self.set_key(key[0], key[1])
        self.set_nonce(nonce[0], nonce[1])
        self.set_ad(ad[0], ad[1])
        self.set_pt(pt[0], pt[1])
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


    def capture_trace(self, scope, key=(b'',b''), nonce=(b'',b''), ad=(b'',b''), pt=(b'',b''), rnd = b'', acq=True):
        """Run an operation and acquire it
        """
        self.run_init()
        # Data
        self.set_rand(rnd)
        self.set_key(key[0], key[1])
        self.set_nonce(nonce[0], nonce[1])
        self.set_ad(ad[0], ad[1])
        self.set_pt(pt[0], pt[1])
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
        data = key + nonce + ad + pt + tuple(ct) + tuple(mac) + tuple(rnd)

        return data, t


