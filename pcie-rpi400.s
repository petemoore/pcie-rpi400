.global _start

.text

_start:
  mrs     x0, mpidr_el1            // x0 = Multiprocessor Affinity Register.
  and     x0, x0, #0x3             // x0 = core number.
  cbnz    x0, sleep_core           // Put all cores except core 0 to sleep.

  mov     x0, #0x00000000ff800000
  str     wzr, [x0]
  mov     w1, #0x0000000080000000
  str     w1, [x0, #8]

  mrs     x0, s3_1_c11_c0_2        // l2ctlr_el1
  mov     x1, #0x0000000000000022
  orr     x0, x0, x1
  msr     s3_1_c11_c0_2, x0

  ldr     x0, =0x000000000337f980  // 54,000,000 Hz
  msr     cntfrq_el0, x0

  msr     cntvoff_el2, xzr

  msr     cptr_el3, xzr

  mov     x0, #0x0000000000000531
  msr     scr_el3, x0

  adrp    x0, VectorTableEL3
  msr     vbar_el3, x0

  mov     x0, #0x0000000000000040
  msr     s3_1_c15_c2_1, x0        // cpuectlr_el1 

// setup gic
  mrs     x0, mpidr_el1
  ldr     x2, =0x00000000ff841000
  tst     x0, #0x3
  b.eq    1f
  mov     w0, #0x3
  str     w0, [x2]
1:
  add     x1, x2, #0x0000000000001000
  mov     w0, #0x000001e7
  str     w0, [x1]
  mov     w0, #0x000000ff
  str     w0, [x1, #4]
  add     x2, x2, #0x80
  mov     x0, #0x20
  mov     w1, #0xffffffff
  2:
    subs    x0, x0, #0x4
    str     w1, [x2, x0]
    b.ne    2b

  ldr     x0, =0x0000000030c50830
  msr     sctlr_el2, x0

  mov     x0, #0x00000000000003c9
  msr     spsr_el3, x0

  adr     x0, 3f
  msr     elr_el3, x0
  eret

3:
  ldr     x0, =0x0000000000080090  // TODO
  msr     sp_el1, x0

  adrp    x0, VectorTable
  msr     vbar_el2, x0

  mrs     x0, cnthctl_el2
  orr     x0, x0, #0x0000000000000003
  msr     cnthctl_el2, x0

  msr     cntvoff_el2, xzr

  mrs     x0, midr_el1
  msr     vpidr_el2, x0

  mrs     x1, mpidr_el1
  msr     vmpidr_el2, x1

  mov     x0, #0x00000000000033ff
  msr     cptr_el2, x0

  msr     hstr_el2, xzr

  mov     x0, #0x0000000000300000
  msr     cpacr_el1, x0

  mov     x0, #0x0000000080000000
  msr     hcr_el2, x0

  ldr     x0, =0x0000000030d00800
  msr     sctlr_el1, x0

  mov     x0, #0x00000000000003c4
  msr     spsr_el2, x0

  adr     x0, 4f
  msr     elr_el2, x0
  eret

4:
  msr     daifclr, #0x1
  msr     daifclr, #0x2

  adrp    x0, VectorTable
  msr     vbar_el1, x0

  mov     x1, #0x00000000000004ff
  msr     mair_el1, x1

  mov     x0, #0xffffffffffffffff  // TODO
  msr     ttbr0_el1, x0

  mrs     x0, tcr_el1
  ldr     x2, =0xfffffff9ffbf755c  // 0b1111111111111111111111111111100111111111101111110111010101011100
  and     x0, x0, x2               // 0b-----------------------------00----------0------0---0-0-0-0---00
  ldr     x1, =0x000000010080751c  // 0b0000000000000000000000000000000100000000100000000111010100011100
  orr     x0, x0, x1               // 0b-----------------------------001--------10------011101010-011100
  msr     tcr_el1, x0

  mrs     x0, sctlr_el1
  ldr     x2, =0xfffffffffff7fffd  // 0b1111111111111111111111111111111111111111111101111111111111111101
  and     x0, x0, x2               // 0b--------------------------------------------0-----------------0-
  mov     x1, #0x0000000000001005  // 0b0000000000000000000000000000000000000000000000000001000000000101
  orr     x0, x0, x1               // 0b--------------------------------------------0------1---------101
  msr     sctlr_el1, x0

sleep_core:
  wfe                              // Sleep until woken.
  b       sleep_core               // Go back to sleep.

UnexpectedStub:
  mrs    x0, esr_el1
  mrs    x1, spsr_el1
  mov    x2, x30
  mrs    x3, elr_el1
  mrs    x4, sp_el0
  mov    x5, sp
  mrs    x6, far_el1
  str    x6, [sp, #-16]!
  stp    x4, x5, [sp, #-16]!
  stp    x2, x3, [sp, #-16]!
  stp    x0, x1, [sp, #-16]!
  mov    x0, #0x0
  mov    x1, sp
  b    ExceptionHandler

SynchronousStub:
  mrs    x0, esr_el1
  mrs    x1, spsr_el1
  mov    x2, x30
  mrs    x3, elr_el1
  mrs    x4, sp_el0
  mov    x5, sp
  mrs    x6, far_el1
  str    x6, [sp, #-16]!
  stp    x4, x5, [sp, #-16]!
  stp    x2, x3, [sp, #-16]!
  stp    x0, x1, [sp, #-16]!
  mov    x0, #0x1
  mov    x1, sp
  b    ExceptionHandler

SErrorStub:
  mrs    x0, esr_el1
  mrs    x1, spsr_el1
  mov    x2, x30
  mrs    x3, elr_el1
  mrs    x4, sp_el0
  mov    x5, sp
  mrs    x6, far_el1
  str    x6, [sp, #-16]!
  stp    x4, x5, [sp, #-16]!
  stp    x2, x3, [sp, #-16]!
  stp    x0, x1, [sp, #-16]!
  mov    x0, #0x2
  mov    x1, sp
  b    ExceptionHandler

IRQStub:
  stp    x29, x30, [sp, #-16]!
  mrs    x29, elr_el1
  mrs    x30, spsr_el1
  stp    x29, x30, [sp, #-16]!
  msr    daifclr, #0x1
  stp    x27, x28, [sp, #-16]!
  stp    x25, x26, [sp, #-16]!
  stp    x23, x24, [sp, #-16]!
  stp    x21, x22, [sp, #-16]!
  stp    x19, x20, [sp, #-16]!
  stp    x17, x18, [sp, #-16]!
  stp    x15, x16, [sp, #-16]!
  stp    x13, x14, [sp, #-16]!
  stp    x11, x12, [sp, #-16]!
  stp    x9, x10, [sp, #-16]!
  stp    x7, x8, [sp, #-16]!
  stp    x5, x6, [sp, #-16]!
  stp    x3, x4, [sp, #-16]!
  stp    x1, x2, [sp, #-16]!
  str    x0, [sp, #-16]!
  ldr    x0, af9b8 <HVCStub+0x18>
  str    x29, [x0]
  bl    ab400 <InterruptHandler>
  ldr    x0, [sp], #16
  ldp    x1, x2, [sp], #16
  ldp    x3, x4, [sp], #16
  ldp    x5, x6, [sp], #16
  ldp    x7, x8, [sp], #16
  ldp    x9, x10, [sp], #16
  ldp    x11, x12, [sp], #16
  ldp    x13, x14, [sp], #16
  ldp    x15, x16, [sp], #16
  ldp    x17, x18, [sp], #16
  ldp    x19, x20, [sp], #16
  ldp    x21, x22, [sp], #16
  ldp    x23, x24, [sp], #16
  ldp    x25, x26, [sp], #16
  ldp    x27, x28, [sp], #16
  msr    daifset, #0x1
  ldp    x29, x30, [sp], #16
  msr    elr_el1, x29
  msr    spsr_el1, x30
  ldp    x29, x30, [sp], #16
  eret

FIQStub:
  stp    x29, x30, [sp, #-16]!
  stp    x27, x28, [sp, #-16]!
  stp    x25, x26, [sp, #-16]!
  stp    x23, x24, [sp, #-16]!
  stp    x21, x22, [sp, #-16]!
  stp    x19, x20, [sp, #-16]!
  stp    x17, x18, [sp, #-16]!
  stp    x15, x16, [sp, #-16]!
  stp    x13, x14, [sp, #-16]!
  stp    x11, x12, [sp, #-16]!
  stp    x9, x10, [sp, #-16]!
  stp    x7, x8, [sp, #-16]!
  stp    x5, x6, [sp, #-16]!
  stp    x3, x4, [sp, #-16]!
  stp    x1, x2, [sp, #-16]!
  str    x0, [sp, #-16]!
  ldr    x2, af9c0 <HVCStub+0x20>
  ldr    x1, [x2]
  cmp    x1, #0x0
  b.eq   ?????
  ldr    x0, [x2, #8]
  blr    x1
  ldr    x0, [sp], #16
  ldp    x1, x2, [sp], #16
  ldp    x3, x4, [sp], #16
  ldp    x5, x6, [sp], #16
  ldp    x7, x8, [sp], #16
  ldp    x9, x10, [sp], #16
  ldp    x11, x12, [sp], #16
  ldp    x13, x14, [sp], #16
  ldp    x15, x16, [sp], #16
  ldp    x17, x18, [sp], #16
  ldp    x19, x20, [sp], #16
  ldp    x21, x22, [sp], #16
  ldp    x23, x24, [sp], #16
  ldp    x25, x26, [sp], #16
  ldp    x27, x28, [sp], #16
  ldp    x29, x30, [sp], #16
  eret
  ldr    x1, ???????????
  mov    w0, #0x0
  str    w0, [x1]
  b    ??????????

SMCStub:
  ldr    x2, ??????????
  mov    sp, x2
  str    x30, [sp, #-16]!
  bl    SecureMonitorHandler
  ldr    x30, [sp], #16
  eret

HVCStub:
  mrs    x0, spsr_el2
  and    x0, x0, #0xfffffffffffffff0
  mov    x1, #0x9                       // #9
  orr    x0, x0, x1
  msr    spsr_el2, x0
  eret
  .word    0x000bd070
  .word    0x00000000
  .word    0x000bd058
  .word    0x00000000
  .word    0xfe00b20c
  .word    0x00000000
  .word    0x000bd390

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
