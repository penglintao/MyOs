%define BOOTSEG 0x07c0
%define INITSEG 0x9000
%define SYSSEG 0x1000
%define SYSSEG 0x3000
%define ENDSEG SYSSEG + SYSSIZE
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

	mov ax, SYSSEG
	mov es, ax
	call read_it
	jmp $

read_it:
	mov ax, es
	test ax, 0xfff
die:
	jne die ;测试es段是不是64k边界处，如果不是就die
	xor bx, bx
rp_read:
	mov ax, es;ex会增加的，后面
	cmp ax, ENDSEG
	jb ok1_read;ax < ENDSEG
	ret
ok1_read:
;算出下次磁盘操作需要读取的扇区数目
	mov ax, sectors;取出每磁道的扇区数
	sub ax, sread; 当前磁道已经读出的扇区
	mov cx, ax
	shl cx, 9	;*512,转换成字节
	add cx, bx;数据缓冲区buffer偏移
	jnc ok2_read
	je ok2_read
	xor ax, ax
	sub ax, bx
	shr ax, 9
ok2_read:
;此次磁盘操作后需要切换磁头，或者磁道
	call read_track
	mov cx, ax;上次操作读了多少个扇区
	add ax, sread ;加上历史存数
	cmp ax, sectors;是不是读满了一个磁道了
	jne ok3_read ;如果还没读满，继续去读取该磁道的数据
	mov ax, 1
;磁盘读数据原理就是磁头切换优先，因为磁头切换很快，比磁道切换快很多 
	sub ax, head;如果是磁头0了,就去磁头1读取数据，磁头0和1上的每条磁道都要扫描一次
	jne ok4_read
	inc track;如果磁头0和磁头1的磁道都读过一次，就读取下一磁道
ok4_read:
	mov head, ax
	xor ax, ax
ok3_read:
;判读是否读完一个段
	mov read, ax
	shl cx, 9;cx表示前面一次磁盘操作读了多少个扇区
	add bx, cx
	jnc rp_read; bx<0x10000,bx为16位,溢出就置c位了
	mov es, ax
	add ax, 0x1000
	mov ex, ax;段基地址+0x1000
	xor bx, bx
	jmp rp_read 
	
;每次读取一个磁道的数据，al存储该磁道还需读取扇区的个数
read_track:
	push ax
	push bx
	push cx
	push dx
	mov dx, track ;读出当前磁道号
	mov cx, sread; 已经读了几个扇区
	inc cx ;cl表示下一个要读的扇区号, ch表示当前磁道号
	mov ch, dl;填充当前磁道号
	mov dx, head;读出当前磁头号
	mov dh, dl;把磁头号填充进去	
	mov dl, 8;驱动器号，这里是硬盘
	mov ah, 2
	int 0x13
	jc bad_rt
	pop dx
	pop cx
	pop bx	
	pop ax
	ret

bad_rt:
	mov ax, 0
	mov dx, 0
	int 0x13
	pop dx
	pop cx
	pop bx	
	pop ax
	jmp read_track

sectors dw 0
msg:
	db 13, 10 ; \r\n
	db "Loading SYStem ..."
	db 13, 10, 13, 10 ;\r\n\r\n

head dw 0
sread dw 1 + SETUPLEN
track dw 0




;times 510-($-$$) db 0 ; Fill the remain space,make the 2 binary file 512 byt    es
;dw 0xaa55 ; end sign
;软驱一定要加最后这个，要不然找不到启动设备
