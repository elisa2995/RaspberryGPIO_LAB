@ buttonLED32.s
@ Switch on a LED connected to pin 26 as soon as a button
@ connected to pin 17 is pressed. When the button is unpressed 
@ the LED is switched off.

@ Define my Raspberry Pi
        .cpu    cortex-a53
        .fpu    neon-fp-armv8
        .syntax unified         	@ modern syntax

@ Constants for assembler
        .equ    PERIPH,0x3f000000   	@ RPi 2 & 3 peripherals
        .equ    GPIO_OFFSET,0x200000  	@ start of GPIO device

@ The following are defined in /usr/include/asm-generic/fcntl.h:
@ Note that the values are specified in octal.
        .equ    O_RDWR,00000002   		@ open for read/write
        .equ    O_DSYNC,00010000
        .equ    __O_SYNC,04000000
        .equ    O_SYNC,__O_SYNC|O_DSYNC

@ The following are defined in /usr/include/asm-generic/mman-common.h:
        .equ    PROT_READ,0x1   		@ page can be read
        .equ    PROT_WRITE,0x2  		@ page can be written
        .equ    MAP_SHARED,0x01 		@ share changes

@ The following are defined by me:
        .equ    O_FLAGS,O_RDWR|O_SYNC 	@ open file flags
        .equ    PROT_RDWR,PROT_READ|PROT_WRITE
        .equ    NO_PREF,0
        .equ    PAGE_SIZE,4096  		@ Raspbian memory page
        .equ    INPUT,0         		@ use pin for input
        .equ    OUTPUT,1        		@ use pin for ouput
        .equ    PIN_BTN,17        		@ button pin
	.equ    PIN_LED,26        		@ LED pin (output)

@ Constant program data
        .section .rodata
        .align  2
device:
        .asciz  "/dev/gpiomem"
devErr:
        .asciz  "Cannot open /dev/gpiomem\n"
memErr:
        .asciz  "Cannot map /dev/gpiomem\n"
message:
	.asciz	"Counter: %i \n"

@ The program
        .text
        .align  2
        .global main
        .type   main, %function
main:
	push	{r4, r5, r6, r7, r8, lr}

@ Open /dev/gpiomem for read/write and syncing        
        ldr     r0, deviceAddr  		@ address of /dev/gpiomem
        ldr     r1, openMode    		@ flags for accessing device
        bl      open
        cmp     r0, -1          		@ check for error
        bne     gpiomemOK       		@ no error, continue
        ldr     r0, devErrAddr  		@ error, tell user
        bl      printf
        b       allDone         		@ and end program
        
gpiomemOK:      
        mov     r4, r0          		@ use r4 for file descriptor

@ Map the GPIO registers to a main memory location so we can access them
        ldr	r5, gpio			@ address of the GPIO
	push	{r4, r5}
        mov     r0, #NO_PREF     		@ let kernel pick memory
        mov     r1, #PAGE_SIZE   		@ get 1 page of memory
        mov     r2, #PROT_RDWR   		@ read/write this memory
        mov     r3, #MAP_SHARED  		@ share with other processes
        bl      mmap
	pop	{r4, r5}
        cmp     r0, -1          		@ check for error
        bne     mmapOK          		@ no error, continue
        ldr     r0, memErrAddr 			@ error, tell user
        bl      printf
        b       closeDev        		@ and close /dev/gpiomem
        
@ All OK, configure button pin
mmapOK:        
        mov     r5, r0          		@ use r5 for programming memory address
        mov     r0, r5          		@ programming memory
        mov     r1, #PIN_BTN       		@ button pin
        mov     r2, #INPUT     			@ it's an input
        bl      gpioPinFSelect  		@ select function
        
        mov     r0, r5          		@ programming memory
	mov     r1, #PIN_LED       		@ LED pin
	mov     r2, #OUTPUT      		@ it's an output
        bl      gpioPinFSelect  		@ select function

@ Initialization of the current and old level of the pin	
	mov 	r8, #0				@ r8= current level of the pin 
	mov 	r7, #0				@ r7= old level of the pin
	


readAgain:
	ldr	r0, =1				@ MODIFY THIS VALUE TO SEE THE EFFECT THE BOUNCE
	bl	usleep
		
	mov 	r7, r8				@ save previous level of the pin in r7
	
	mov 	r0, r5				@ GPIO programming memory
	mov 	r1, PIN_BTN			@ pin to read
	bl 	gpioPinRead	

@ If a rising edge is detected, the LED is switched on.
@ Rising edge(transition from 0 to 1): _|¯
@ If a falling edge is detected, the LED is switched off.
@ Falling edge(transition from 1 to 0):¯|_
	mov 	r8, r0				@ r8=new level of the pin
	
	cmp	r8, r7
	beq	readAgain			@ if the level hasn't change 
	
	cmp	r8, #1		 			
	beq	switchOn			@ r8=1 rising edge
	bne	switchOff			@ r8=0 falling edge
	

switchOn:
	mov     r0, r5          		@ GPIO programming memory
	mov     r1, #PIN_LED			@ LED pin
	bl      gpioPinClr			@ pull down the pin
	b 	readAgain

switchOff:
	mov     r0, r5          		@ GPIO programming memory
	mov     r1, #PIN_LED			@ LED pin
	bl      gpioPinSet			@ pull up the pin
	b 	readAgain		 

unmap:        
        mov     r0, r5          		@ memory to unmap
        mov     r1, PAGE_SIZE   		@ amount we mapped
        bl      munmap          		@ unmap it

closeDev:
        mov     r0, r4          		@ /dev/gpiomem file descriptor
        bl      close           		@ close the file

allDone:        
        mov     r0, 0           		@ return 0;
	pop	{r4, r5, r6, r7, r8, lr}
        bx      lr              		@ return
        
        .align  2

@ addresses of messages
deviceAddr:
        .word   device
openMode:
        .word   O_FLAGS
gpio:
        .word   PERIPH+GPIO_OFFSET
devErrAddr:
        .word   devErr
memErrAddr:
        .word   memErr
messageAddr:
	.word	message

