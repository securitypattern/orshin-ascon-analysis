# Power analysis of three implementations of Ascon, exploiting Chipwhisperer Husky tool

This GitHub project enables the deployment of selected Ascon algorithm implementations on an FPGA, the acquisition of power traces using the ChipWhisperer Husky tool, and their subsequent analysis. For further information, refer to Deliverable D3.3 of the ORSHIN project.

## Note

Everything done in this repository is based on ChipWhisperer, link to the project: http://www.chipwhisperer.com (ChipWhisperer is a registered trademark of NewAE Technology Inc in the US & Europe). We also refer to their project for the acquisition setup.
We have followed the same naming conventions as in the project, so some files that include "CW305" in their name have actually been modified to run on the CW_312T-A5.

## Devices

Chipwhisper Husky and CW312T-A35 (https://www.newae.com/products/nae-cwhusky)

## Organization of the repository

This repository is organized in the following three folders.
- [Ascon_no_countermeasures]: the implemented Ascon is without any protection against first order side-channel attacks
- [Ascon_DOM]: the implemented Ascon algorithm is protected with Domain Oriented Masking scheme against first order side-channel attack
- [Ascon_TI]: the implemented Ascon algorithm is protected with Threshold Implementation scheme against first order side-channel attack

Each folder, in turn, includes the following contents.
- A bitstream [bitstream_husky_ascon*] which implements the Ascon algorithm (with or without protection, depending on the folder) for the Chipwhisperer Husky (CW312T-A35 board)
- A bitstream [bitstream_CW305_ascon*] which implements the Ascon algorithm (with or without protection, depending on the folder) for the Chipwhisperer CW305 board
- A [CW305_ascon*] file, in which the class CW305_ascon is defined, with relative fucntions
- A [CW305_ascon_defines*] file, which contains the definitions of the register addresses
- [ascon_acquisition] is a Python file which upload the bitstream to the FPGA, connect to the Husky and acquire power traces that are  saved in the folder [acquisition]
- [ascon_analysis] is a Python notebook that upload the power traces and does some inferences on them
- In folder [HW_cw305_ascon*] there are all the files for the hw synthesis of the algorithm. Note that the implementations comes from the following Open Source repositories, and can be linked inside the folder:
    - https://github.com/ascon/ascon-hardware/tree/master for the Ascon without countermeasure
    - https://github.com/ascon/ascon-hardware-sca for the Ascon protected by Domain Oriented Masking scheme
    - https://github.com/aneeshkandi14/ascon-hw-public for the Ascon protected by Threshold Implementation scheme
We have kept the underlying hardware interface exactly the same, and modified the surrounding structure to be modeled on the core architecture.

## How to use the repository

- [Analysis of traces]: in the folder [acquisition] there are some previously acquired traces, that can be uploaded and analysed running code in the notebook [ascon_analysis].
- [Acquisition of new traces]: it is possible to acquire new traces running the Python file [ascon_acquisition]. Note that for each acquisition campaign the name of the folder in which the traces are saved should be changed, and the acquisition values should be checked.