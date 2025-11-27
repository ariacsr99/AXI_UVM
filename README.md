# AXI_UVM
AXI UVM testbench

--- AXI DUT flow ---
1. Reset sequence
    - initialise all output ports to 0
    - AWREADY, ARREADY, BREADY & RREADY set to 1 as default

2. Write request channel (AW)
    - when both AWVALID && AWREADY are asserted, store AWADDR, AWID, AWLEN, AWSIZE & AWBURST into respective local registers
    - LEN + 1: indicate total number of beat transfers
    - SIZE: 2^SIZE bytes size for each beat
    - BURST: 2'b01 = INCR, 2'b10 = WRAP, 2'b00 = FIXED

3. Write data channel (W)
    - when both WVALID && WREADY asserted, store WDATA in local memory array
    - to also consider WSTRB (each bit of WSTRB controls every 8-bit of WDATA)
        WSTRB[0] -> WDATA[7:0]
        WSTRB[1] -> WDATA[15:8]
        WSTRB[2] -> WDATA[23:16]
        WSTRB[3] -> WDATA[31:24]
        WSTRB[i] -> WDATA[(i+1)*8-1:i*8]
    - assert WLAST when last beat is transferred

4. Write response channel (B)
    - when both BVALID && BREADY asserted -> write transaction complete
    - BRESP == 2'b00 (OKAY) to indicate successful transfer

5. Read request channel (AR)
    - when both ARVALID and ARREADY asserted, store ARADDR, ARID, ARLEN, ARSIZE & ARBURST into respective local registers

6. Read data channel (R)
    - when both RVALID and RREADY asserted, fetch value from local mem_array and place into RDATA
    - assert RLAST during last beat transfer
    - when RLAST asserted, RRESP == 2'b00 (OKAY) to indicate successful transfer


RESULTS
- AXI base test which performs 2 directed write/read and randomized write/read burst
- Assumption: LEN = 3 (4 beat transfers) , SIZE = 2, BURST = 2'b01 (INCR mode)

2 directed write/read:
<img width="884" height="397" alt="image" src="https://github.com/user-attachments/assets/2b42d53c-6567-4869-a7eb-c2cf992aaed1" />

Randomized write/read burst:
<img width="892" height="397" alt="image" src="https://github.com/user-attachments/assets/402db456-8b3e-413a-8019-c52152e7ec7a" />

Log messages:
AW REQ:
<img width="891" height="317" alt="image" src="https://github.com/user-attachments/assets/197e333f-fbb0-4bb1-a6be-b5906e3b5ce0" />

W REQ:
<img width="891" height="228" alt="image" src="https://github.com/user-attachments/assets/54f5c180-0f7b-41d4-895e-5af73f9581cc" />

BRESP:
<img width="894" height="291" alt="image" src="https://github.com/user-attachments/assets/cc51684b-2f3b-4a15-b75c-f422a48cbe09" />

AR REQ:
<img width="896" height="246" alt="image" src="https://github.com/user-attachments/assets/7baddb33-f74a-41d9-8c48-dce9d5560935" />

R REQ:
<img width="895" height="289" alt="image" src="https://github.com/user-attachments/assets/acd51344-31b0-4f2b-a172-1ea8036b4954" />

