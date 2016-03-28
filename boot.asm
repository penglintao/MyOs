%define BOOTSEG 0x07c0
%define INITSEG 0x9000
%define SETUPLEN 4 ;number of sectors


mov ax, BOOTSEG
mov ds, ax
mov ax, INITSEG
mov es, ax
mov cx, 256
xor si, si
xor di, di
rep
movsw
jmp INITSEG:go

go: mov ax, cs
	mov ds, ax
	mov es, ax
;create stack
	mov ss, ax
	mov sp, 0xff00

;load setup
load_setup:

	mov dx, 0x0080; drive 0, head0 驱动器0表示从软驱加载 硬盘驱动dl位七置位
	mov cx, 0x0002; sector 2, track 0
	mov bx, 0x0200; address = 512
	mov ax, 0x0200 + SETUPLEN;4 sectors
	int 0x13 ;read 2-5 sector to address 0x90000 + 200
	jnc ok_load_setup
	mov dx, 0x0000
	mov ax, 0x0000
	int 0x13
	jmp load_setup
ok_load_setup:
;读取磁盘的参数,每条磁道的扇区数
	mov dl, 0x80 ; 00 表示软驱
	mov ax, 0x0800
	int 0x13
	mov ch, 0x00
	mov [sectors], cx
	mov ax, INITSEG
	mov es, ax

	mov ah, 0x03
	xor bh, bh
	int 0x10
;将msg写入显示在屏幕上	
	mov cx, 24;24 chars 
	mov bx, 0x0007
	mov bp, msg
	mov ax, 0x1301	
	int 0x10
	jmp $

sectors dw 0
msg:
	db 13, 10 ; \r\n
	db "Loading SYStem ..."
	db 13, 10, 13, 10 ;\r\n\r\n


;times 510-($-$$) db 0 ; Fill the remain space,make the 2 binary file 512 byt    es
;dw 0xaa55 ; end sign
;软驱一定要加最后这个，要不然找不到启动设备
