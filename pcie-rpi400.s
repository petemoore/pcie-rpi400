.global _start

.text

_start:
  mrs     x0, mpidr_el1            // x0 = Multiprocessor Affinity Register.
  and     x0, x0, #0x3             // x0 = core number.
  cbnz    x0, sleep_core           // Put all cores except core 0 to sleep.

  mrs     x0, s3_1_c11_c0_2        // l2ctlr_el1
  mov     x1, #0x22
  orr     x0, x0, x1
  msr     s3_1_c11_c0_2, x0

  ldr     x0, =0x000000000337f980  // 54,000,000 Hz
  msr     cntfrq_el0, x0

  msr     cntvoff_el2, xzr

  msr     cptr_el3, xzr

  mov     x0, #0x531
  msr     scr_el3, x0

  mov     x0, #0x70000
  msr     vbar_el3, x0

  mov     x0, #0x40
  msr     s3_1_c15_c2_1, x0        // cpuectlr_el1 

  ldr     x0, =0x30c50830
  msr     sctlr_el2, x0

  mov     x0, #0x3c9
  msr     spsr_el3, x0

  ldr     x0, =0x00000000000af000
  msr     vbar_el2, x0

  mrs     x0, cnthctl_el2
  orr     x0, x0, #0x3
  msr     cnthctl_el2, x0

  msr     cntvoff_el2, xzr

  mrs     x0, midr_el1
  msr     vpidr_el2, x0

  mrs     x1, mpidr_el1
  msr     vmpidr_el2, x1

  mov     x0, #0x33ff
  msr     cptr_el2, x0

  msr     hstr_el2, xzr

  mov     x0, #0x300000
  msr     cpacr_el1, x0

  mov     x0, #0x80000000
  msr     hcr_el2, x0

  ldr     x0, =0x30d00800
  msr     sctlr_el1, x0

  mov     x0, #0x3c4
  msr     spsr_el2, x0

  ldr     x0, =0x00000000000af000
  msr     vbar_el1, x0

  mov     x1, #0x4ff
  msr     mair_el1, x1

  mov     x0, #0xffffffffffffffff  // TODO
  msr     ttbr0_el1, x0

  mrs     x0, tcr_el1
  mov     x2, #0xffffffffffff0040
  movk    x2, #0xffbf, lsl #16
  movk    x2, #0xfff8, lsl #32
  mov     x1, #0x751c
  movk    x1, #0x80, lsl #16
  and     x0, x0, x2
  movk    x1, #0x1, lsl #32
  orr     x0, x0, x1
  msr     tcr_el1, x0

  mrs     x0, sctlr_el1
  mov     x2, #0xfffffffffffffffd  //   (bit 1)
  movk    x2, #0xfff7, lsl #16     //   (bit 19)
  mov     x1, #0x1005              //   (bits 0, 2, 12)
  and     x0, x0, x2               //   clear bits 1, 19
  orr     x0, x0, x1               //   set bits 0, 2, 12
  msr     sctlr_el1, x0

sleep_core:
  wfe                              // Sleep until woken.
  b       sleep_core               // Go back to sleep.
