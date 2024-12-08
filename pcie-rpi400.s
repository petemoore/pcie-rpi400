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

  mov     x0, #0x0000000000070000  // TODO
  msr     vbar_el3, x0

  mov     x0, #0x0000000000000040
  msr     s3_1_c15_c2_1, x0        // cpuectlr_el1 

// setup gic
  mrs     x0, mpidr_el1
  ldr     x2, =0x00000000ff841000
  tst     x0, #0x0000000000000003
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

  ldr     x0, =0x00000000000af000  // TODO
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

  ldr     x0, =0x00000000000af000  // TODO
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
