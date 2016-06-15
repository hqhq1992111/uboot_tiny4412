/*
 * (C) Copyright 2011 Samsung Electronics Co. Ltd
 *
 * See file CREDITS for list of people who contributed to this
 * project.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 */

#include <config.h>
#include <asm/arch/cpu.h>

#ifdef CONFIG_CLK_BUS_DMC_200_400
#define MCLK_400
#else
#define MCLK_330
#endif


	.globl mem_ctrl_asm_init
mem_ctrl_asm_init:

	/* Async bridge configuration at CPU_core:
	 * 1: half_sync
	 * 0: full_sync */
	ldr	r0, =0x10010350
	mov	r1, #1
	str	r1, [r0]


/*****************************************************************/
/*DREX0***********************************************************/
/*****************************************************************/

	ldr	r0, =APB_DMC_0_BASE
	/*2.If on die termination is required, enable PhyControl1.term_write_en,  
    *PhyControl1.term_read_en.
	*/
	ldr	r1, =0xe0000086 @bit31=1,mem_term_en;
						@bit30=1,phy_read_en;
						@bit29=1,Duration of DQS Gating Signal
						@bit[14:8]=0,ctrl_offsetc;Delay Offset for DQS Cleaning.This value is valid only after ctrl_resync becomes HIGH and LOW
						@bit[7:4]=0x8;Reference Count for DLL Lock Confirmation
						@bit3=0,fp_resync;when bit3=1,Force DLL Resyncronization
						@bit[2:0]=0x6,ctrl_shiftc;Phase Delay for DQS Cleaning(180 shift).This value is valid only after ctrl_resync becomes HIGH and LOW//???????????
	str	r1, [r0, #DMC_PHYCONTROL1]
	/*3.If ZQ calibration is required, disable PhyZQControl.ctrl_zq_mode_noterm and enable PhyZQCon-trol.
	*ctrl_zq_start so that the PHY automatically calibrates the I/Os to match the driving and termination 
	*impedance by referencing resistor value of an external resistor and updates the matched value during 
	*auto re-fresh cycles.
	*/
	ldr	r1, =0xE3854C03 @bit[13:11]=0x1,On-die-termination Resistor Value= 120 ohm
						@bit[10:8]=0x4,Driver Strength =48 ohm
						@bit1=1,ctrl_zq_start;Auto Calibration Start Signal ZQ I/O calibration starts by setting this register. 
						@bit0=1,ctrl_zq_mode_noterm;Disables termination
	str	r1, [r0, #DMC_PHYZQCONTROL]

	mov	r2, #0x100000
1:	subs	r2, r2, #1
	bne	1b
	
    /*fp_resync from 1 to 0, some bits of PHYCONTROL1 will go into effect,such as ctrl_offsetc(bit[14:8])
	*ctrl_shiftc(bit[2:0])
	*/
	ldr	r1, =0xe000008e @bit3=1,fp_resync;
	str	r1, [r0, #DMC_PHYCONTROL1]
	ldr	r1, =0xe0000086 @bit3=0,fp_resync;
	str	r1, [r0, #DMC_PHYCONTROL1]

	/*4. Set the PhyControl0.ctrl_start_point and PhyControl0.ctrl_inc bit-fields
     to correct value according to clock frequency.  
    Set the PhyControl0.ctrl_dll_on bit-field to "1" to activate the PHY DLL.*/
	ldr	r1, =0x71101008 @bit[31:24]=0x71,ctrl_force;
						@bit[23:16]=0x10,ctrl_inc;This value should be 0x10
						@bit[15:8]=0x10,ctrl_start_point;This value should be 0x10
						@bit3=1,ctrl_dfdqs;Differential DQS
						@bit1=0,ctrl_dll_on;DLL OFF
						@bit0=0,ctrl_start;HIGH active start signal makes DLL run and lock.
	str	r1, [r0, #DMC_PHYCONTROL0]
	ldr	r1, =0x7110100A @bit1=1,ctrl_dll_on;DLL On
	str	r1, [r0, #DMC_PHYCONTROL0]

	/*5. DQS Cleaning: set the PhyControl1.ctrl_shiftc and PhyControl1. 
    ctrl_offsetc bit-fields to the proper value according to clock frequency,  
    board delay and memory tDQSCK parameter.*/  
	ldr	r1, =0xe0000086
	str	r1, [r0, #DMC_PHYCONTROL1]
	
	/*6. Set the PhyControl0.ctrl_start bit-field to "1".*/  
	ldr	r1, =0x7110100B @bit1=1,ctrl_dll_on;DLL ON
						@bit0=1,ctrl_start;active start signal makes DLL run and lock.
	str	r1, [r0, #DMC_PHYCONTROL0]

	ldr	r1, =0x00000000
	str	r1, [r0, #DMC_PHYCONTROL2]

	/*7.Set the ConControl. At this moment, an auto refresh counter should be off.*/
	ldr	r1, =0x0FFF301A @bit5=0,aref_en;Disable autorefresh
	str	r1, [r0, #DMC_CONCONTROL]

	/* 8.Set the MemControl. At this moment, all power down modes and periodic ZQ(pzq_en) should be off*/
	//ldr	r1, =0x00312640
	ldr	r1, =0x00312640@bit[22:20]=0x3,burst length=8;
					   @bit[19:16]=0x1,have 2 mem chip
					   @bit[15:12]=0x2,data width=32
					   @bit[11:8]=0x4,mem type =reserved
	str	r1, [r0, #DMC_MEMCONTROL]

	/*9.Set the MemConfig0 register. If there are two external memory chips, also set the MemConfig1 register.*/
	ldr	r1, =0x40c01333@bit[31:24]=0x40,chip base=0x40000000
					   @bit[11:8]=0x3,num of col addr=10
					   @bit[7:4]=0x3,num of row addr =15
					   @bit[3:0]=0x3,num of bank=8
	str	r1, [r0, #DMC_MEMCONFIG0]//need to be modified
	ldr	r1, =0x60c01333
	str	r1, [r0, #DMC_MEMCONFIG1]//need to be modified

#ifdef CONFIG_IV_SIZE
	ldr	r1, =(0x80000000 | CONFIG_IV_SIZE)
#else
	ldr	r1, =0x08
#endif
	str	r1, [r0, #DMC_IVCONTROL]

	/*10.Set the PrechConfig and PwrdnConfig registers.*/
	ldr	r1, =0xff000000
	str	r1, [r0, #DMC_PRECHCONFIG]

	/*11.Set the TimingAref, TimingRow, TimingData and TimingPower registers according to memory AC parame-ters.*/
	ldr	r1, =0x000000BB	
	str	r1, [r0, #DMC_TIMINGAREF] @TimingAref

#ifdef MCLK_330
	ldr	r1, =0x3545548d
	str	r1, [r0, #DMC_TIMINGROW]
	ldr	r1, =0x45430506
	str	r1, [r0, #DMC_TIMINGDATA]
	ldr	r1, =0x46000A3c
	str	r1, [r0, #DMC_TIMINGPOWER]
#endif
#ifdef MCLK_400
	#if 1
	/*TimingRow*/
	ldr r1,[r0, #DMC_TIMINGROW]
	bic r1,r1,#0x0000f000 @tRCD
	orr r1,r1,#0x00006000 @bit[15:12]=0x6,tRCD.THE TIME FROM SENDING ROW ACTIVE COMMAND TO SEND READ/WRITE COMMAND
		

	bic r1,r1,#0xFF000000 @tRFC//need to be modified
	orr r1,r1,#0x69000000 @bit[31:24]=0x69,tRFC;Auto refresh command period

	bic r1,r1,#0x00f00000 @tRRD
	orr r1,r1,#0x00400000 @bit[23:20]=0x4
	
	bic r1,r1,#0x000f0000  @tRP
	orr r1,r1,#0x00060000  @bit[19:16]=0x6,tRP.THE TIME FROM SEND PRECHARGE COMMAND TO OPEN AN NEW ROW

	
	bic r1,r1,#0x0000003f  @tRAS
	orr r1,r1,#0x0000000f  @bit[5:0]=0xf,tRAS;THE TIME FROM ROW ACTIVE TO SEND PRECHARGE COMMAND
							

	bic r1,r1,#0x00000FC0  @tRC
	orr r1,r1,#0x00000540  @bit[11:6]=0x15

	str	r1, [r0, #DMC_TIMINGROW] @TimingRow
	#endif
	
	/*TimingData*/
    ldr	r1, [r0, #DMC_TIMINGDATA]  
	bic r1,r1,#0x0000000f @rl
	orr r1,r1,#0x00000006 @bit[3:0]=0x6 clk


	bic r1,r1,#0x00000f00 @wl
	orr r1,r1,#0x00000500 @bit[11:8]=0x5 clk;write data lattence in clk

	bic r1,r1,#0xf0000000 @t_WTR
	orr r1,r1,#0x40000000 @bit[31:28]=0x4 clk;internal Write to Read command delay, in cycles

	bic r1,r1,#0x0f000000 @t_wr
	orr r1,r1,#0x06000000 @bit[27:24]=0x6 clk;Write recovery time, in cycles

	
	bic r1,r1,#0x00f00000 @t_rtp
	orr r1,r1,#0x00400000 @bit[23:20]=0x4 clk;Internal Read to Precharge command delay, in cycles

	bic r1,r1,#0x000F0000 @CAS
	orr r1,r1,#0x00000000 @bit[19:16]=0x0 clk;CAS Latency in cycles
	str	r1, [r0, #DMC_TIMINGDATA] @TimingData
	
	
	ldr	r1, =0x52000a3c
	str	r1, [r0, #DMC_TIMINGPOWER] @TimingPower
	
#endif

	/* chip 0 */
	ldr	r1, =0x07000000 @bit[27:24]=0x7,cmd_type=NOP
	str	r1, [r0, #DMC_DIRECTCMD]

	mov	r2, #0x100000
2:	subs	r2, r2, #1
	bne	2b
	ldr	r1, =0x00020000 @bit[27:24]=0x0,cmd_type=MRS
						/*MRS2*/
						@M[5:3]=0x3,CWL
	str	r1, [r0, #DMC_DIRECTCMD]
	ldr	r1, =0x00030000 @bit[27:24]=0x0,cmd_type=MRS
						@MRS3
	str	r1, [r0, #DMC_DIRECTCMD]
	ldr	r1, =0x00010002 @bit[27:24]=0x0,cmd_type=MRS
						/*MRS1*/
						@M[18:16]=0x1,means now we config MRS1
	str	r1, [r0, #DMC_DIRECTCMD]
	ldr	r1, =0x00000328 @bit[27:24]=0x0,cmd_type=MRS
						
						/*MRS0*/
						@M[18:16]=0x0,means now we config MRS0
						@M[15:13]=0x0,must be 0
						@M12=0
						@M[11:9]=0x1,write recovery=5
						@M8=1,DLL RESET
						@M[6:4]=0x2,CAS=6
						@M3=1,read burst type=interleaved
						@M[1:0]=0x00,burst length=8
	str	r1, [r0, #DMC_DIRECTCMD]

	mov	r2, #0x100000
3:	subs	r2, r2, #1
	bne	3b

	ldr	r1, =0x0a000000
	str	r1, [r0, #DMC_DIRECTCMD]

	mov	r2, #0x100000
4:	subs	r2, r2, #1
	bne	4b

#if 1
	/* chip 1 */
	ldr	r1, =0x07100000
	str	r1, [r0, #DMC_DIRECTCMD]

	mov	r2, #0x100000
5:	subs	r2, r2, #1
	bne	5b

	ldr	r1, =0x00120000
	str	r1, [r0, #DMC_DIRECTCMD]
	ldr	r1, =0x00130000
	str	r1, [r0, #DMC_DIRECTCMD]
	ldr	r1, =0x00110002
	str	r1, [r0, #DMC_DIRECTCMD]
	ldr	r1, =0x00100328
	str	r1, [r0, #DMC_DIRECTCMD]

	mov	r2, #0x100000
6:	subs	r2, r2, #1
	bne	6b

	ldr	r1, =0x0a100000
	str	r1, [r0, #DMC_DIRECTCMD]

	mov	r2, #0x100000
7:	subs	r2, r2, #1
	bne	7b
#endif

	ldr	r1, =0xe000008e
	str	r1, [r0, #DMC_PHYCONTROL1]
	ldr	r1, =0xe0000086
	str	r1, [r0, #DMC_PHYCONTROL1]

	mov	r2, #0x100000
8:	subs	r2, r2, #1
	bne	8b


/*****************************************************************/
/*DREX1***********************************************************/
/*****************************************************************/

	ldr	r0, =APB_DMC_1_BASE

	ldr	r1, =0xe0000086
	str	r1, [r0, #DMC_PHYCONTROL1]

	ldr	r1, =0xE3854C03
	str	r1, [r0, #DMC_PHYZQCONTROL]

	mov	r2, #0x100000
1:	subs	r2, r2, #1
	bne	1b

	ldr	r1, =0xe000008e
	str	r1, [r0, #DMC_PHYCONTROL1]
	ldr	r1, =0xe0000086
	str	r1, [r0, #DMC_PHYCONTROL1]

	ldr	r1, =0x71101008
	str	r1, [r0, #DMC_PHYCONTROL0]
	ldr	r1, =0x7110100A
	str	r1, [r0, #DMC_PHYCONTROL0]

	ldr	r1, =0xe0000086
	str	r1, [r0, #DMC_PHYCONTROL1]
	ldr	r1, =0x7110100B
	str	r1, [r0, #DMC_PHYCONTROL0]

	ldr	r1, =0x00000000
	str	r1, [r0, #DMC_PHYCONTROL2]

	ldr	r1, =0x0FFF301A
	str	r1, [r0, #DMC_CONCONTROL]
	ldr	r1, =0x00312640
	str	r1, [r0, #DMC_MEMCONTROL]

	ldr	r1, =0x40c01333			@Interleaved?//need to be modified
	str	r1, [r0, #DMC_MEMCONFIG0]
	ldr	r1, =0x60c01333          //need to be modified
	str	r1, [r0, #DMC_MEMCONFIG1]

#ifdef CONFIG_IV_SIZE
	ldr	r1, =(0x80000000 | CONFIG_IV_SIZE)
#else
	ldr	r1, =0x08
#endif
	str	r1, [r0, #DMC_IVCONTROL]

	ldr	r1, =0xff000000
	str	r1, [r0, #DMC_PRECHCONFIG]

	ldr	r1, =0x000000BB
	str	r1, [r0, #DMC_TIMINGAREF] @TimingAref

#ifdef MCLK_330
	ldr	r1, =0x3545548d
	str	r1, [r0, #DMC_TIMINGROW]
	ldr	r1, =0x45430506
	str	r1, [r0, #DMC_TIMINGDATA]
	ldr	r1, =0x46000A3c
	str	r1, [r0, #DMC_TIMINGPOWER]
#endif
#ifdef MCLK_400
	ldr	r1, =0x6946654f//need to be modified
	str	r1, [r0, #DMC_TIMINGROW] @TimingRow
	ldr	r1, =0x46400506	
	str	r1, [r0, #DMC_TIMINGDATA] @TimingData
	ldr	r1, =0x52000a3c
	str	r1, [r0, #DMC_TIMINGPOWER] @TimingPower
#endif

	/* chip 0 */
	ldr	r1, =0x07000000
	str	r1, [r0, #DMC_DIRECTCMD]

	mov	r2, #0x100000
2:	subs	r2, r2, #1
	bne	2b

	ldr	r1, =0x00020000
	str	r1, [r0, #DMC_DIRECTCMD]
	ldr	r1, =0x00030000
	str	r1, [r0, #DMC_DIRECTCMD]
	ldr	r1, =0x00010002
	str	r1, [r0, #DMC_DIRECTCMD]
	ldr	r1, =0x00000328 @bit[27:24]=0x0,cmd_type=MRS
						
						/*MRS0*/
						@M[18:16]=0x0,means now we config MRS0
						@M12=0
						@M[11:9]=0x2,write recovery=6
						@M8=1,DLL RESET
						@M[6:4]=0x2,CAS
						@M3=1,read burst type =interleaved
						@M[1:0]=0x00,burst length=8
	str	r1, [r0, #DMC_DIRECTCMD]

	mov	r2, #0x100000
3:	subs	r2, r2, #1
	bne	3b

	ldr	r1, =0x0a000000
	str	r1, [r0, #DMC_DIRECTCMD]

	mov	r2, #0x100000
4:	subs	r2, r2, #1
	bne	4b

#if 1
	/* chip 1 */
	ldr	r1, =0x07100000
	str	r1, [r0, #DMC_DIRECTCMD]

	mov	r2, #0x100000
5:	subs	r2, r2, #1
	bne	5b

	ldr	r1, =0x00120000
	str	r1, [r0, #DMC_DIRECTCMD]
	ldr	r1, =0x00130000
	str	r1, [r0, #DMC_DIRECTCMD]
	ldr	r1, =0x00110002
	str	r1, [r0, #DMC_DIRECTCMD]
	ldr	r1, =0x00100328
	str	r1, [r0, #DMC_DIRECTCMD]

	mov	r2, #0x100000
6:	subs	r2, r2, #1
	bne	6b

	ldr	r1, =0x0a100000
	str	r1, [r0, #DMC_DIRECTCMD]

	mov	r2, #0x100000
7:	subs	r2, r2, #1
	bne	7b
#endif

	ldr	r1, =0xe000008e
	str	r1, [r0, #DMC_PHYCONTROL1]
	ldr	r1, =0xe0000086
	str	r1, [r0, #DMC_PHYCONTROL1]

	mov	r2, #0x100000
8:	subs	r2, r2, #1
	bne	8b


/*****************************************************************/
/*Finalize********************************************************/
/*****************************************************************/

	ldr	r0, =APB_DMC_0_BASE
	ldr	r1, =0x0FFF303A
	str	r1, [r0, #DMC_CONCONTROL]

	ldr	r0, =APB_DMC_1_BASE
	ldr	r1, =0x0FFF303A
	str	r1, [r0, #DMC_CONCONTROL]

	mov	pc, lr

