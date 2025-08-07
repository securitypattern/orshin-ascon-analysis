
#=================================================
# Copyright (c) 2025, Security Pattern
# All rights reserved.
#
#    This file is part of: Analysis of ountermeasures used to protect the Ascon algorithm.
#
#    SPDX-License-Identifier: MIT 
#=================================================

import random
import math

"""
Ascon v1.2, AEAD algorithm, variant "Ascon-128"
Implementation protected at first order against SCA, with the and operation masked with DOM
Python version of variant V1 in repo https://github.com/ascon/ascon-hardware-sca (implemented by the Hardware Design Group - Graz)
"""

debug = False # Set this variable to print the intermediate state after each phase of the encryption/hashing process
debugpermutation = False # Set this variable to print the intermediate state after each step of the permutation's round function

# === Ascon AEAD encryption, 2 shares, first order protection of the AND operation with DOM ===

def ascon_encrypt_shares(key1, key2, nonce1, nonce2, associateddata1, associateddata2, plaintext1, plaintext2, a, b, rate, v_rand): 
    """
    Ascon encryption.
    key1, key2: two bytes objects of size 16 (for Ascon-128, Ascon-128a; 128-bit security) or 20 (for Ascon-80pq; 128-bit security)
    nonce1, nonce2: two bytes objects of size 16 (must not repeat for the same key!)
    associateddata: a bytes object of arbitrary length
    plaintext: a bytes object of arbitrary length
    variant: "Ascon-128", "Ascon-128a", or "Ascon-80pq" (specifies key size, rate and number of rounds)
    returns a bytes object of length len(plaintext)+16 containing the ciphertext and tag
    """
    # Verify the length of key and nonce
    assert(len(key1) == 16 and len(key2) == 16 and len(nonce1) == 16 and len(nonce2) == 16)
    # State initialization -> two states
    S1 = [0, 0, 0, 0, 0]
    S2 = [0, 0, 0, 0, 0]
    k = len(key1) * 8   # bits of the keys
    #a = 12   # n of rounds -> pa
    #b = 6   # rounds -> pb
    #rate = 8   # rate bytes

    ascon_initialize(S1, S2, k, rate, a, b, key1, key2, nonce1, nonce2, v_rand[0:5*a])
    #print("len assoc data"+str(len(associateddata1)/rate))
    ascon_process_associated_data(S1, S2, b, rate, associateddata1, associateddata2, v_rand[5*a:5*(a+b*math.ceil((len(associateddata1)+1)/rate))])
    ciphertext1, ciphertext2 = ascon_process_plaintext(S1, S2, b, rate, plaintext1, plaintext2, v_rand[5*(a+b*math.ceil((len(associateddata1)+1)/rate)):5*(a+b*(math.ceil((len(associateddata1)+1)/rate)+math.ceil(((len(plaintext1)+1)/rate)-1)))])
    # print the chipertext and its shares
    #printbytearray(ciphertext1, "ciphertext share 1")
    #printbytearray(ciphertext2, "ciphertext share 2")
    ciphertext = bytes([_a ^ _b for _a, _b in zip(ciphertext1, ciphertext2)])
    #printbytearray(ciphertext, "ciphertext")
    tag1,tag2 = ascon_finalize(S1, S2, rate, a, key1, key2, v_rand[5*(a+b*(math.ceil((len(associateddata1)+1)/rate)+math.ceil(((len(plaintext1)+1)/rate)-1))):5*(2*a+b*(math.ceil((len(associateddata1)+1)/rate)+math.ceil(((len(plaintext1)+1)/rate)-1)))])
    # print the tag and its shares
    #printbytearray(tag1, "tag share 1")
    #printbytearray(tag2, "tag share 2")
    tag = bytes([_a ^ _b for _a, _b in zip(tag1, tag2)])
    #printbytearray(tag, "tag")
    return ciphertext1 + tag1, ciphertext2 + tag2

    # === Ascon state initialization ===

def ascon_initialize(S1, S2, k, rate, a, b, key1, key2, nonce1, nonce2, v_rand):
    """
    Ascon initialization phase - internal helper function.
    S1, S2: Ascon states, two lists of 5 64-bit integers (total state bits: 320)
    k: key size in bits
    rate: block size in bytes (8 for Ascon-128)
    a: number of initialization/finalization rounds for permutation
    b: number of intermediate rounds for permutation
    key1, key2: two bytes objects of size 16 (for Ascon-128)
    nonce1, nonce2: two bytes objects of size 16
    returns nothing, updates S1, S2
    """

    iv_zero_key_nonce2 = to_bytes([k, rate * 8, a, b] + (20-len(key2))*[0]) + key2 + nonce2
    S2[0], S2[1], S2[2], S2[3], S2[4] = bytes_to_state(iv_zero_key_nonce2)
    iv_zero_key_nonce1 = to_bytes(8*[0]) + key1 + nonce1
    S1[0], S1[1], S1[2], S1[3], S1[4] = bytes_to_state(iv_zero_key_nonce1)
    if debug: 
        S = [S2[i] ^ S1[i] for i in range(5)]
        printstate(S1, "initial value state share 1:")
        printstate(S2, "initial value state share 2:")
        printstate(S, "initial value state-xor:")

    # In the initalization, "a" round of the round transformation p are applied
    ascon_permutation(S1, S2, v_rand, a)

    zero_key1 = bytes_to_state(zero_bytes(40-len(key1)) + key1)
    S1[0] ^= zero_key1[0]
    S1[1] ^= zero_key1[1]
    S1[2] ^= zero_key1[2]
    S1[3] ^= zero_key1[3]
    S1[4] ^= zero_key1[4]
    zero_key2 = bytes_to_state(zero_bytes(40-len(key2)) + key2)
    S2[0] ^= zero_key2[0]
    S2[1] ^= zero_key2[1]
    S2[2] ^= zero_key2[2]
    S2[3] ^= zero_key2[3]
    S2[4] ^= zero_key2[4]

    if debug: 
        S = [S2[i] ^ S1[i] for i in range(5)]
        printstate(S1, "initialization state share 1:")
        printstate(S2, "initialization state share 2:")
        printstate(S, "initialization state-xor:")

# === Ascon processing associated data ===

def ascon_process_associated_data(S1, S2, b, rate, associateddata1, associateddata2, v_rand):
    """
    Ascon associated data processing phase - internal helper function.
    S1, S2: Ascon states, two lists of 5 64-bit integers
    b: number of intermediate rounds for permutation
    rate: block size in bytes (8 for Ascon-128)
    associateddata: a bytes object of arbitrary length
    returns nothing, updates S1, S2
    """
    if len(associateddata1) > 0:
        a_zeros = rate - (len(associateddata1) % rate) - 1
        a_padding1 = to_bytes([0x80] + [0 for i in range(a_zeros)]) 
        a_padded1 = associateddata1 + a_padding1
        a_padding2 = to_bytes([0x00] + [0 for i in range(a_zeros)]) 
        a_padded2 = associateddata2 + a_padding2

        #print(len(v_rand))

        idx_rand = 0
        for block in range(0, len(a_padded1), rate):
            #print("block "+str(block))
            S1[0] ^= bytes_to_int(a_padded1[block:block+8]) 
            S2[0] ^= bytes_to_int(a_padded2[block:block+8]) 
            ascon_permutation(S1, S2, v_rand[idx_rand:(idx_rand+5*b)], b)
            idx_rand += 5*b
            #print(idx_rand)
                            

    S1[4] ^= 1
    if debug: 
        S = [S2[i] ^ S1[i] for i in range(5)]
        printstate(S1, "process associated data, state share 1:")
        printstate(S2, "process associated data, state share 2:")
        printstate(S, "process associated data, state-xor:")

# === Ascon processing plaintext ===

def ascon_process_plaintext(S1, S2, b, rate, plaintext1, plaintext2, v_rand):
    """
    Ascon plaintext processing phase (during encryption) - internal helper function.
    S: Ascon state, a list of 5 64-bit integers
    b: number of intermediate rounds for permutation
    rate: block size in bytes (8 for Ascon-128)
    plaintext: a bytes object of arbitrary length
    returns the ciphertext (without tag), updates S
    """
    p_lastlen = len(plaintext1) % rate
    p_padding1 = to_bytes([0x80] + (rate-p_lastlen-1)*[0x00])
    p_padding2 = to_bytes([0x00] + (rate-p_lastlen-1)*[0x00])
    p_padded1 = plaintext1 + p_padding1
    p_padded2 = plaintext2 + p_padding2

    ciphertext1 = to_bytes([])
    ciphertext2 = to_bytes([])
    idx_rand = 0
    for block in range(0, len(p_padded1) - rate, rate): # for all the blocks less the last one
        S1[0] ^= bytes_to_int(p_padded1[block:block+8])
        S2[0] ^= bytes_to_int(p_padded2[block:block+8]) 
        ciphertext1 += int_to_bytes(S1[0], 8) 
        ciphertext2 += int_to_bytes(S2[0], 8) 
        ascon_permutation(S1, S2, v_rand[idx_rand:(idx_rand+5*b)], b)
        idx_rand += 5*b 


    block = len(p_padded1) - rate
    S1[0] ^= bytes_to_int(p_padded1[block:block+8])
    S2[0] ^= bytes_to_int(p_padded2[block:block+8])
    ciphertext1 += int_to_bytes(S1[0], 8)[:p_lastlen]
    ciphertext2 += int_to_bytes(S2[0], 8)[:p_lastlen]

    if debug: 
        S = [S2[i] ^ S1[i] for i in range(5)]
        printstate(S1, "process plaintext, state share 1:")
        printstate(S2, "process plaintext, state share 2:")
        printstate(S, "process plaintext, state-xor:")

    return ciphertext1, ciphertext2

    # === Ascon state finalization ===

def ascon_finalize(S1, S2, rate, a, key1, key2, v_rand):
    """
    Ascon finalization phase - internal helper function.
    S1, S2: Ascon states, two lists of 5 64-bit integers
    rate: block size in bytes (8 for Ascon-128)
    a: number of initialization/finalization rounds for permutation
    key1, key2: two bytes objects of size 16 (for Ascon-128)
    returns the tag, updates S
    """
    assert(len(key1) in [16,20])
    assert(len(key2) in [16,20])
    S1[rate//8+0] ^= bytes_to_int(key1[0:8])
    S1[rate//8+1] ^= bytes_to_int(key1[8:16])
    S1[rate//8+2] ^= bytes_to_int(key1[16:] + zero_bytes(24-len(key1)))
    S2[rate//8+0] ^= bytes_to_int(key2[0:8])
    S2[rate//8+1] ^= bytes_to_int(key2[8:16])
    S2[rate//8+2] ^= bytes_to_int(key2[16:] + zero_bytes(24-len(key2)))

    ascon_permutation(S1, S2, v_rand, a)

    S1[3] ^= bytes_to_int(key1[-16:-8])
    S1[4] ^= bytes_to_int(key1[-8:])
    S2[3] ^= bytes_to_int(key2[-16:-8])
    S2[4] ^= bytes_to_int(key2[-8:])
    tag1 = int_to_bytes(S1[3], 8) + int_to_bytes(S1[4], 8)
    tag2 = int_to_bytes(S2[3], 8) + int_to_bytes(S2[4], 8)
    if debug: 
        S = [S2[i] ^ S1[i] for i in range(5)]
        printstate(S1, "finalization, state share 1:")
        printstate(S2, "finalization, state share 2:")
        printstate(S, "finalization, state-xor:")
    return tag1,tag2

# === Ascon permutation, and protected at the first order with DOM ===

def ascon_permutation(S1, S2, v_rand, rounds=1):
    """
    Ascon core permutation for the sponge construction - internal helper function.
    S1, S2: Ascon states, two lists of 5 64-bit integers
    rounds: number of rounds to perform
    returns nothing, updates S1, S2
    """

    rand_idx = 0

    assert(rounds <= 12)
    if debugpermutation: 
        S = [S2[i] ^ S1[i] for i in range(5)]
        printstate(S1, "permutation input state share 1:")
        printstate(S2, "permutation input state share 2:")
        printstate(S, "permutation input state-xor:")

    for r in range(12-rounds, 12):

        # --- add round constants ---
        S1[2] ^= (0xf0 - r*0x10 + r*0x1) 
        if debugpermutation: 
            S = [S2[i] ^ S1[i] for i in range(5)]
            printstate(S1, "round constant addition state share 1:")
            printstate(S2, "round constant addition state share 2:")
            printstate(S, "round constant addition state-xor:")

        # --- substitution layer ---

        S1[0] = S1[0] ^ S1[4]  
        S1[2] = S1[2] ^ S1[1] 
        S1[4] = S1[4] ^ S1[3] 

        S2[0] = S2[0] ^ S2[4] 
        S2[2] = S2[2] ^ S2[1]
        S2[4] = S2[4] ^ S2[3] 

        T = [masked_and(S1[i], S1[(i+1)%5], S2[i], S2[(i+1)%5], v_rand[rand_idx+i]) for i in range(5)]
        T1 = [T[i][0] for i in range(5)]
        T2 = [T[i][1] for i in range(5)]

        #print(rand_idx)
        rand_idx += 5

        for i in range(5):
            S1[i] ^= T1[(i+1)%5]
        S1[1] ^= S1[0]
        S1[0] ^= S1[4]
        S1[3] ^= S1[2]
        S1[2] ^= 0XFFFFFFFFFFFFFFFF

        for i in range(5):
            S2[i] ^= T2[(i+1)%5]
        S2[1] ^= S2[0]
        S2[0] ^= S2[4]
        S2[3] ^= S2[2]
        
        if debugpermutation: 
            S = [S2[i] ^ S1[i] for i in range(5)]
            printstate(S1, "substitution layer state share 1")
            printstate(S2, "substitution layer state share 2")
            printstate(S, "substitution layer state-xor")

        # --- linear diffusion layer ---
        S1[0] ^= rotr(S1[0], 19) ^ rotr(S1[0], 28)
        S1[1] ^= rotr(S1[1], 61) ^ rotr(S1[1], 39)
        S1[2] ^= rotr(S1[2],  1) ^ rotr(S1[2],  6)
        S1[3] ^= rotr(S1[3], 10) ^ rotr(S1[3], 17)
        S1[4] ^= rotr(S1[4],  7) ^ rotr(S1[4], 41)

        S2[0] ^= rotr(S2[0], 19) ^ rotr(S2[0], 28)
        S2[1] ^= rotr(S2[1], 61) ^ rotr(S2[1], 39)
        S2[2] ^= rotr(S2[2],  1) ^ rotr(S2[2],  6)
        S2[3] ^= rotr(S2[3], 10) ^ rotr(S2[3], 17)
        S2[4] ^= rotr(S2[4],  7) ^ rotr(S2[4], 41)
        if debugpermutation: 
            S = [S2[i] ^ S1[i] for i in range(5)]
            printstate(S1, "linear diffusion layer state share 1")
            printstate(S2, "linear diffusion layer state share 2")
            printstate(S, "linear diffusion layer state-xor")

#  === AND operation masked at the first order with DOM ===

def masked_and(S1_1, S1_2, S2_1, S2_2, Z): 
    #Z = bytes_to_int(random.randbytes(8))
    #Z = 0
    reg1 = ((S1_1 ^ 0xFFFFFFFFFFFFFFFF) & S2_2) ^ Z
    r1 = (S1_1 ^ 0xFFFFFFFFFFFFFFFF) & S1_2 ^ reg1
    reg2 = (S1_2 & S2_1) ^ Z
    r2 = S2_1 & S2_2 ^ reg2
    return r1,r2

def dom(S1_1, S1_2, S2_1, S2_2): # Si_j = share i of the variable (aka lane) j
    #Z = bytes_to_int(random.randbytes(8))
    Z = 0
    reg1 = ((S1_1 ^ 0xFFFFFFFFFFFFFFFF) & S2_2) ^ Z
    r1 = (S1_1 ^ 0xFFFFFFFFFFFFFFFF) & S1_2 ^ reg1
    reg2 = (S1_2 & S2_1) ^ Z
    r2 = S2_1 & S2_2 ^ reg2
    return r1,r2

# === helper functions ===

def to_bytes(l):
    return bytes(bytearray(l))

def bytes_to_state(bytes): # a state is composed of five 64-bit registers words  
    return [bytes_to_int(bytes[8*w:8*(w+1)]) for w in range(5)]

# enumerate gives a list of couples (i, bi) = (position of the byte, byte)
# b0 is the less significant byte, the other are shifted with growing importance
# all of them are summed to return an unique integer for each list of bytes
def bytes_to_int(bytes): 
    return sum([bi << ((len(bytes) - 1 - i)*8) for i, bi in enumerate(to_bytes(bytes))])

def int_to_bytes(integer, nbytes):
    return to_bytes([(integer >> ((nbytes - 1 - i) * 8)) % 256 for i in range(nbytes)])

def printstate(S, description=""):
    print(" " + description)
    print(" ".join(["{s:016x}".format(s=s) for s in S]))

def zero_bytes(n):
    return n * b"\x00"

def rotr(val, r):
    return (val >> r) | ((val & (1<<r)-1) << (64-r))

def printwords(S, description=""):
    print(" " + description)
    print("\n".join(["  x{i}={s:016x}".format(**locals()) for i, s in enumerate(S)]))

def printbytes(listByte, description=""):
    print(" " + description)
    print(''.join(['\\x%02x' % b for b in listByte]))

def printbytearray(C, description=""):
    print(" " + description)
    print(''.join(C.hex()))

# Function that xor two bytes strings
def byte_xor(ba1, ba2):
    return bytes([_a ^ _b for _a, _b in zip(ba1, ba2)])