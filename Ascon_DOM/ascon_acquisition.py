#=================================================
# Copyright (c) 2025, Security Pattern
# All rights reserved.
#
#    This file is part of: Analysis of ountermeasures used to protect the Ascon algorithm.
#    This file allows to connect to the Chipwhisperer Husky, upload a bitstream on the FPGA, 
#    test inputs/ouputs and acquire traces. 
#
#    SPDX-License-Identifier: MIT 
#=================================================

import chipwhisperer as cw
import os
import numpy as np
import time
from tqdm import tqdm
import datetime
from CW305_ascon_dom import CW305_ascon as cw1 # Import of the chipwhisperer class

#=================================================
# Definition of the acquisition function
# Input:
# - project_name: name of the folder in which are saved the traces and data files
# - NS: number of traces for each file (10 by default)
# - ttest: activation of the t-test mode.
#          If True, an half of the acquired traces are with fixed input and an half with random inputs
#          If False, all the acquired traces are with random inputs (default value)
#=================================================

def acqTrace(project_name, NS=10, ttest=False):

    project = [project_name]
    for pn in project:
        if not os.path.exists(pn):
            os.makedirs(pn)

    traces = []
    data = []
    if ttest is True:
        traces_fix = []
        data_fix = []
    
    # Each input is a couple of bytearray, which are the shares of the input
    for i in tqdm(range(NS)):
        if ttest is True and i%2 == 0:  
            r_key = os.urandom(16)   
            r_nonce = os.urandom(16)
            r_ad = os.urandom(16)   
            r_pt = os.urandom(16)
            # All the logic states of the input data are 0 -> the shares are equal
            key = (r_key, r_key)
            nonce = (r_nonce, r_nonce)
            AD = (r_ad, r_ad)
            PT    = (r_pt, r_pt)
            rand  = (os.urandom(40*12))

        else:
            key   = (os.urandom(16),os.urandom(16))
            nonce = (os.urandom(16),os.urandom(16))
            AD    = (os.urandom(16),os.urandom(16))
            PT    = (os.urandom(16),os.urandom(16))
            rand  = (os.urandom(40*12))
        
        # capture_trace is defined in CW305_ascon_dom.py
        res, t = target.capture_trace(scope, key, nonce, AD, PT, rand)
        if res is not None:
            if ttest is True and i%2 == 0:
                traces_fix.append(t)
                data_fix.append(res)
            else:
                traces.append(t)
                data.append(res)

    timestr = time.strftime("%Y%m%d-%H%M%S")
    for i, pn in enumerate(project):
        np.save(os.path.join(pn, "Random/traces_"+timestr+".npy"), traces)
        np.save(os.path.join(pn, "Random/data_"+timestr+".npy"), data)
        if ttest is True:
            np.save(os.path.join(pn, "Fixed/traces_fix_"+timestr+".npy"), traces_fix)
            np.save(os.path.join(pn, "Fixed/data_fix_"+timestr+".npy"), data_fix)
        
#=================================================
# Capture setup
#=================================================

scope = cw.scope()
scope.default_setup()
scope.adc.samples = 1300 # Number of acquired samples for each trace

scope.adc.offset = 0
scope.adc.basic_mode = "rising_edge"
scope.trigger.triggers = "tio4"
scope.io.tio1 = "serial_rx"
scope.io.tio2 = "serial_tx"
scope.io.hs2 = "disabled"
scope.gain.db = 35 # the analog signal gain setting 

#=================================================
# Upload of the bitstream and response test
#=================================================

fpga_id = None
platform = 'ss2_a35'
target = cw.target(scope, cw1, force=True, platform=platform, fpga_id=fpga_id, bsfile='./bitstream_husky_ascon_with_dom.bit')

scope.clock.clkgen_freq = 7.37e6
scope.io.hs2 = 'clkgen'
scope.clock.clkgen_src = 'system'
scope.clock.adc_mul = 8 # the multiplier between the ADC (analog-to-digital converter) clock and the main clock source (how many samples per clock cycle)
scope.clock.reset_dcms()
time.sleep(0.1)
target._ss2_test_echo()

for i in range(5):
    scope.clock.reset_adc()
    time.sleep(1)
    if scope.clock.adc_locked:
        break 
assert (scope.clock.adc_locked), "ADC failed to lock"

res = target.get_id()
print("Loaded CW305 FPGA with bitsream id: {}".format(res.hex()))

#=================================================
# Acqision of the traces, main
#=================================================

ttest = True
project_file = "./acquisition/folder_in_which_the_traces_are_saved"
if not os.path.exists(project_file+"/Random"):
    os.makedirs(project_file+"/Random")
    if ttest:
        os.makedirs(project_file+"/Fixed")


N = 100000 # Total number of acquired traces
NS = 1000 # Number of traces for each file

for j in range(int(N / NS)):
    now = datetime.datetime.now()
    print("Traces: {}, time {}".format(j * NS, now))
    acqTrace(project_file, NS, ttest)

# Closing
scope.dis()
target.dis()


