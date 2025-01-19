.macro log char
  stp     x29, x30, [sp, #-16]!
  stp     x0, x1, [sp, #-16]!
  stp     x2, x3, [sp, #-16]!
  stp     x4, x5, [sp, #-16]!
  mrs     x4, nzcv                                // copy N, Z, C, and V flags into x4 (not disturbed by following uart_puts call)
  mov     x0, #\char
  bl      uart_send
  bl      uart_newline
  msr     nzcv, x4                                // restore flags
  ldp     x4, x5, [sp], #16
  ldp     x2, x3, [sp], #16
  ldp     x0, x1, [sp], #16
  ldp     x29, x30, [sp], #16
.endm

.global _start

.text

.align 2
_start:

  mrs     x0, mpidr_el1            // x0 = Multiprocessor Affinity Register.
  and     x0, x0, #0x3             // x0 = core number.
  cbnz    x0, sleep_core           // Put all cores except core 0 to sleep.

  adrp    x0, 0x2000000
  mov     sp, x0
  bl      uart_init
  adr     x0, msg_initialising
  bl      uart_puts

  mrs     x0, currentel
  and     x0, x0, #0x0c
  bl      uart_x0
  bl      uart_newline

  /*
   * LOCAL_CONTROL:
   * Bit 8 clear: Increment by 1 (vs. 2).
   * Bit 7 clear: Timer source is 19.2MHz crystal (vs. APB).
   */
  mov     x0, #0x00000000ff800000
  str     wzr, [x0]
  mov     w1, #0x0000000080000000
  str     w1, [x0, #8]

  /* Set L2 read/write cache latency to 3 */
  mrs     x0, s3_1_c11_c0_2                       // l2ctlr_el1
  mov     x1, #0x0000000000000022
  orr     x0, x0, x1
  msr     s3_1_c11_c0_2, x0

  /* Set up CNTFRQ_EL0 */
  ldr     x0, =0x000000000337f980                 // 54,000,000 Hz
  msr     cntfrq_el0, x0

  /* Set up CNTVOFF_EL2 */
  msr     cntvoff_el2, xzr

  /* Enable FP/SIMD */
  /* bit 10 (TFP) set to 0 */
  msr     cptr_el3, xzr

  /* Set up SCR */
  mov     x0, #0x0000000000000531
  msr     scr_el3, x0

  /* Set up secure monitor entry and stack */
  adrp    x0, VectorTableEL3
  msr     vbar_el3, x0
  mov     sp, x0

  /* Set SMPEN */
  mov     x0, #0x0000000000000040
  msr     s3_1_c15_c2_1, x0                       // cpuectlr_el1

// Set up GIC
// Called from secure mode - set all interrupts to group 1 and enable.
  mrs     x0, mpidr_el1
  ldr     x2, =0x00000000ff841000
  tst     x0, #0x3
  b.eq    1f                                      // primary core
  mov     w0, #0x3                                // Enable group 0 and 1 IRQs from distributor
  str     w0, [x2]
1:
  add     x1, x2, #0x0000000000001000
  mov     w0, #0x000001e7
  str     w0, [x1]                                // Enable group 1 IRQs from CPU interface
  mov     w0, #0x000000ff
  str     w0, [x1, #4]                            // priority mask
  add     x2, x2, #0x80
  mov     x0, #0x20
  mov     w1, #0xffffffff                         // group 1 all the things
  2:
    subs    x0, x0, #0x4
    str     w1, [x2, x0]
    b.ne    2b

  /*
   * Set up SCTLR_EL2
   * All set bits below are res1. LE, no WXN/I/SA/C/A/M
   */
  ldr     x0, =0x0000000030c50830
  msr     sctlr_el2, x0

  /* Switch to EL2 */
  mov     x0, #0x00000000000003c9
  msr     spsr_el3, x0

  adr     x0, 3f
  msr     elr_el3, x0
  bl uart_x0
  log 'a'
  eret

3:
  adrp    x0, 0x2000000
  mov     sp, x0
  log 'b'
  mrs     x0, currentel                           // check if already in EL1t mode?
  cmp     x0, #0x4
  b.eq    5f                                      // skip ahead, if already at EL1t, no work to do

  ldr     x0, =0x00000000002a0000                 // main thread runs in EL1t and uses sp_el0
  mov     sp, x0                                  // init its stack

  adrp    x0, 0x2001000                           // IRQ, FIQ and exception handler run in EL1h
  msr     sp_el1, x0                              // init their stack
  adrp    x0, VectorTable                         // init exception vector table for EL2
  msr     vbar_el2, x0

  mrs     x0, cnthctl_el2                         // Initialize Generic Timers
  orr     x0, x0, #0x0000000000000003             // Enable EL1 access to timers
  msr     cnthctl_el2, x0

  msr     cntvoff_el2, xzr

  mrs     x0, midr_el1
  msr     vpidr_el2, x0

  mrs     x1, mpidr_el1
  msr     vmpidr_el2, x1

  mov     x0, #0x00000000000033ff                 // Disable coprocessor traps
  msr     cptr_el2, x0                            // Disable coprocessor traps to EL2

  msr     hstr_el2, xzr                           // Disable coprocessor traps to EL2

  mov     x0, #0x0000000000300000
  msr     cpacr_el1, x0                           // Enable FP/SIMD at EL1

  mov     x0, #0x0000000080000000                 // 64bit EL1
  msr     hcr_el2, x0

                                                  // SCTLR_EL1 initialization
                                                  //
                                                  // setting RES1 bits (29,28,23,22,20,11) to 1
                                                  // and RES0 bits (31,30,27,21,17,13,10,6) +
                                                  // UCI,EE,EOE,WXN,nTWE,nTWI,UCT,DZE,I,UMA,SED,ITD,
                                                  // CP15BEN,SA0,SA,C,A,M to 0
  ldr     x0, =0x0000000030d00800
  msr     sctlr_el1, x0                           // SCTLR_EL1 = 0x30d00800

  mov     x0, #0x00000000000003c4                 // Return to the EL1_SP1 mode from EL2
  msr     spsr_el2, x0                            // EL1_SP0 | D | A | I | F

  adr     x0, 5f
  msr     elr_el2, x0
  log 'c'
  eret

5:
  adrp    x0, 0x2000000
  mov     sp, x0
  log 'd'

  adrp    x0, VectorTable
  msr     vbar_el1, x0

  msr     daifclr, #0x1
  msr     daifclr, #0x2

log 'A'

# Configure page tables

  adrp    x0, pg_dir                              // x0 = pg_dir (page aligned, so no additional add needed)
  mov     x1, pg_dir_end - pg_dir                 // clear 10 64KB pages
  bl      memzero
  adrp    x0, pg_dir
  mov     x1, #0x1003
  add     x1, x0, x1
  ldr     x3, =0x0000000100000000
  lsr     x2, x3, #30
  3:
    str     x1, [x0], #8                          // [pg_dir + 0x1000 + i*8] = pg_dir + 0x1003 + i*0x1000. PUD table complete for 0 - peripherals end.
    add     x1, x1, #0x1000
    subs    x2, x2, #0x1
    b.ne    3b
  adrp    x0, (pg_dir+0x1000)
  mov     x1, #0x401                              // bit 10: AF=1, bits 2-4: mair attr index = 0 (normal), bits 0-1: 1 (block descriptor)
  ldr     x2, =0x00000000fc000000
  4:                                              // creates 2016 entries for 0x00000000 - 0xfc000000
    str     x1, [x0], #8                          // [pg_dir + 0x2000 + i*8] = 0x401 + i*0x200000. PMD table entries complete for 0 - peripherals start address.
    add     x1, x1, #0x200000
    cmp     x1, x2
    b.lt    4b
  add     x1, x1, #0x4                            // bits 2-4: mair attr index = 1 (device)
  5:                                              // creates 32 entries for 0xfc000000 - 0x100000000
    str     x1, [x0], #8                          // [pg_dir + 0x2000 + i*8] = 0x405 + i*0x200000. PMD table entries complete for peripherals start to peripherals end address.
    add     x1, x1, #0x200000
    cmp     x1, x3
    b.lt    5b
  adrp    x0, pg_dir
  adrp    x1, (pg_dir+0x5000)
  orr     x2, x1, #0b11                           // bit 0 = 1 => valid descriptor. bit 1 = 1 => table descriptor
  str     x2, [x0, 0xc0]                          // [pg_dir+0x10c0] = pg_dir+0x6003. PUD table entry for xHCI region (entry 0x600000000-0x640000000 covers more than xHCI).
  mov     x2, 0x600000000                         // x2 = xHCI start (24GB)
  orr     x3, x2, 0x4000000                       // x3 = xHCI end (64MB higher) (0x604000000) - so we don't fill entire table, only first 32/512 entries
  add     x2, x2, #0x409                          // bit 10: AF=1, bits 2-4: mair attr index = 2 (coherent), bits 0-1: 1 (block descriptor)
  6:                                              // creates 32 entries for xHCI addresses 0x600000000 - 0x604000000
    str     x2, [x1], #8                          // [pg_dir + 0x6000 + i*8] = 0x409 + i*0x200000. PMD table entries complete for xHCI region.
    add     x2, x2, #0x200000
    cmp     x2, x3
    b.lt    6b

  dsb     sy                                      // Data Sync Barrier

  ldr     x0, =0x000004ff
  msr     mair_el1, x0                            // mair_el1 = 0x00000000000004ff => attr index 0 => normal, attr index 1 => device, attr index 2 => coherent

  adrp    x0, pg_dir
log 'B'
  msr     ttbr0_el1, x0                           // Configure page tables for virtual addresses with 0's in first 16 bits
log 'C'

# mrs     x0, tcr_el1
# ldr     x2, =0xfffffff8ffbf0040
# ldr     x1, =0x000000010080751c
# and     x0, x0, x2
                                                  // = bic ~0x000000070040ffbf
                                                  // => clear bits 0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 22, 32, 33, 34
# orr     x0, x0, x1
                                                  // => set bits 2, 3, 4, 8, 10, 12, 13, 14, 23, 32
                                                  // => remaining cleared bits are 0, 1, 5, 7, 9, 11, 15, 22, 33, 34
                                                  // => T0SZ [5:0] = 0b011100 = 28 => region size = 2^(64-28) = 2^36 bytes = 64 GB
                                                  // => EPD0 [7] = 0 => perform walk on a miss
                                                  // => IRGN0 [9:8] = 0b01 => Normal memory, Inner Write-Back Read-Allocate Write-Allocate Cacheable.
                                                  // => ORGN0 [11:10] = 0b01 => Normal memory, Outer Write-Back Read-Allocate Write-Allocate Cacheable.
                                                  // => SH0 [13:12] = 0b11 => Inner Shareable
                                                  // => TG0 [15:14] = 0b01 => Granule size 64KB
                                                  // => T1SZ [21:16] = <unchanged>
                                                  // => A1 [22] = 0 => TTBR0_EL1.ASID defines the ASID
                                                  // => EPD1 [23] = 1 => A TLB miss on an address that is translated using TTBR1_EL1 generates a Translation fault. No translation table walk is performed
                                                  // => IRGN1 [25:24] = <unchanged>
                                                  // => ORGN1 [27:26] = <unchanged>
                                                  // => SH1 [29:28] = <unchanged>
                                                  // => TG1 [31:30] = <unchanged> (Granule size for TTBR1_EL1)
                                                  // => IPS [34:32] = 1 => Intermediate Physical Address size = 36 bits, 64GB.

                                                  //                                           O  I                   O  I
                                                  //                                           R  R  E                R  R  E
                                                  //                                     T  S  G  G  P          T  S  G  G  P
                                                  //                                     G  H  N  N  D A        G  H  N  N  D
                                                  //                                 IPS 1  1  1  1  1 1 T1SZ   0  0  0  0  0   T0SZ

                                                  //   66665555555555444444444433333 333 33 22 22 22 2 2 221111 11 11 11
                                                  //   32109876543210987654321098765 432 10 98 76 54 3 2 109876 54 32 10 98 7 6 543210

# ldr     x0, =0x0000000180100010                 // 0b00000000000000000000000000000 001 10 00 00 00 0 0 010000 00 00 00 00 0 0 010000 // working spectrum4 value
# ldr     x0, =0x00000001801c001c                 // 0b00000000000000000000000000000 001 10 00 00 00 0 0 011100 00 00 00 00 0 0 011100 // intended spectrum4 value
# ldr     x0, =0x000000010080751c                 // 0b00000000000000000000000000000 001 00 00 00 00 1 0 000000 01 11 01 01 0 0 011100 // circle actual value

                                                  // => T0SZ [5:0] = 0b011100 = 28 = region size = 2^(64-28) = 2^36 bytes = 64GB
                                                  // => EPD0 [7] = 0b0 = 0 => perform walk on a miss
                                                  // => IRGN0 [9:8] = 0b00 => Normal memory, Inner Non-cacheable.
                                                  // => ORGN0 [11:10] = 0b00 => Normal memory, Outer Non-cacheable.
                                                  // => SH0 [13:12] = 0b00 => Non-shareable
                                                  // => TG0 [15:14] = 0b00 => 4KB
                                                  // => T1SZ [21:16] = 0b011100 = 28 = region size = 2^(64-28) = 2^36 bytes = 64GB
                                                  // => A1 [22] = 0b => TTRB0_EL1.ASID defines the ASID
                                                  // => EPD1 [23] = 0b (Perform translation table walks using TTBR1_EL1 on TLB miss)
                                                  // => IRGN1 [25:24] = 0b00 (Normal memory, Inner Non-cacheable.)
                                                  // => ORGN1 [27:26] = 0b00 (Normal memory, Outer Non-cacheable.)
                                                  // => SH1 [29:28] = 0b00 (Non-shareable.)
                                                  // => TG1 [31:30] = 0b10 => 4KB Granule size for the TTBR1_EL1.
                                                  // => IPS [34:32] = 0b001 => Intermediate Physical Address size = 36 bits, 64GB
# msr     tcr_el1, x0
log 'D'


                                                  //     S
                                                  //     P
                                                  //     I                                                                                                            C
                                                  //     N                         T    T                             L n                                   E         P
                                                  //   T T   E   T   E E E         W    W D           I     E M       S T               T                   n         1
                                                  //   I M   n T C E n n n   T   T E    E S   A    T  T     n S C E E M L E       S   I S   n R n     E     R       T 5
                                                  //   D A N T C S P A A A T M T M D    D S A T T  C  F B B F C M n n A S n U   E P E E C W T E T U D n   E C U S I H B S
                                                  //   C S M P S O A L S S M E M T E    E B T A C  F  S T T P E O I I O M D C E 0 A I S X X W S W T Z D   O T M E T E E A S
                                                  //   P K I 2 O 0 N S 0 R E 0 T 0 L    n S A 0 F  0  B 1 0 M n W A B E D A I E E N S B T N E 0 I C E B I S X A D D E N 0 A C A M

                                                  //   6 6 6 6 5 5 5 5 5 5 5 5 5 5 4444 4 4 4 4 44 33 3 3 3 3 3 3 3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1
                                                  //   3 2 1 0 9 8 7 6 5 4 3 2 1 0 9876 5 4 3 2 10 98 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0

# circle sctlr_el1: 0x0000000030d01805            // 0b0 0 0 0 0 0 0 0 0 0 0 0 0 0 0000 0 0 0 0 00 00 0 0 0 0 0 0 0 0 1 1 0 0 0 0 1 1 0 1 0 0 0 0 0 0 0 1 1 0 0 0 0 0 0 0 0 1 0 1
# spectrum4 value:  0x0000000030d00801            // 0b0 0 0 0 0 0 0 0 0 0 0 0 0 0 0000 0 0 0 0 00 00 0 0 0 0 0 0 0 0 1 1 0 0 0 0 1 1 0 1 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 1
log 'E'






# mov     x0, #0xffffffffffffffff                 // TODO
# msr     ttbr0_el1, x0
log 'F'

  mrs     x0, tcr_el1
  ldr     x2, =0xfffffff9ffbf755c                 // 0b1111111111111111111111111111100111111111101111110111010101011100
  and     x0, x0, x2                              // 0b-----------------------------00----------0------0---0-0-0-0---00
  ldr     x1, =0x000000010080751c                 // 0b0000000000000000000000000000000100000000100000000111010100011100
  orr     x0, x0, x1                              // 0b-----------------------------001--------10------011101010-011100
  msr     tcr_el1, x0
log 'G'

  mrs     x0, sctlr_el1
  ldr     x2, =0xfffffffffff7fffd                 // 0b1111111111111111111111111111111111111111111101111111111111111101
  and     x0, x0, x2                              // 0b--------------------------------------------0-----------------0-
  mov     x1, #0x0000000000001005                 // 0b0000000000000000000000000000000000000000000000000001000000000101
  orr     x0, x0, x1                              // 0b--------------------------------------------0------1---------101
  msr     sctlr_el1, x0
  isb
log 'H'

  b       sleep_core


sleep_core:
  wfe                                             // Sleep until woken.
  b       sleep_core                              // Go back to sleep.

UnexpectedStub:
  b       ExceptionHandler

SynchronousStub:
  b       ExceptionHandler

SErrorStub:
  b       ExceptionHandler

IRQStub:
  log 'e'
  eret
  log 'f'

FIQStub:
  log 'g'
  eret
  log 'h'

SMCStub:
  log 'i'
  eret
  log 'j'

HVCStub:
  log 'k'
  eret
  log 'l'

ExceptionHandler:
  b       sleep_core


# ------------------------------------------------------------------------------
# See "BCM2837 ARM Peripherals" datasheet pages 90-104:
#   https://cs140e.sergio.bz/docs/BCM2837-ARM-Peripherals.pdf
# ------------------------------------------------------------------------------
# GPFSEL1,        0x0004                       // GPIO Function Select 1
# GPPUD,          0x0094                       // GPIO Pin Pull-up/down Enable
# GPPUDCLK0,      0x0098                       // GPIO Pin Pull-up/down Enable Clock 0

# ------------------------------------------------------------------------------
# Initialise the Mini UART interface for logging over serial port.
# Note, this is Broadcomm's own UART, not the ARM licenced UART interface.
# ------------------------------------------------------------------------------
uart_init:
  adrp    x1, 0xfe215000
  ldr     w2, [x1, #0x4]                          // w2 = [AUX_ENABLES] (Auxiliary enables)
  orr     w2, w2, #1
  str     w2, [x1, #0x4]                          //   [AUX_ENABLES] |= 0x00000001 => Enable Mini UART.
  str     wzr, [x1, #0x44]                        //   [AUX_MU_IER] = 0x00000000 => Disable Mini UART interrupts.
  str     wzr, [x1, #0x60]                        //   [AUX_MU_CNTL] = 0x00000000 => Disable Mini UART Tx/Rx
  mov     w2, #0x6                                // w2 = 6
  str     w2, [x1, #0x48]                         //   [AUX_MU_IIR] = 0x00000006 => Mini UART clear Tx, Rx FIFOs
  mov     w3, #0x3                                // w3 = 3
  str     w3, [x1, #0x4c]                         //   [AUX_MU_LCR] = 0x00000003 => Mini UART in 8-bit mode.
  str     wzr, [x1, #0x50]                        //   [AUX_MU_MCR] = 0x00000000 => Set UART1_RTS line high.
  mov     w2, 0x0000021d
  str     w2, [x1, #0x68]                         //   [AUX_MU_BAUD] = 0x0000010e (rpi3) or 0x0000021d (rpi4)
                                                  //         => baudrate = system_clock_freq/(8*([AUX_MU_BAUD]+1))
                                                  //                       (as close to 115200 as possible)
  adrp    x4, 0xfe200000
  ldr     w2, [x4, #0x4]                          // w2 = [GPFSEL1]
  and     w2, w2, #0xfffc0fff                     // Unset bits 12, 13, 14 (FSEL14 => GPIO Pin 14 is an input).
                                                  // Unset bits 15, 16, 17 (FSEL15 => GPIO Pin 15 is an input).
  orr     w2, w2, #0x00002000                     // Set bit 13 (FSEL14 => GPIO Pin 14 takes alternative function 5).
  orr     w2, w2, #0x00010000                     // Set bit 16 (FSEL15 => GPIO Pin 15 takes alternative function 5).
  str     w2, [x4, #0x4]                          //   [GPFSEL1] = updated value => Enable UART 1.
  str     wzr, [x4, #0x94]                        //   [GPPUD] = 0x00000000 => GPIO Pull up/down = OFF
  mov     x5, #0x96                               // Wait 150 instruction cycles (as stipulated by datasheet).
1:
  subs    x5, x5, #0x1                            // x0 -= 1
  b.ne    1b                                      // Repeat until x0 == 0.
  mov     w2, #0xc000                             // w2 = 2^14 + 2^15
  str     w2, [x4, #0x98]                         //   [GPPUDCLK0] = 0x0000c000 => Control signal to lines 14, 15.
  mov     x0, #0x96                               // Wait 150 instruction cycles (as stipulated by datasheet).
2:
  subs    x0, x0, #0x1                            // x0 -= 1
  b.ne    2b                                      // Repeat until x0 == 0.
  str     wzr, [x4, #0x98]                        //   [GPPUDCLK0] = 0x00000000 => Remove control signal to lines 14, 15.
  str     w3, [x1, #0x60]                         //   [AUX_MU_CNTL] = 0x00000003 => Enable Mini UART Tx/Rx
  ret                                             // Return.


# ------------------------------------------------------------------------------
# Send a byte over Mini UART
# ------------------------------------------------------------------------------
# On entry:
#   x0: char to send
# On exit:
#   x1: 0xfe215000
#   x2: Last read of [AUX_MU_LSR] when waiting for bit 5 to be set
uart_send:
  adrp    x1, 0xfe215000
1:
  ldr     w2, [x1, #0x54]                         // w2 = [AUX_MU_LSR]
  tbz     x2, #5, 1b                              // Repeat last statement until bit 5 is set.
  strb    w0, [x1, #0x40]                         //   [AUX_MU_IO] = w0
  ret

# ------------------------------------------------------------------------------
# Send '\r\n' over Mini UART
# ------------------------------------------------------------------------------
#
# On entry:
#   <nothing>
# On exit:
#   x0: 0x0a
#   x1: 0xfe215000
#   x2: Last read of [AUX_MU_LSR] when waiting for bit 5 to be set
uart_newline:
  stp     x29, x30, [sp, #-16]!                   // Push frame pointer, procedure link register on stack.
  mov     x29, sp                                 // Update frame pointer to new stack location.
  mov     x0, #13
  bl      uart_send
  mov     x0, #10
  bl      uart_send
  ldp     x29, x30, [sp], #0x10                   // Pop frame pointer, procedure link register off stack.
  ret


# ------------------------------------------------------------------------------
# Send a null terminated string over Mini UART.
# ------------------------------------------------------------------------------
#
# On entry:
#   x0 = address of null terminated string
# On exit:
#   x0 = address of null terminator
#   x1 = 0xfe215000
#   x2 = 0
#   x3 = [AUX_MU_LSR]
uart_puts:
  adrp    x1, 0xfe215000
1:
  ldrb    w2, [x0], #1
  cbz     w2, 5f
  cmp     w2, #127
  b.ne    4f
  mov     w2, '('
2:
  ldr     w3, [x1, #0x54]                         // w3 = [AUX_MU_LSR]
  tbz     x3, #5, 2b                              // Repeat last statement until bit 5 is set.
  strb    w2, [x1, #0x40]                         //   [AUX_MU_IO] = w2
  mov     w2, 'c'
3:
  ldr     w3, [x1, #0x54]                         // w3 = [AUX_MU_LSR]
  tbz     x3, #5, 3b                              // Repeat last statement until bit 5 is set.
  strb    w2, [x1, #0x40]                         //   [AUX_MU_IO] = w2
  mov     w2, ')'
4:
  ldr     w3, [x1, #0x54]                         // w3 = [AUX_MU_LSR]
  tbz     x3, #5, 4b                              // Repeat last statement until bit 5 is set.
  strb    w2, [x1, #0x40]                         //   [AUX_MU_IO] = w2
  b       1b
5:
  ret


# ------------------------------------------------------------------------------
# Write the full value of x0 as hex string (0x0123456789abcdef) to Mini UART.
# Sends 18 bytes ('0', 'x', <16 byte hex string>). No trailing newline.
# ------------------------------------------------------------------------------
#
# On entry:
#   x0 = value to write as a hex string to Mini UART.
#   x2 = number of bits to print (multiple of 4)
uart_x0:
  stp     x29, x30, [sp, #-16]!                   // Push frame pointer, procedure link register on stack.
  mov     x29, sp                                 // Update frame pointer to new stack location.
  mov     x2, #64
  bl      uart_x0_s
  ldp     x29, x30, [sp], #16                     // Pop frame pointer, procedure link register off stack.
  ret


# ------------------------------------------------------------------------------
# Write the lower nibbles of x0 as a hex string to Mini UART, with custom size
# (number of nibbles).
# ------------------------------------------------------------------------------
#
# Includes leading '0x' and no trailing newline.
#
# On entry:
#   x0 = value to write as a hex string to Mini UART.
#   x2 = number of lower bits of x0 to print (multiple of 4)
uart_x0_s:
  stp     x29, x30, [sp, #-16]!                   // Push frame pointer, procedure link register on stack.
  mov     x29, sp                                 // Update frame pointer to new stack location.
  stp     x19, x20, [sp, #-16]!                   // Backup x19, x20
  mov     x19, x0                                 // Backup x0 in x19
  sub     sp, sp, #0x20                           // Allocate space on stack for hex string
  mov     w3, #0x7830
  mov     x1, sp
  strh    w3, [x1], #2                            // "0x"
  bl      hex_x0
  strb    wzr, [x1], #1
  mov     x0, sp
  bl      uart_puts
  add     sp, sp, #0x20
  mov     x0, x19                                 // Restore x0
  ldp     x19, x20, [sp], #16                     // Restore x19, x20
  ldp     x29, x30, [sp], #16                     // Pop frame pointer, procedure link register off stack.
  ret

# On entry:
#   x0 = hex value to convert to text
#   x1 = address to write text to (no trailing 0)
#   x2 = number of bits to convert (multiple of 4)
# On exit:
#   x0 = <unchanged>
#   x1 = address of next unused char (x1 += x2/4)
#   x2 = 0
#   x3 = last char in text
hex_x0:
  ror     x0, x0, x2
1:
  ror     x0, x0, #60
  and     w3, w0, #0x0f
  add     w3, w3, 0x30
  cmp     w3, 0x3a
  b.lo    2f
  add     w3, w3, 0x27
2:
  strb    w3, [x1], #1
  subs    w2, w2, #4
  b.ne    1b
  ret

memzero:
1:
  str     xzr, [x0], #8
  subs    x1, x1, #0x8
  b.gt    1b
  ret

msg_initialising:
.asciz    "Initialising...\r\n"


.align 12
VectorTableEL3:
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       SMCStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub

.align 12
VectorTable:
  b       SynchronousStub
.align 7
  b       IRQStub
.align 7
  b       FIQStub
.align 7
  b       SErrorStub
.align 7
  b       SynchronousStub
.align 7
  b       IRQStub
.align 7
  b       FIQStub
.align 7
  b       SErrorStub
.align 7
  b       HVCStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub
.align 7
  b       UnexpectedStub





.bss
.align 16
pg_dir:
.space 0x90000
pg_dir_end:
