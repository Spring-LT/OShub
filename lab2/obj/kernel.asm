
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid # hartid当前运行的线程ID
ffffffffc0200000:	00005297          	auipc	t0,0x5
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0) # 保存当前运行的线程ID
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0205000 <boot_hartid>
    la t0, boot_dtb # 设备树blob的物理地址
ffffffffc020000c:	00005297          	auipc	t0,0x5
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0205008 <boot_dtb>
    sd a1, 0(t0) # 保存设备树blob的物理地址到$a1
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39) # 存储了根页表的虚拟地址
ffffffffc0200018:	c02042b7          	lui	t0,0xc0204
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12 # 去除页内偏移
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60 # 8 表示 Sv39 模式
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1 # 页表物理页号与模式位组合成完整的 satp 值
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0 # 写入 satp 寄存器，切换到新的页表
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma # 刷新 TLB，使新的页表生效
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop) # 设置栈指针为 bootstacktop，即栈的顶部
ffffffffc020003c:	c0204137          	lui	sp,0xc0204
    addi sp, sp, %lo(bootstacktop) # 栈指针加上页内偏移，指向栈的顶部
ffffffffc0200040:	00010113          	mv	sp,sp

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init) # 加载 kern_init 的高 20 位到 t0
ffffffffc0200044:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init) # 加载 kern_init 的低 12 位到 t0
ffffffffc0200048:	0dc28293          	addi	t0,t0,220 # ffffffffc02000dc <kern_init>
    jr t0 # 跳转到 t0 指向的地址，即 kern_init
ffffffffc020004c:	8282                	jr	t0

ffffffffc020004e <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc020004e:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[];
    cprintf("Special kernel symbols:\n");
ffffffffc0200050:	00001517          	auipc	a0,0x1
ffffffffc0200054:	61850513          	addi	a0,a0,1560 # ffffffffc0201668 <etext+0x2>
void print_kerninfo(void) {
ffffffffc0200058:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc020005a:	0f6000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005e:	00000597          	auipc	a1,0x0
ffffffffc0200062:	07e58593          	addi	a1,a1,126 # ffffffffc02000dc <kern_init>
ffffffffc0200066:	00001517          	auipc	a0,0x1
ffffffffc020006a:	62250513          	addi	a0,a0,1570 # ffffffffc0201688 <etext+0x22>
ffffffffc020006e:	0e2000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc0200072:	00001597          	auipc	a1,0x1
ffffffffc0200076:	5f458593          	addi	a1,a1,1524 # ffffffffc0201666 <etext>
ffffffffc020007a:	00001517          	auipc	a0,0x1
ffffffffc020007e:	62e50513          	addi	a0,a0,1582 # ffffffffc02016a8 <etext+0x42>
ffffffffc0200082:	0ce000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200086:	00005597          	auipc	a1,0x5
ffffffffc020008a:	f9258593          	addi	a1,a1,-110 # ffffffffc0205018 <free_area>
ffffffffc020008e:	00001517          	auipc	a0,0x1
ffffffffc0200092:	63a50513          	addi	a0,a0,1594 # ffffffffc02016c8 <etext+0x62>
ffffffffc0200096:	0ba000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc020009a:	00005597          	auipc	a1,0x5
ffffffffc020009e:	fde58593          	addi	a1,a1,-34 # ffffffffc0205078 <end>
ffffffffc02000a2:	00001517          	auipc	a0,0x1
ffffffffc02000a6:	64650513          	addi	a0,a0,1606 # ffffffffc02016e8 <etext+0x82>
ffffffffc02000aa:	0a6000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000ae:	00005597          	auipc	a1,0x5
ffffffffc02000b2:	3c958593          	addi	a1,a1,969 # ffffffffc0205477 <end+0x3ff>
ffffffffc02000b6:	00000797          	auipc	a5,0x0
ffffffffc02000ba:	02678793          	addi	a5,a5,38 # ffffffffc02000dc <kern_init>
ffffffffc02000be:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000c2:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02000c6:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000c8:	3ff5f593          	andi	a1,a1,1023
ffffffffc02000cc:	95be                	add	a1,a1,a5
ffffffffc02000ce:	85a9                	srai	a1,a1,0xa
ffffffffc02000d0:	00001517          	auipc	a0,0x1
ffffffffc02000d4:	63850513          	addi	a0,a0,1592 # ffffffffc0201708 <etext+0xa2>
}
ffffffffc02000d8:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000da:	a89d                	j	ffffffffc0200150 <cprintf>

ffffffffc02000dc <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000dc:	00005517          	auipc	a0,0x5
ffffffffc02000e0:	f3c50513          	addi	a0,a0,-196 # ffffffffc0205018 <free_area>
ffffffffc02000e4:	00005617          	auipc	a2,0x5
ffffffffc02000e8:	f9460613          	addi	a2,a2,-108 # ffffffffc0205078 <end>
int kern_init(void) {
ffffffffc02000ec:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ee:	8e09                	sub	a2,a2,a0
ffffffffc02000f0:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000f2:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f4:	560010ef          	jal	ra,ffffffffc0201654 <memset>
    dtb_init();
ffffffffc02000f8:	12c000ef          	jal	ra,ffffffffc0200224 <dtb_init>
    cons_init();  // init the console
ffffffffc02000fc:	11e000ef          	jal	ra,ffffffffc020021a <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc0200100:	00001517          	auipc	a0,0x1
ffffffffc0200104:	63850513          	addi	a0,a0,1592 # ffffffffc0201738 <etext+0xd2>
ffffffffc0200108:	07e000ef          	jal	ra,ffffffffc0200186 <cputs>

    print_kerninfo();
ffffffffc020010c:	f43ff0ef          	jal	ra,ffffffffc020004e <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc0200110:	6eb000ef          	jal	ra,ffffffffc0200ffa <pmm_init>

    /* do nothing */
    while (1)
ffffffffc0200114:	a001                	j	ffffffffc0200114 <kern_init+0x38>

ffffffffc0200116 <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc0200116:	1141                	addi	sp,sp,-16
ffffffffc0200118:	e022                	sd	s0,0(sp)
ffffffffc020011a:	e406                	sd	ra,8(sp)
ffffffffc020011c:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc020011e:	0fe000ef          	jal	ra,ffffffffc020021c <cons_putc>
    (*cnt) ++;
ffffffffc0200122:	401c                	lw	a5,0(s0)
}
ffffffffc0200124:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc0200126:	2785                	addiw	a5,a5,1
ffffffffc0200128:	c01c                	sw	a5,0(s0)
}
ffffffffc020012a:	6402                	ld	s0,0(sp)
ffffffffc020012c:	0141                	addi	sp,sp,16
ffffffffc020012e:	8082                	ret

ffffffffc0200130 <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc0200130:	1101                	addi	sp,sp,-32
ffffffffc0200132:	862a                	mv	a2,a0
ffffffffc0200134:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200136:	00000517          	auipc	a0,0x0
ffffffffc020013a:	fe050513          	addi	a0,a0,-32 # ffffffffc0200116 <cputch>
ffffffffc020013e:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc0200140:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc0200142:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200144:	0fa010ef          	jal	ra,ffffffffc020123e <vprintfmt>
    return cnt;
}
ffffffffc0200148:	60e2                	ld	ra,24(sp)
ffffffffc020014a:	4532                	lw	a0,12(sp)
ffffffffc020014c:	6105                	addi	sp,sp,32
ffffffffc020014e:	8082                	ret

ffffffffc0200150 <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc0200150:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc0200152:	02810313          	addi	t1,sp,40 # ffffffffc0204028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc0200156:	8e2a                	mv	t3,a0
ffffffffc0200158:	f42e                	sd	a1,40(sp)
ffffffffc020015a:	f832                	sd	a2,48(sp)
ffffffffc020015c:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020015e:	00000517          	auipc	a0,0x0
ffffffffc0200162:	fb850513          	addi	a0,a0,-72 # ffffffffc0200116 <cputch>
ffffffffc0200166:	004c                	addi	a1,sp,4
ffffffffc0200168:	869a                	mv	a3,t1
ffffffffc020016a:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc020016c:	ec06                	sd	ra,24(sp)
ffffffffc020016e:	e0ba                	sd	a4,64(sp)
ffffffffc0200170:	e4be                	sd	a5,72(sp)
ffffffffc0200172:	e8c2                	sd	a6,80(sp)
ffffffffc0200174:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc0200176:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc0200178:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020017a:	0c4010ef          	jal	ra,ffffffffc020123e <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc020017e:	60e2                	ld	ra,24(sp)
ffffffffc0200180:	4512                	lw	a0,4(sp)
ffffffffc0200182:	6125                	addi	sp,sp,96
ffffffffc0200184:	8082                	ret

ffffffffc0200186 <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc0200186:	1101                	addi	sp,sp,-32
ffffffffc0200188:	e822                	sd	s0,16(sp)
ffffffffc020018a:	ec06                	sd	ra,24(sp)
ffffffffc020018c:	e426                	sd	s1,8(sp)
ffffffffc020018e:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc0200190:	00054503          	lbu	a0,0(a0)
ffffffffc0200194:	c51d                	beqz	a0,ffffffffc02001c2 <cputs+0x3c>
ffffffffc0200196:	0405                	addi	s0,s0,1
ffffffffc0200198:	4485                	li	s1,1
ffffffffc020019a:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc020019c:	080000ef          	jal	ra,ffffffffc020021c <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc02001a0:	00044503          	lbu	a0,0(s0)
ffffffffc02001a4:	008487bb          	addw	a5,s1,s0
ffffffffc02001a8:	0405                	addi	s0,s0,1
ffffffffc02001aa:	f96d                	bnez	a0,ffffffffc020019c <cputs+0x16>
    (*cnt) ++;
ffffffffc02001ac:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc02001b0:	4529                	li	a0,10
ffffffffc02001b2:	06a000ef          	jal	ra,ffffffffc020021c <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc02001b6:	60e2                	ld	ra,24(sp)
ffffffffc02001b8:	8522                	mv	a0,s0
ffffffffc02001ba:	6442                	ld	s0,16(sp)
ffffffffc02001bc:	64a2                	ld	s1,8(sp)
ffffffffc02001be:	6105                	addi	sp,sp,32
ffffffffc02001c0:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc02001c2:	4405                	li	s0,1
ffffffffc02001c4:	b7f5                	j	ffffffffc02001b0 <cputs+0x2a>

ffffffffc02001c6 <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02001c6:	00005317          	auipc	t1,0x5
ffffffffc02001ca:	e6a30313          	addi	t1,t1,-406 # ffffffffc0205030 <is_panic>
ffffffffc02001ce:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02001d2:	715d                	addi	sp,sp,-80
ffffffffc02001d4:	ec06                	sd	ra,24(sp)
ffffffffc02001d6:	e822                	sd	s0,16(sp)
ffffffffc02001d8:	f436                	sd	a3,40(sp)
ffffffffc02001da:	f83a                	sd	a4,48(sp)
ffffffffc02001dc:	fc3e                	sd	a5,56(sp)
ffffffffc02001de:	e0c2                	sd	a6,64(sp)
ffffffffc02001e0:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02001e2:	000e0363          	beqz	t3,ffffffffc02001e8 <__panic+0x22>
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);

panic_dead:
    while (1) {
ffffffffc02001e6:	a001                	j	ffffffffc02001e6 <__panic+0x20>
    is_panic = 1;
ffffffffc02001e8:	4785                	li	a5,1
ffffffffc02001ea:	00f32023          	sw	a5,0(t1)
    va_start(ap, fmt);
ffffffffc02001ee:	8432                	mv	s0,a2
ffffffffc02001f0:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001f2:	862e                	mv	a2,a1
ffffffffc02001f4:	85aa                	mv	a1,a0
ffffffffc02001f6:	00001517          	auipc	a0,0x1
ffffffffc02001fa:	56250513          	addi	a0,a0,1378 # ffffffffc0201758 <etext+0xf2>
    va_start(ap, fmt);
ffffffffc02001fe:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc0200200:	f51ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    vcprintf(fmt, ap);
ffffffffc0200204:	65a2                	ld	a1,8(sp)
ffffffffc0200206:	8522                	mv	a0,s0
ffffffffc0200208:	f29ff0ef          	jal	ra,ffffffffc0200130 <vcprintf>
    cprintf("\n");
ffffffffc020020c:	00001517          	auipc	a0,0x1
ffffffffc0200210:	52450513          	addi	a0,a0,1316 # ffffffffc0201730 <etext+0xca>
ffffffffc0200214:	f3dff0ef          	jal	ra,ffffffffc0200150 <cprintf>
ffffffffc0200218:	b7f9                	j	ffffffffc02001e6 <__panic+0x20>

ffffffffc020021a <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc020021a:	8082                	ret

ffffffffc020021c <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc020021c:	0ff57513          	zext.b	a0,a0
ffffffffc0200220:	3a00106f          	j	ffffffffc02015c0 <sbi_console_putchar>

ffffffffc0200224 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200224:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200226:	00001517          	auipc	a0,0x1
ffffffffc020022a:	55250513          	addi	a0,a0,1362 # ffffffffc0201778 <etext+0x112>
void dtb_init(void) {
ffffffffc020022e:	fc86                	sd	ra,120(sp)
ffffffffc0200230:	f8a2                	sd	s0,112(sp)
ffffffffc0200232:	e8d2                	sd	s4,80(sp)
ffffffffc0200234:	f4a6                	sd	s1,104(sp)
ffffffffc0200236:	f0ca                	sd	s2,96(sp)
ffffffffc0200238:	ecce                	sd	s3,88(sp)
ffffffffc020023a:	e4d6                	sd	s5,72(sp)
ffffffffc020023c:	e0da                	sd	s6,64(sp)
ffffffffc020023e:	fc5e                	sd	s7,56(sp)
ffffffffc0200240:	f862                	sd	s8,48(sp)
ffffffffc0200242:	f466                	sd	s9,40(sp)
ffffffffc0200244:	f06a                	sd	s10,32(sp)
ffffffffc0200246:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc0200248:	f09ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc020024c:	00005597          	auipc	a1,0x5
ffffffffc0200250:	db45b583          	ld	a1,-588(a1) # ffffffffc0205000 <boot_hartid>
ffffffffc0200254:	00001517          	auipc	a0,0x1
ffffffffc0200258:	53450513          	addi	a0,a0,1332 # ffffffffc0201788 <etext+0x122>
ffffffffc020025c:	ef5ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc0200260:	00005417          	auipc	s0,0x5
ffffffffc0200264:	da840413          	addi	s0,s0,-600 # ffffffffc0205008 <boot_dtb>
ffffffffc0200268:	600c                	ld	a1,0(s0)
ffffffffc020026a:	00001517          	auipc	a0,0x1
ffffffffc020026e:	52e50513          	addi	a0,a0,1326 # ffffffffc0201798 <etext+0x132>
ffffffffc0200272:	edfff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200276:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc020027a:	00001517          	auipc	a0,0x1
ffffffffc020027e:	53650513          	addi	a0,a0,1334 # ffffffffc02017b0 <etext+0x14a>
    if (boot_dtb == 0) {
ffffffffc0200282:	120a0463          	beqz	s4,ffffffffc02003aa <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc0200286:	57f5                	li	a5,-3
ffffffffc0200288:	07fa                	slli	a5,a5,0x1e
ffffffffc020028a:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc020028e:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200290:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200294:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200296:	0087d59b          	srliw	a1,a5,0x8
ffffffffc020029a:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020029e:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002a2:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a6:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002aa:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002ac:	8ec9                	or	a3,a3,a0
ffffffffc02002ae:	0087979b          	slliw	a5,a5,0x8
ffffffffc02002b2:	1b7d                	addi	s6,s6,-1
ffffffffc02002b4:	0167f7b3          	and	a5,a5,s6
ffffffffc02002b8:	8dd5                	or	a1,a1,a3
ffffffffc02002ba:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc02002bc:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002c0:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc02002c2:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfedae75>
ffffffffc02002c6:	10f59163          	bne	a1,a5,ffffffffc02003c8 <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc02002ca:	471c                	lw	a5,8(a4)
ffffffffc02002cc:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc02002ce:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002d0:	0087d59b          	srliw	a1,a5,0x8
ffffffffc02002d4:	0086d51b          	srliw	a0,a3,0x8
ffffffffc02002d8:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002dc:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e0:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e4:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e8:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002ec:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002f0:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f4:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002f8:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002fa:	01146433          	or	s0,s0,a7
ffffffffc02002fe:	0086969b          	slliw	a3,a3,0x8
ffffffffc0200302:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200306:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200308:	0087979b          	slliw	a5,a5,0x8
ffffffffc020030c:	8c49                	or	s0,s0,a0
ffffffffc020030e:	0166f6b3          	and	a3,a3,s6
ffffffffc0200312:	00ca6a33          	or	s4,s4,a2
ffffffffc0200316:	0167f7b3          	and	a5,a5,s6
ffffffffc020031a:	8c55                	or	s0,s0,a3
ffffffffc020031c:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200320:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200322:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200324:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200326:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020032a:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020032c:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020032e:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc0200332:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200334:	00001917          	auipc	s2,0x1
ffffffffc0200338:	4cc90913          	addi	s2,s2,1228 # ffffffffc0201800 <etext+0x19a>
ffffffffc020033c:	49bd                	li	s3,15
        switch (token) {
ffffffffc020033e:	4d91                	li	s11,4
ffffffffc0200340:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200342:	00001497          	auipc	s1,0x1
ffffffffc0200346:	4b648493          	addi	s1,s1,1206 # ffffffffc02017f8 <etext+0x192>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc020034a:	000a2703          	lw	a4,0(s4)
ffffffffc020034e:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200352:	0087569b          	srliw	a3,a4,0x8
ffffffffc0200356:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020035a:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020035e:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200362:	0107571b          	srliw	a4,a4,0x10
ffffffffc0200366:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200368:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020036c:	0087171b          	slliw	a4,a4,0x8
ffffffffc0200370:	8fd5                	or	a5,a5,a3
ffffffffc0200372:	00eb7733          	and	a4,s6,a4
ffffffffc0200376:	8fd9                	or	a5,a5,a4
ffffffffc0200378:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc020037a:	09778c63          	beq	a5,s7,ffffffffc0200412 <dtb_init+0x1ee>
ffffffffc020037e:	00fbea63          	bltu	s7,a5,ffffffffc0200392 <dtb_init+0x16e>
ffffffffc0200382:	07a78663          	beq	a5,s10,ffffffffc02003ee <dtb_init+0x1ca>
ffffffffc0200386:	4709                	li	a4,2
ffffffffc0200388:	00e79763          	bne	a5,a4,ffffffffc0200396 <dtb_init+0x172>
ffffffffc020038c:	4c81                	li	s9,0
ffffffffc020038e:	8a56                	mv	s4,s5
ffffffffc0200390:	bf6d                	j	ffffffffc020034a <dtb_init+0x126>
ffffffffc0200392:	ffb78ee3          	beq	a5,s11,ffffffffc020038e <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc0200396:	00001517          	auipc	a0,0x1
ffffffffc020039a:	4e250513          	addi	a0,a0,1250 # ffffffffc0201878 <etext+0x212>
ffffffffc020039e:	db3ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc02003a2:	00001517          	auipc	a0,0x1
ffffffffc02003a6:	50e50513          	addi	a0,a0,1294 # ffffffffc02018b0 <etext+0x24a>
}
ffffffffc02003aa:	7446                	ld	s0,112(sp)
ffffffffc02003ac:	70e6                	ld	ra,120(sp)
ffffffffc02003ae:	74a6                	ld	s1,104(sp)
ffffffffc02003b0:	7906                	ld	s2,96(sp)
ffffffffc02003b2:	69e6                	ld	s3,88(sp)
ffffffffc02003b4:	6a46                	ld	s4,80(sp)
ffffffffc02003b6:	6aa6                	ld	s5,72(sp)
ffffffffc02003b8:	6b06                	ld	s6,64(sp)
ffffffffc02003ba:	7be2                	ld	s7,56(sp)
ffffffffc02003bc:	7c42                	ld	s8,48(sp)
ffffffffc02003be:	7ca2                	ld	s9,40(sp)
ffffffffc02003c0:	7d02                	ld	s10,32(sp)
ffffffffc02003c2:	6de2                	ld	s11,24(sp)
ffffffffc02003c4:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc02003c6:	b369                	j	ffffffffc0200150 <cprintf>
}
ffffffffc02003c8:	7446                	ld	s0,112(sp)
ffffffffc02003ca:	70e6                	ld	ra,120(sp)
ffffffffc02003cc:	74a6                	ld	s1,104(sp)
ffffffffc02003ce:	7906                	ld	s2,96(sp)
ffffffffc02003d0:	69e6                	ld	s3,88(sp)
ffffffffc02003d2:	6a46                	ld	s4,80(sp)
ffffffffc02003d4:	6aa6                	ld	s5,72(sp)
ffffffffc02003d6:	6b06                	ld	s6,64(sp)
ffffffffc02003d8:	7be2                	ld	s7,56(sp)
ffffffffc02003da:	7c42                	ld	s8,48(sp)
ffffffffc02003dc:	7ca2                	ld	s9,40(sp)
ffffffffc02003de:	7d02                	ld	s10,32(sp)
ffffffffc02003e0:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003e2:	00001517          	auipc	a0,0x1
ffffffffc02003e6:	3ee50513          	addi	a0,a0,1006 # ffffffffc02017d0 <etext+0x16a>
}
ffffffffc02003ea:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003ec:	b395                	j	ffffffffc0200150 <cprintf>
                int name_len = strlen(name);
ffffffffc02003ee:	8556                	mv	a0,s5
ffffffffc02003f0:	1ea010ef          	jal	ra,ffffffffc02015da <strlen>
ffffffffc02003f4:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f6:	4619                	li	a2,6
ffffffffc02003f8:	85a6                	mv	a1,s1
ffffffffc02003fa:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003fc:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003fe:	230010ef          	jal	ra,ffffffffc020162e <strncmp>
ffffffffc0200402:	e111                	bnez	a0,ffffffffc0200406 <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc0200404:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc0200406:	0a91                	addi	s5,s5,4
ffffffffc0200408:	9ad2                	add	s5,s5,s4
ffffffffc020040a:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc020040e:	8a56                	mv	s4,s5
ffffffffc0200410:	bf2d                	j	ffffffffc020034a <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200412:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200416:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020041a:	0087d71b          	srliw	a4,a5,0x8
ffffffffc020041e:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200422:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200426:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020042a:	0107d79b          	srliw	a5,a5,0x10
ffffffffc020042e:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200432:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200436:	0087979b          	slliw	a5,a5,0x8
ffffffffc020043a:	00eaeab3          	or	s5,s5,a4
ffffffffc020043e:	00fb77b3          	and	a5,s6,a5
ffffffffc0200442:	00faeab3          	or	s5,s5,a5
ffffffffc0200446:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200448:	000c9c63          	bnez	s9,ffffffffc0200460 <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc020044c:	1a82                	slli	s5,s5,0x20
ffffffffc020044e:	00368793          	addi	a5,a3,3
ffffffffc0200452:	020ada93          	srli	s5,s5,0x20
ffffffffc0200456:	9abe                	add	s5,s5,a5
ffffffffc0200458:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc020045c:	8a56                	mv	s4,s5
ffffffffc020045e:	b5f5                	j	ffffffffc020034a <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200460:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200464:	85ca                	mv	a1,s2
ffffffffc0200466:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200468:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020046c:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200470:	0187971b          	slliw	a4,a5,0x18
ffffffffc0200474:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200478:	0107d79b          	srliw	a5,a5,0x10
ffffffffc020047c:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020047e:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200482:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200486:	8d59                	or	a0,a0,a4
ffffffffc0200488:	00fb77b3          	and	a5,s6,a5
ffffffffc020048c:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc020048e:	1502                	slli	a0,a0,0x20
ffffffffc0200490:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200492:	9522                	add	a0,a0,s0
ffffffffc0200494:	17c010ef          	jal	ra,ffffffffc0201610 <strcmp>
ffffffffc0200498:	66a2                	ld	a3,8(sp)
ffffffffc020049a:	f94d                	bnez	a0,ffffffffc020044c <dtb_init+0x228>
ffffffffc020049c:	fb59f8e3          	bgeu	s3,s5,ffffffffc020044c <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc02004a0:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004a4:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc02004a8:	00001517          	auipc	a0,0x1
ffffffffc02004ac:	36050513          	addi	a0,a0,864 # ffffffffc0201808 <etext+0x1a2>
           fdt32_to_cpu(x >> 32);
ffffffffc02004b0:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004b4:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc02004b8:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004bc:	0187de1b          	srliw	t3,a5,0x18
ffffffffc02004c0:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c4:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004c8:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004cc:	0187d693          	srli	a3,a5,0x18
ffffffffc02004d0:	01861f1b          	slliw	t5,a2,0x18
ffffffffc02004d4:	0087579b          	srliw	a5,a4,0x8
ffffffffc02004d8:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004dc:	0106561b          	srliw	a2,a2,0x10
ffffffffc02004e0:	010f6f33          	or	t5,t5,a6
ffffffffc02004e4:	0187529b          	srliw	t0,a4,0x18
ffffffffc02004e8:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004ec:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004f0:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f4:	0186f6b3          	and	a3,a3,s8
ffffffffc02004f8:	01859e1b          	slliw	t3,a1,0x18
ffffffffc02004fc:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200500:	0107581b          	srliw	a6,a4,0x10
ffffffffc0200504:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200508:	8361                	srli	a4,a4,0x18
ffffffffc020050a:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020050e:	0105d59b          	srliw	a1,a1,0x10
ffffffffc0200512:	01e6e6b3          	or	a3,a3,t5
ffffffffc0200516:	00cb7633          	and	a2,s6,a2
ffffffffc020051a:	0088181b          	slliw	a6,a6,0x8
ffffffffc020051e:	0085959b          	slliw	a1,a1,0x8
ffffffffc0200522:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200526:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020052a:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020052e:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200532:	0088989b          	slliw	a7,a7,0x8
ffffffffc0200536:	011b78b3          	and	a7,s6,a7
ffffffffc020053a:	005eeeb3          	or	t4,t4,t0
ffffffffc020053e:	00c6e733          	or	a4,a3,a2
ffffffffc0200542:	006c6c33          	or	s8,s8,t1
ffffffffc0200546:	010b76b3          	and	a3,s6,a6
ffffffffc020054a:	00bb7b33          	and	s6,s6,a1
ffffffffc020054e:	01d7e7b3          	or	a5,a5,t4
ffffffffc0200552:	016c6b33          	or	s6,s8,s6
ffffffffc0200556:	01146433          	or	s0,s0,a7
ffffffffc020055a:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc020055c:	1702                	slli	a4,a4,0x20
ffffffffc020055e:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200560:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc0200562:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200564:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc0200566:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc020056a:	0167eb33          	or	s6,a5,s6
ffffffffc020056e:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc0200570:	be1ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc0200574:	85a2                	mv	a1,s0
ffffffffc0200576:	00001517          	auipc	a0,0x1
ffffffffc020057a:	2b250513          	addi	a0,a0,690 # ffffffffc0201828 <etext+0x1c2>
ffffffffc020057e:	bd3ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc0200582:	014b5613          	srli	a2,s6,0x14
ffffffffc0200586:	85da                	mv	a1,s6
ffffffffc0200588:	00001517          	auipc	a0,0x1
ffffffffc020058c:	2b850513          	addi	a0,a0,696 # ffffffffc0201840 <etext+0x1da>
ffffffffc0200590:	bc1ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200594:	008b05b3          	add	a1,s6,s0
ffffffffc0200598:	15fd                	addi	a1,a1,-1
ffffffffc020059a:	00001517          	auipc	a0,0x1
ffffffffc020059e:	2c650513          	addi	a0,a0,710 # ffffffffc0201860 <etext+0x1fa>
ffffffffc02005a2:	bafff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("DTB init completed\n");
ffffffffc02005a6:	00001517          	auipc	a0,0x1
ffffffffc02005aa:	30a50513          	addi	a0,a0,778 # ffffffffc02018b0 <etext+0x24a>
        memory_base = mem_base;
ffffffffc02005ae:	00005797          	auipc	a5,0x5
ffffffffc02005b2:	a887b523          	sd	s0,-1398(a5) # ffffffffc0205038 <memory_base>
        memory_size = mem_size;
ffffffffc02005b6:	00005797          	auipc	a5,0x5
ffffffffc02005ba:	a967b523          	sd	s6,-1398(a5) # ffffffffc0205040 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005be:	b3f5                	j	ffffffffc02003aa <dtb_init+0x186>

ffffffffc02005c0 <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005c0:	00005517          	auipc	a0,0x5
ffffffffc02005c4:	a7853503          	ld	a0,-1416(a0) # ffffffffc0205038 <memory_base>
ffffffffc02005c8:	8082                	ret

ffffffffc02005ca <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005ca:	00005517          	auipc	a0,0x5
ffffffffc02005ce:	a7653503          	ld	a0,-1418(a0) # ffffffffc0205040 <memory_size>
ffffffffc02005d2:	8082                	ret

ffffffffc02005d4 <best_fit_init>:
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02005d4:	00005797          	auipc	a5,0x5
ffffffffc02005d8:	a4478793          	addi	a5,a5,-1468 # ffffffffc0205018 <free_area>
ffffffffc02005dc:	e79c                	sd	a5,8(a5)
ffffffffc02005de:	e39c                	sd	a5,0(a5)
#define nr_free (free_area.nr_free)

static void
best_fit_init(void) {
    list_init(&free_list);
    nr_free = 0;
ffffffffc02005e0:	0007a823          	sw	zero,16(a5)
}
ffffffffc02005e4:	8082                	ret

ffffffffc02005e6 <best_fit_nr_free_pages>:
}

static size_t
best_fit_nr_free_pages(void) {
    return nr_free;
}
ffffffffc02005e6:	00005517          	auipc	a0,0x5
ffffffffc02005ea:	a4256503          	lwu	a0,-1470(a0) # ffffffffc0205028 <free_area+0x10>
ffffffffc02005ee:	8082                	ret

ffffffffc02005f0 <best_fit_alloc_pages>:
    assert(n > 0);
ffffffffc02005f0:	cd49                	beqz	a0,ffffffffc020068a <best_fit_alloc_pages+0x9a>
    if (n > nr_free) {
ffffffffc02005f2:	00005617          	auipc	a2,0x5
ffffffffc02005f6:	a2660613          	addi	a2,a2,-1498 # ffffffffc0205018 <free_area>
ffffffffc02005fa:	01062803          	lw	a6,16(a2)
ffffffffc02005fe:	86aa                	mv	a3,a0
ffffffffc0200600:	02081793          	slli	a5,a6,0x20
ffffffffc0200604:	9381                	srli	a5,a5,0x20
ffffffffc0200606:	08a7e063          	bltu	a5,a0,ffffffffc0200686 <best_fit_alloc_pages+0x96>
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc020060a:	661c                	ld	a5,8(a2)
    size_t min_size = nr_free + 1;
ffffffffc020060c:	0018059b          	addiw	a1,a6,1
ffffffffc0200610:	1582                	slli	a1,a1,0x20
ffffffffc0200612:	9181                	srli	a1,a1,0x20
    struct Page *page = NULL;
ffffffffc0200614:	4501                	li	a0,0
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200616:	06c78763          	beq	a5,a2,ffffffffc0200684 <best_fit_alloc_pages+0x94>
        if (p->property >= n && p->property < min_size) {
ffffffffc020061a:	ff87e703          	lwu	a4,-8(a5)
ffffffffc020061e:	00d76763          	bltu	a4,a3,ffffffffc020062c <best_fit_alloc_pages+0x3c>
ffffffffc0200622:	00b77563          	bgeu	a4,a1,ffffffffc020062c <best_fit_alloc_pages+0x3c>
        struct Page *p = le2page(le, page_link);
ffffffffc0200626:	fe878513          	addi	a0,a5,-24
ffffffffc020062a:	85ba                	mv	a1,a4
ffffffffc020062c:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &free_list) {
ffffffffc020062e:	fec796e3          	bne	a5,a2,ffffffffc020061a <best_fit_alloc_pages+0x2a>
    if (page != NULL) {
ffffffffc0200632:	c929                	beqz	a0,ffffffffc0200684 <best_fit_alloc_pages+0x94>
        if (page->property > n) {
ffffffffc0200634:	01052883          	lw	a7,16(a0)
 * list_prev - get the previous entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_prev(list_entry_t *listelm) {
    return listelm->prev;
ffffffffc0200638:	6d18                	ld	a4,24(a0)
    __list_del(listelm->prev, listelm->next);
ffffffffc020063a:	710c                	ld	a1,32(a0)
ffffffffc020063c:	02089793          	slli	a5,a7,0x20
ffffffffc0200640:	9381                	srli	a5,a5,0x20
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc0200642:	e70c                	sd	a1,8(a4)
    next->prev = prev;
ffffffffc0200644:	e198                	sd	a4,0(a1)
            p->property = page->property - n;
ffffffffc0200646:	0006831b          	sext.w	t1,a3
        if (page->property > n) {
ffffffffc020064a:	02f6f563          	bgeu	a3,a5,ffffffffc0200674 <best_fit_alloc_pages+0x84>
            struct Page *p = page + n;
ffffffffc020064e:	00269793          	slli	a5,a3,0x2
ffffffffc0200652:	97b6                	add	a5,a5,a3
ffffffffc0200654:	078e                	slli	a5,a5,0x3
ffffffffc0200656:	97aa                	add	a5,a5,a0
            SetPageProperty(p);
ffffffffc0200658:	6794                	ld	a3,8(a5)
            p->property = page->property - n;
ffffffffc020065a:	406888bb          	subw	a7,a7,t1
ffffffffc020065e:	0117a823          	sw	a7,16(a5)
            SetPageProperty(p);
ffffffffc0200662:	0026e693          	ori	a3,a3,2
ffffffffc0200666:	e794                	sd	a3,8(a5)
            list_add(prev, &(p->page_link));
ffffffffc0200668:	01878693          	addi	a3,a5,24
    prev->next = next->prev = elm;
ffffffffc020066c:	e194                	sd	a3,0(a1)
ffffffffc020066e:	e714                	sd	a3,8(a4)
    elm->next = next;
ffffffffc0200670:	f38c                	sd	a1,32(a5)
    elm->prev = prev;
ffffffffc0200672:	ef98                	sd	a4,24(a5)
        ClearPageProperty(page);
ffffffffc0200674:	651c                	ld	a5,8(a0)
        nr_free -= n;
ffffffffc0200676:	4068083b          	subw	a6,a6,t1
ffffffffc020067a:	01062823          	sw	a6,16(a2)
        ClearPageProperty(page);
ffffffffc020067e:	9bf5                	andi	a5,a5,-3
ffffffffc0200680:	e51c                	sd	a5,8(a0)
ffffffffc0200682:	8082                	ret
}
ffffffffc0200684:	8082                	ret
        return NULL;
ffffffffc0200686:	4501                	li	a0,0
ffffffffc0200688:	8082                	ret
best_fit_alloc_pages(size_t n) {
ffffffffc020068a:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc020068c:	00001697          	auipc	a3,0x1
ffffffffc0200690:	23c68693          	addi	a3,a3,572 # ffffffffc02018c8 <etext+0x262>
ffffffffc0200694:	00001617          	auipc	a2,0x1
ffffffffc0200698:	23c60613          	addi	a2,a2,572 # ffffffffc02018d0 <etext+0x26a>
ffffffffc020069c:	06900593          	li	a1,105
ffffffffc02006a0:	00001517          	auipc	a0,0x1
ffffffffc02006a4:	24850513          	addi	a0,a0,584 # ffffffffc02018e8 <etext+0x282>
best_fit_alloc_pages(size_t n) {
ffffffffc02006a8:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc02006aa:	b1dff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc02006ae <best_fit_check>:
}

// LAB2: below code is used to check the best fit allocation algorithm (your EXERCISE 1) 
// NOTICE: You SHOULD NOT CHANGE basic_check, default_check functions!
static void
best_fit_check(void) {
ffffffffc02006ae:	715d                	addi	sp,sp,-80
ffffffffc02006b0:	e0a2                	sd	s0,64(sp)
    return listelm->next;
ffffffffc02006b2:	00005417          	auipc	s0,0x5
ffffffffc02006b6:	96640413          	addi	s0,s0,-1690 # ffffffffc0205018 <free_area>
ffffffffc02006ba:	641c                	ld	a5,8(s0)
ffffffffc02006bc:	e486                	sd	ra,72(sp)
ffffffffc02006be:	fc26                	sd	s1,56(sp)
ffffffffc02006c0:	f84a                	sd	s2,48(sp)
ffffffffc02006c2:	f44e                	sd	s3,40(sp)
ffffffffc02006c4:	f052                	sd	s4,32(sp)
ffffffffc02006c6:	ec56                	sd	s5,24(sp)
ffffffffc02006c8:	e85a                	sd	s6,16(sp)
ffffffffc02006ca:	e45e                	sd	s7,8(sp)
ffffffffc02006cc:	e062                	sd	s8,0(sp)
    int score = 0 ,sumscore = 6;
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc02006ce:	26878963          	beq	a5,s0,ffffffffc0200940 <best_fit_check+0x292>
    int count = 0, total = 0;
ffffffffc02006d2:	4481                	li	s1,0
ffffffffc02006d4:	4901                	li	s2,0
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
ffffffffc02006d6:	ff07b703          	ld	a4,-16(a5)
ffffffffc02006da:	8b09                	andi	a4,a4,2
ffffffffc02006dc:	26070663          	beqz	a4,ffffffffc0200948 <best_fit_check+0x29a>
        count ++, total += p->property;
ffffffffc02006e0:	ff87a703          	lw	a4,-8(a5)
ffffffffc02006e4:	679c                	ld	a5,8(a5)
ffffffffc02006e6:	2905                	addiw	s2,s2,1
ffffffffc02006e8:	9cb9                	addw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc02006ea:	fe8796e3          	bne	a5,s0,ffffffffc02006d6 <best_fit_check+0x28>
    }
    assert(total == nr_free_pages());
ffffffffc02006ee:	89a6                	mv	s3,s1
ffffffffc02006f0:	0ff000ef          	jal	ra,ffffffffc0200fee <nr_free_pages>
ffffffffc02006f4:	33351a63          	bne	a0,s3,ffffffffc0200a28 <best_fit_check+0x37a>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02006f8:	4505                	li	a0,1
ffffffffc02006fa:	0dd000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc02006fe:	8a2a                	mv	s4,a0
ffffffffc0200700:	36050463          	beqz	a0,ffffffffc0200a68 <best_fit_check+0x3ba>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200704:	4505                	li	a0,1
ffffffffc0200706:	0d1000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc020070a:	89aa                	mv	s3,a0
ffffffffc020070c:	32050e63          	beqz	a0,ffffffffc0200a48 <best_fit_check+0x39a>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200710:	4505                	li	a0,1
ffffffffc0200712:	0c5000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc0200716:	8aaa                	mv	s5,a0
ffffffffc0200718:	2c050863          	beqz	a0,ffffffffc02009e8 <best_fit_check+0x33a>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc020071c:	253a0663          	beq	s4,s3,ffffffffc0200968 <best_fit_check+0x2ba>
ffffffffc0200720:	24aa0463          	beq	s4,a0,ffffffffc0200968 <best_fit_check+0x2ba>
ffffffffc0200724:	24a98263          	beq	s3,a0,ffffffffc0200968 <best_fit_check+0x2ba>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200728:	000a2783          	lw	a5,0(s4)
ffffffffc020072c:	24079e63          	bnez	a5,ffffffffc0200988 <best_fit_check+0x2da>
ffffffffc0200730:	0009a783          	lw	a5,0(s3)
ffffffffc0200734:	24079a63          	bnez	a5,ffffffffc0200988 <best_fit_check+0x2da>
ffffffffc0200738:	411c                	lw	a5,0(a0)
ffffffffc020073a:	24079763          	bnez	a5,ffffffffc0200988 <best_fit_check+0x2da>
extern size_t npage;
extern const size_t nbase;
extern uint64_t va_pa_offset;

// 将页结构指针转换为物理页号
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc020073e:	00005797          	auipc	a5,0x5
ffffffffc0200742:	9127b783          	ld	a5,-1774(a5) # ffffffffc0205050 <pages>
ffffffffc0200746:	40fa0733          	sub	a4,s4,a5
ffffffffc020074a:	870d                	srai	a4,a4,0x3
ffffffffc020074c:	00002597          	auipc	a1,0x2
ffffffffc0200750:	88c5b583          	ld	a1,-1908(a1) # ffffffffc0201fd8 <error_string+0x38>
ffffffffc0200754:	02b70733          	mul	a4,a4,a1
ffffffffc0200758:	00002617          	auipc	a2,0x2
ffffffffc020075c:	88863603          	ld	a2,-1912(a2) # ffffffffc0201fe0 <nbase>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200760:	00005697          	auipc	a3,0x5
ffffffffc0200764:	8e86b683          	ld	a3,-1816(a3) # ffffffffc0205048 <npage>
ffffffffc0200768:	06b2                	slli	a3,a3,0xc
ffffffffc020076a:	9732                	add	a4,a4,a2

// 将页结构指针转换为物理地址
static inline uintptr_t page2pa(struct Page *page) {
    return page2ppn(page) << PGSHIFT;
ffffffffc020076c:	0732                	slli	a4,a4,0xc
ffffffffc020076e:	22d77d63          	bgeu	a4,a3,ffffffffc02009a8 <best_fit_check+0x2fa>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200772:	40f98733          	sub	a4,s3,a5
ffffffffc0200776:	870d                	srai	a4,a4,0x3
ffffffffc0200778:	02b70733          	mul	a4,a4,a1
ffffffffc020077c:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc020077e:	0732                	slli	a4,a4,0xc
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200780:	3ed77463          	bgeu	a4,a3,ffffffffc0200b68 <best_fit_check+0x4ba>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200784:	40f507b3          	sub	a5,a0,a5
ffffffffc0200788:	878d                	srai	a5,a5,0x3
ffffffffc020078a:	02b787b3          	mul	a5,a5,a1
ffffffffc020078e:	97b2                	add	a5,a5,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200790:	07b2                	slli	a5,a5,0xc
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200792:	3ad7fb63          	bgeu	a5,a3,ffffffffc0200b48 <best_fit_check+0x49a>
    assert(alloc_page() == NULL);
ffffffffc0200796:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200798:	00043c03          	ld	s8,0(s0)
ffffffffc020079c:	00843b83          	ld	s7,8(s0)
    unsigned int nr_free_store = nr_free;
ffffffffc02007a0:	01042b03          	lw	s6,16(s0)
    elm->prev = elm->next = elm;
ffffffffc02007a4:	e400                	sd	s0,8(s0)
ffffffffc02007a6:	e000                	sd	s0,0(s0)
    nr_free = 0;
ffffffffc02007a8:	00005797          	auipc	a5,0x5
ffffffffc02007ac:	8807a023          	sw	zero,-1920(a5) # ffffffffc0205028 <free_area+0x10>
    assert(alloc_page() == NULL);
ffffffffc02007b0:	027000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc02007b4:	36051a63          	bnez	a0,ffffffffc0200b28 <best_fit_check+0x47a>
    free_page(p0);
ffffffffc02007b8:	4585                	li	a1,1
ffffffffc02007ba:	8552                	mv	a0,s4
ffffffffc02007bc:	027000ef          	jal	ra,ffffffffc0200fe2 <free_pages>
    free_page(p1);
ffffffffc02007c0:	4585                	li	a1,1
ffffffffc02007c2:	854e                	mv	a0,s3
ffffffffc02007c4:	01f000ef          	jal	ra,ffffffffc0200fe2 <free_pages>
    free_page(p2);
ffffffffc02007c8:	4585                	li	a1,1
ffffffffc02007ca:	8556                	mv	a0,s5
ffffffffc02007cc:	017000ef          	jal	ra,ffffffffc0200fe2 <free_pages>
    assert(nr_free == 3);
ffffffffc02007d0:	4818                	lw	a4,16(s0)
ffffffffc02007d2:	478d                	li	a5,3
ffffffffc02007d4:	32f71a63          	bne	a4,a5,ffffffffc0200b08 <best_fit_check+0x45a>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02007d8:	4505                	li	a0,1
ffffffffc02007da:	7fc000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc02007de:	89aa                	mv	s3,a0
ffffffffc02007e0:	30050463          	beqz	a0,ffffffffc0200ae8 <best_fit_check+0x43a>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02007e4:	4505                	li	a0,1
ffffffffc02007e6:	7f0000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc02007ea:	8aaa                	mv	s5,a0
ffffffffc02007ec:	2c050e63          	beqz	a0,ffffffffc0200ac8 <best_fit_check+0x41a>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02007f0:	4505                	li	a0,1
ffffffffc02007f2:	7e4000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc02007f6:	8a2a                	mv	s4,a0
ffffffffc02007f8:	2a050863          	beqz	a0,ffffffffc0200aa8 <best_fit_check+0x3fa>
    assert(alloc_page() == NULL);
ffffffffc02007fc:	4505                	li	a0,1
ffffffffc02007fe:	7d8000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc0200802:	28051363          	bnez	a0,ffffffffc0200a88 <best_fit_check+0x3da>
    free_page(p0);
ffffffffc0200806:	4585                	li	a1,1
ffffffffc0200808:	854e                	mv	a0,s3
ffffffffc020080a:	7d8000ef          	jal	ra,ffffffffc0200fe2 <free_pages>
    assert(!list_empty(&free_list));
ffffffffc020080e:	641c                	ld	a5,8(s0)
ffffffffc0200810:	1a878c63          	beq	a5,s0,ffffffffc02009c8 <best_fit_check+0x31a>
    assert((p = alloc_page()) == p0);
ffffffffc0200814:	4505                	li	a0,1
ffffffffc0200816:	7c0000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc020081a:	52a99763          	bne	s3,a0,ffffffffc0200d48 <best_fit_check+0x69a>
    assert(alloc_page() == NULL);
ffffffffc020081e:	4505                	li	a0,1
ffffffffc0200820:	7b6000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc0200824:	50051263          	bnez	a0,ffffffffc0200d28 <best_fit_check+0x67a>
    assert(nr_free == 0);
ffffffffc0200828:	481c                	lw	a5,16(s0)
ffffffffc020082a:	4c079f63          	bnez	a5,ffffffffc0200d08 <best_fit_check+0x65a>
    free_page(p);
ffffffffc020082e:	854e                	mv	a0,s3
ffffffffc0200830:	4585                	li	a1,1
    free_list = free_list_store;
ffffffffc0200832:	01843023          	sd	s8,0(s0)
ffffffffc0200836:	01743423          	sd	s7,8(s0)
    nr_free = nr_free_store;
ffffffffc020083a:	01642823          	sw	s6,16(s0)
    free_page(p);
ffffffffc020083e:	7a4000ef          	jal	ra,ffffffffc0200fe2 <free_pages>
    free_page(p1);
ffffffffc0200842:	4585                	li	a1,1
ffffffffc0200844:	8556                	mv	a0,s5
ffffffffc0200846:	79c000ef          	jal	ra,ffffffffc0200fe2 <free_pages>
    free_page(p2);
ffffffffc020084a:	4585                	li	a1,1
ffffffffc020084c:	8552                	mv	a0,s4
ffffffffc020084e:	794000ef          	jal	ra,ffffffffc0200fe2 <free_pages>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n",score, sumscore);
    #endif
    struct Page *p0 = alloc_pages(5), *p1, *p2;
ffffffffc0200852:	4515                	li	a0,5
ffffffffc0200854:	782000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc0200858:	89aa                	mv	s3,a0
    assert(p0 != NULL);
ffffffffc020085a:	48050763          	beqz	a0,ffffffffc0200ce8 <best_fit_check+0x63a>
    assert(!PageProperty(p0));
ffffffffc020085e:	651c                	ld	a5,8(a0)
ffffffffc0200860:	8b89                	andi	a5,a5,2
ffffffffc0200862:	46079363          	bnez	a5,ffffffffc0200cc8 <best_fit_check+0x61a>
    cprintf("grading: %d / %d points\n",score, sumscore);
    #endif
    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);
ffffffffc0200866:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200868:	00043b03          	ld	s6,0(s0)
ffffffffc020086c:	00843a83          	ld	s5,8(s0)
ffffffffc0200870:	e000                	sd	s0,0(s0)
ffffffffc0200872:	e400                	sd	s0,8(s0)
    assert(alloc_page() == NULL);
ffffffffc0200874:	762000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc0200878:	42051863          	bnez	a0,ffffffffc0200ca8 <best_fit_check+0x5fa>
    #endif
    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    // * - - * -
    free_pages(p0 + 1, 2);
ffffffffc020087c:	4589                	li	a1,2
ffffffffc020087e:	02898513          	addi	a0,s3,40
    unsigned int nr_free_store = nr_free;
ffffffffc0200882:	01042b83          	lw	s7,16(s0)
    free_pages(p0 + 4, 1);
ffffffffc0200886:	0a098c13          	addi	s8,s3,160
    nr_free = 0;
ffffffffc020088a:	00004797          	auipc	a5,0x4
ffffffffc020088e:	7807af23          	sw	zero,1950(a5) # ffffffffc0205028 <free_area+0x10>
    free_pages(p0 + 1, 2);
ffffffffc0200892:	750000ef          	jal	ra,ffffffffc0200fe2 <free_pages>
    free_pages(p0 + 4, 1);
ffffffffc0200896:	8562                	mv	a0,s8
ffffffffc0200898:	4585                	li	a1,1
ffffffffc020089a:	748000ef          	jal	ra,ffffffffc0200fe2 <free_pages>
    assert(alloc_pages(4) == NULL);
ffffffffc020089e:	4511                	li	a0,4
ffffffffc02008a0:	736000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc02008a4:	3e051263          	bnez	a0,ffffffffc0200c88 <best_fit_check+0x5da>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc02008a8:	0309b783          	ld	a5,48(s3)
ffffffffc02008ac:	8b89                	andi	a5,a5,2
ffffffffc02008ae:	3a078d63          	beqz	a5,ffffffffc0200c68 <best_fit_check+0x5ba>
ffffffffc02008b2:	0389a703          	lw	a4,56(s3)
ffffffffc02008b6:	4789                	li	a5,2
ffffffffc02008b8:	3af71863          	bne	a4,a5,ffffffffc0200c68 <best_fit_check+0x5ba>
    // * - - * *
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc02008bc:	4505                	li	a0,1
ffffffffc02008be:	718000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc02008c2:	8a2a                	mv	s4,a0
ffffffffc02008c4:	38050263          	beqz	a0,ffffffffc0200c48 <best_fit_check+0x59a>
    assert(alloc_pages(2) != NULL);      // best fit feature
ffffffffc02008c8:	4509                	li	a0,2
ffffffffc02008ca:	70c000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc02008ce:	34050d63          	beqz	a0,ffffffffc0200c28 <best_fit_check+0x57a>
    assert(p0 + 4 == p1);
ffffffffc02008d2:	334c1b63          	bne	s8,s4,ffffffffc0200c08 <best_fit_check+0x55a>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n",score, sumscore);
    #endif
    p2 = p0 + 1;
    free_pages(p0, 5);
ffffffffc02008d6:	854e                	mv	a0,s3
ffffffffc02008d8:	4595                	li	a1,5
ffffffffc02008da:	708000ef          	jal	ra,ffffffffc0200fe2 <free_pages>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc02008de:	4515                	li	a0,5
ffffffffc02008e0:	6f6000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc02008e4:	89aa                	mv	s3,a0
ffffffffc02008e6:	30050163          	beqz	a0,ffffffffc0200be8 <best_fit_check+0x53a>
    assert(alloc_page() == NULL);
ffffffffc02008ea:	4505                	li	a0,1
ffffffffc02008ec:	6ea000ef          	jal	ra,ffffffffc0200fd6 <alloc_pages>
ffffffffc02008f0:	2c051c63          	bnez	a0,ffffffffc0200bc8 <best_fit_check+0x51a>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n",score, sumscore);
    #endif
    assert(nr_free == 0);
ffffffffc02008f4:	481c                	lw	a5,16(s0)
ffffffffc02008f6:	2a079963          	bnez	a5,ffffffffc0200ba8 <best_fit_check+0x4fa>
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);
ffffffffc02008fa:	4595                	li	a1,5
ffffffffc02008fc:	854e                	mv	a0,s3
    nr_free = nr_free_store;
ffffffffc02008fe:	01742823          	sw	s7,16(s0)
    free_list = free_list_store;
ffffffffc0200902:	01643023          	sd	s6,0(s0)
ffffffffc0200906:	01543423          	sd	s5,8(s0)
    free_pages(p0, 5);
ffffffffc020090a:	6d8000ef          	jal	ra,ffffffffc0200fe2 <free_pages>
    return listelm->next;
ffffffffc020090e:	641c                	ld	a5,8(s0)

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200910:	00878963          	beq	a5,s0,ffffffffc0200922 <best_fit_check+0x274>
        struct Page *p = le2page(le, page_link);
        count --, total -= p->property;
ffffffffc0200914:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200918:	679c                	ld	a5,8(a5)
ffffffffc020091a:	397d                	addiw	s2,s2,-1
ffffffffc020091c:	9c99                	subw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc020091e:	fe879be3          	bne	a5,s0,ffffffffc0200914 <best_fit_check+0x266>
    }
    assert(count == 0);
ffffffffc0200922:	26091363          	bnez	s2,ffffffffc0200b88 <best_fit_check+0x4da>
    assert(total == 0);
ffffffffc0200926:	e0ed                	bnez	s1,ffffffffc0200a08 <best_fit_check+0x35a>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n",score, sumscore);
    #endif
}
ffffffffc0200928:	60a6                	ld	ra,72(sp)
ffffffffc020092a:	6406                	ld	s0,64(sp)
ffffffffc020092c:	74e2                	ld	s1,56(sp)
ffffffffc020092e:	7942                	ld	s2,48(sp)
ffffffffc0200930:	79a2                	ld	s3,40(sp)
ffffffffc0200932:	7a02                	ld	s4,32(sp)
ffffffffc0200934:	6ae2                	ld	s5,24(sp)
ffffffffc0200936:	6b42                	ld	s6,16(sp)
ffffffffc0200938:	6ba2                	ld	s7,8(sp)
ffffffffc020093a:	6c02                	ld	s8,0(sp)
ffffffffc020093c:	6161                	addi	sp,sp,80
ffffffffc020093e:	8082                	ret
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200940:	4981                	li	s3,0
    int count = 0, total = 0;
ffffffffc0200942:	4481                	li	s1,0
ffffffffc0200944:	4901                	li	s2,0
ffffffffc0200946:	b36d                	j	ffffffffc02006f0 <best_fit_check+0x42>
        assert(PageProperty(p));
ffffffffc0200948:	00001697          	auipc	a3,0x1
ffffffffc020094c:	fb868693          	addi	a3,a3,-72 # ffffffffc0201900 <etext+0x29a>
ffffffffc0200950:	00001617          	auipc	a2,0x1
ffffffffc0200954:	f8060613          	addi	a2,a2,-128 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200958:	10900593          	li	a1,265
ffffffffc020095c:	00001517          	auipc	a0,0x1
ffffffffc0200960:	f8c50513          	addi	a0,a0,-116 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200964:	863ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200968:	00001697          	auipc	a3,0x1
ffffffffc020096c:	02868693          	addi	a3,a3,40 # ffffffffc0201990 <etext+0x32a>
ffffffffc0200970:	00001617          	auipc	a2,0x1
ffffffffc0200974:	f6060613          	addi	a2,a2,-160 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200978:	0d500593          	li	a1,213
ffffffffc020097c:	00001517          	auipc	a0,0x1
ffffffffc0200980:	f6c50513          	addi	a0,a0,-148 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200984:	843ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200988:	00001697          	auipc	a3,0x1
ffffffffc020098c:	03068693          	addi	a3,a3,48 # ffffffffc02019b8 <etext+0x352>
ffffffffc0200990:	00001617          	auipc	a2,0x1
ffffffffc0200994:	f4060613          	addi	a2,a2,-192 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200998:	0d600593          	li	a1,214
ffffffffc020099c:	00001517          	auipc	a0,0x1
ffffffffc02009a0:	f4c50513          	addi	a0,a0,-180 # ffffffffc02018e8 <etext+0x282>
ffffffffc02009a4:	823ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc02009a8:	00001697          	auipc	a3,0x1
ffffffffc02009ac:	05068693          	addi	a3,a3,80 # ffffffffc02019f8 <etext+0x392>
ffffffffc02009b0:	00001617          	auipc	a2,0x1
ffffffffc02009b4:	f2060613          	addi	a2,a2,-224 # ffffffffc02018d0 <etext+0x26a>
ffffffffc02009b8:	0d800593          	li	a1,216
ffffffffc02009bc:	00001517          	auipc	a0,0x1
ffffffffc02009c0:	f2c50513          	addi	a0,a0,-212 # ffffffffc02018e8 <etext+0x282>
ffffffffc02009c4:	803ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(!list_empty(&free_list));
ffffffffc02009c8:	00001697          	auipc	a3,0x1
ffffffffc02009cc:	0b868693          	addi	a3,a3,184 # ffffffffc0201a80 <etext+0x41a>
ffffffffc02009d0:	00001617          	auipc	a2,0x1
ffffffffc02009d4:	f0060613          	addi	a2,a2,-256 # ffffffffc02018d0 <etext+0x26a>
ffffffffc02009d8:	0f100593          	li	a1,241
ffffffffc02009dc:	00001517          	auipc	a0,0x1
ffffffffc02009e0:	f0c50513          	addi	a0,a0,-244 # ffffffffc02018e8 <etext+0x282>
ffffffffc02009e4:	fe2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02009e8:	00001697          	auipc	a3,0x1
ffffffffc02009ec:	f8868693          	addi	a3,a3,-120 # ffffffffc0201970 <etext+0x30a>
ffffffffc02009f0:	00001617          	auipc	a2,0x1
ffffffffc02009f4:	ee060613          	addi	a2,a2,-288 # ffffffffc02018d0 <etext+0x26a>
ffffffffc02009f8:	0d300593          	li	a1,211
ffffffffc02009fc:	00001517          	auipc	a0,0x1
ffffffffc0200a00:	eec50513          	addi	a0,a0,-276 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200a04:	fc2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(total == 0);
ffffffffc0200a08:	00001697          	auipc	a3,0x1
ffffffffc0200a0c:	1a868693          	addi	a3,a3,424 # ffffffffc0201bb0 <etext+0x54a>
ffffffffc0200a10:	00001617          	auipc	a2,0x1
ffffffffc0200a14:	ec060613          	addi	a2,a2,-320 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200a18:	14b00593          	li	a1,331
ffffffffc0200a1c:	00001517          	auipc	a0,0x1
ffffffffc0200a20:	ecc50513          	addi	a0,a0,-308 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200a24:	fa2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(total == nr_free_pages());
ffffffffc0200a28:	00001697          	auipc	a3,0x1
ffffffffc0200a2c:	ee868693          	addi	a3,a3,-280 # ffffffffc0201910 <etext+0x2aa>
ffffffffc0200a30:	00001617          	auipc	a2,0x1
ffffffffc0200a34:	ea060613          	addi	a2,a2,-352 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200a38:	10c00593          	li	a1,268
ffffffffc0200a3c:	00001517          	auipc	a0,0x1
ffffffffc0200a40:	eac50513          	addi	a0,a0,-340 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200a44:	f82ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200a48:	00001697          	auipc	a3,0x1
ffffffffc0200a4c:	f0868693          	addi	a3,a3,-248 # ffffffffc0201950 <etext+0x2ea>
ffffffffc0200a50:	00001617          	auipc	a2,0x1
ffffffffc0200a54:	e8060613          	addi	a2,a2,-384 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200a58:	0d200593          	li	a1,210
ffffffffc0200a5c:	00001517          	auipc	a0,0x1
ffffffffc0200a60:	e8c50513          	addi	a0,a0,-372 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200a64:	f62ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200a68:	00001697          	auipc	a3,0x1
ffffffffc0200a6c:	ec868693          	addi	a3,a3,-312 # ffffffffc0201930 <etext+0x2ca>
ffffffffc0200a70:	00001617          	auipc	a2,0x1
ffffffffc0200a74:	e6060613          	addi	a2,a2,-416 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200a78:	0d100593          	li	a1,209
ffffffffc0200a7c:	00001517          	auipc	a0,0x1
ffffffffc0200a80:	e6c50513          	addi	a0,a0,-404 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200a84:	f42ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200a88:	00001697          	auipc	a3,0x1
ffffffffc0200a8c:	fd068693          	addi	a3,a3,-48 # ffffffffc0201a58 <etext+0x3f2>
ffffffffc0200a90:	00001617          	auipc	a2,0x1
ffffffffc0200a94:	e4060613          	addi	a2,a2,-448 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200a98:	0ee00593          	li	a1,238
ffffffffc0200a9c:	00001517          	auipc	a0,0x1
ffffffffc0200aa0:	e4c50513          	addi	a0,a0,-436 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200aa4:	f22ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200aa8:	00001697          	auipc	a3,0x1
ffffffffc0200aac:	ec868693          	addi	a3,a3,-312 # ffffffffc0201970 <etext+0x30a>
ffffffffc0200ab0:	00001617          	auipc	a2,0x1
ffffffffc0200ab4:	e2060613          	addi	a2,a2,-480 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200ab8:	0ec00593          	li	a1,236
ffffffffc0200abc:	00001517          	auipc	a0,0x1
ffffffffc0200ac0:	e2c50513          	addi	a0,a0,-468 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200ac4:	f02ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200ac8:	00001697          	auipc	a3,0x1
ffffffffc0200acc:	e8868693          	addi	a3,a3,-376 # ffffffffc0201950 <etext+0x2ea>
ffffffffc0200ad0:	00001617          	auipc	a2,0x1
ffffffffc0200ad4:	e0060613          	addi	a2,a2,-512 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200ad8:	0eb00593          	li	a1,235
ffffffffc0200adc:	00001517          	auipc	a0,0x1
ffffffffc0200ae0:	e0c50513          	addi	a0,a0,-500 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200ae4:	ee2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200ae8:	00001697          	auipc	a3,0x1
ffffffffc0200aec:	e4868693          	addi	a3,a3,-440 # ffffffffc0201930 <etext+0x2ca>
ffffffffc0200af0:	00001617          	auipc	a2,0x1
ffffffffc0200af4:	de060613          	addi	a2,a2,-544 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200af8:	0ea00593          	li	a1,234
ffffffffc0200afc:	00001517          	auipc	a0,0x1
ffffffffc0200b00:	dec50513          	addi	a0,a0,-532 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200b04:	ec2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(nr_free == 3);
ffffffffc0200b08:	00001697          	auipc	a3,0x1
ffffffffc0200b0c:	f6868693          	addi	a3,a3,-152 # ffffffffc0201a70 <etext+0x40a>
ffffffffc0200b10:	00001617          	auipc	a2,0x1
ffffffffc0200b14:	dc060613          	addi	a2,a2,-576 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200b18:	0e800593          	li	a1,232
ffffffffc0200b1c:	00001517          	auipc	a0,0x1
ffffffffc0200b20:	dcc50513          	addi	a0,a0,-564 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200b24:	ea2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200b28:	00001697          	auipc	a3,0x1
ffffffffc0200b2c:	f3068693          	addi	a3,a3,-208 # ffffffffc0201a58 <etext+0x3f2>
ffffffffc0200b30:	00001617          	auipc	a2,0x1
ffffffffc0200b34:	da060613          	addi	a2,a2,-608 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200b38:	0e300593          	li	a1,227
ffffffffc0200b3c:	00001517          	auipc	a0,0x1
ffffffffc0200b40:	dac50513          	addi	a0,a0,-596 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200b44:	e82ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200b48:	00001697          	auipc	a3,0x1
ffffffffc0200b4c:	ef068693          	addi	a3,a3,-272 # ffffffffc0201a38 <etext+0x3d2>
ffffffffc0200b50:	00001617          	auipc	a2,0x1
ffffffffc0200b54:	d8060613          	addi	a2,a2,-640 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200b58:	0da00593          	li	a1,218
ffffffffc0200b5c:	00001517          	auipc	a0,0x1
ffffffffc0200b60:	d8c50513          	addi	a0,a0,-628 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200b64:	e62ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200b68:	00001697          	auipc	a3,0x1
ffffffffc0200b6c:	eb068693          	addi	a3,a3,-336 # ffffffffc0201a18 <etext+0x3b2>
ffffffffc0200b70:	00001617          	auipc	a2,0x1
ffffffffc0200b74:	d6060613          	addi	a2,a2,-672 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200b78:	0d900593          	li	a1,217
ffffffffc0200b7c:	00001517          	auipc	a0,0x1
ffffffffc0200b80:	d6c50513          	addi	a0,a0,-660 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200b84:	e42ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(count == 0);
ffffffffc0200b88:	00001697          	auipc	a3,0x1
ffffffffc0200b8c:	01868693          	addi	a3,a3,24 # ffffffffc0201ba0 <etext+0x53a>
ffffffffc0200b90:	00001617          	auipc	a2,0x1
ffffffffc0200b94:	d4060613          	addi	a2,a2,-704 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200b98:	14a00593          	li	a1,330
ffffffffc0200b9c:	00001517          	auipc	a0,0x1
ffffffffc0200ba0:	d4c50513          	addi	a0,a0,-692 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200ba4:	e22ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(nr_free == 0);
ffffffffc0200ba8:	00001697          	auipc	a3,0x1
ffffffffc0200bac:	f1068693          	addi	a3,a3,-240 # ffffffffc0201ab8 <etext+0x452>
ffffffffc0200bb0:	00001617          	auipc	a2,0x1
ffffffffc0200bb4:	d2060613          	addi	a2,a2,-736 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200bb8:	13f00593          	li	a1,319
ffffffffc0200bbc:	00001517          	auipc	a0,0x1
ffffffffc0200bc0:	d2c50513          	addi	a0,a0,-724 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200bc4:	e02ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200bc8:	00001697          	auipc	a3,0x1
ffffffffc0200bcc:	e9068693          	addi	a3,a3,-368 # ffffffffc0201a58 <etext+0x3f2>
ffffffffc0200bd0:	00001617          	auipc	a2,0x1
ffffffffc0200bd4:	d0060613          	addi	a2,a2,-768 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200bd8:	13900593          	li	a1,313
ffffffffc0200bdc:	00001517          	auipc	a0,0x1
ffffffffc0200be0:	d0c50513          	addi	a0,a0,-756 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200be4:	de2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200be8:	00001697          	auipc	a3,0x1
ffffffffc0200bec:	f9868693          	addi	a3,a3,-104 # ffffffffc0201b80 <etext+0x51a>
ffffffffc0200bf0:	00001617          	auipc	a2,0x1
ffffffffc0200bf4:	ce060613          	addi	a2,a2,-800 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200bf8:	13800593          	li	a1,312
ffffffffc0200bfc:	00001517          	auipc	a0,0x1
ffffffffc0200c00:	cec50513          	addi	a0,a0,-788 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200c04:	dc2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(p0 + 4 == p1);
ffffffffc0200c08:	00001697          	auipc	a3,0x1
ffffffffc0200c0c:	f6868693          	addi	a3,a3,-152 # ffffffffc0201b70 <etext+0x50a>
ffffffffc0200c10:	00001617          	auipc	a2,0x1
ffffffffc0200c14:	cc060613          	addi	a2,a2,-832 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200c18:	13000593          	li	a1,304
ffffffffc0200c1c:	00001517          	auipc	a0,0x1
ffffffffc0200c20:	ccc50513          	addi	a0,a0,-820 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200c24:	da2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(alloc_pages(2) != NULL);      // best fit feature
ffffffffc0200c28:	00001697          	auipc	a3,0x1
ffffffffc0200c2c:	f3068693          	addi	a3,a3,-208 # ffffffffc0201b58 <etext+0x4f2>
ffffffffc0200c30:	00001617          	auipc	a2,0x1
ffffffffc0200c34:	ca060613          	addi	a2,a2,-864 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200c38:	12f00593          	li	a1,303
ffffffffc0200c3c:	00001517          	auipc	a0,0x1
ffffffffc0200c40:	cac50513          	addi	a0,a0,-852 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200c44:	d82ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc0200c48:	00001697          	auipc	a3,0x1
ffffffffc0200c4c:	ef068693          	addi	a3,a3,-272 # ffffffffc0201b38 <etext+0x4d2>
ffffffffc0200c50:	00001617          	auipc	a2,0x1
ffffffffc0200c54:	c8060613          	addi	a2,a2,-896 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200c58:	12e00593          	li	a1,302
ffffffffc0200c5c:	00001517          	auipc	a0,0x1
ffffffffc0200c60:	c8c50513          	addi	a0,a0,-884 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200c64:	d62ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc0200c68:	00001697          	auipc	a3,0x1
ffffffffc0200c6c:	ea068693          	addi	a3,a3,-352 # ffffffffc0201b08 <etext+0x4a2>
ffffffffc0200c70:	00001617          	auipc	a2,0x1
ffffffffc0200c74:	c6060613          	addi	a2,a2,-928 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200c78:	12c00593          	li	a1,300
ffffffffc0200c7c:	00001517          	auipc	a0,0x1
ffffffffc0200c80:	c6c50513          	addi	a0,a0,-916 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200c84:	d42ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(alloc_pages(4) == NULL);
ffffffffc0200c88:	00001697          	auipc	a3,0x1
ffffffffc0200c8c:	e6868693          	addi	a3,a3,-408 # ffffffffc0201af0 <etext+0x48a>
ffffffffc0200c90:	00001617          	auipc	a2,0x1
ffffffffc0200c94:	c4060613          	addi	a2,a2,-960 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200c98:	12b00593          	li	a1,299
ffffffffc0200c9c:	00001517          	auipc	a0,0x1
ffffffffc0200ca0:	c4c50513          	addi	a0,a0,-948 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200ca4:	d22ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200ca8:	00001697          	auipc	a3,0x1
ffffffffc0200cac:	db068693          	addi	a3,a3,-592 # ffffffffc0201a58 <etext+0x3f2>
ffffffffc0200cb0:	00001617          	auipc	a2,0x1
ffffffffc0200cb4:	c2060613          	addi	a2,a2,-992 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200cb8:	11f00593          	li	a1,287
ffffffffc0200cbc:	00001517          	auipc	a0,0x1
ffffffffc0200cc0:	c2c50513          	addi	a0,a0,-980 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200cc4:	d02ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(!PageProperty(p0));
ffffffffc0200cc8:	00001697          	auipc	a3,0x1
ffffffffc0200ccc:	e1068693          	addi	a3,a3,-496 # ffffffffc0201ad8 <etext+0x472>
ffffffffc0200cd0:	00001617          	auipc	a2,0x1
ffffffffc0200cd4:	c0060613          	addi	a2,a2,-1024 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200cd8:	11600593          	li	a1,278
ffffffffc0200cdc:	00001517          	auipc	a0,0x1
ffffffffc0200ce0:	c0c50513          	addi	a0,a0,-1012 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200ce4:	ce2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(p0 != NULL);
ffffffffc0200ce8:	00001697          	auipc	a3,0x1
ffffffffc0200cec:	de068693          	addi	a3,a3,-544 # ffffffffc0201ac8 <etext+0x462>
ffffffffc0200cf0:	00001617          	auipc	a2,0x1
ffffffffc0200cf4:	be060613          	addi	a2,a2,-1056 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200cf8:	11500593          	li	a1,277
ffffffffc0200cfc:	00001517          	auipc	a0,0x1
ffffffffc0200d00:	bec50513          	addi	a0,a0,-1044 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200d04:	cc2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(nr_free == 0);
ffffffffc0200d08:	00001697          	auipc	a3,0x1
ffffffffc0200d0c:	db068693          	addi	a3,a3,-592 # ffffffffc0201ab8 <etext+0x452>
ffffffffc0200d10:	00001617          	auipc	a2,0x1
ffffffffc0200d14:	bc060613          	addi	a2,a2,-1088 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200d18:	0f700593          	li	a1,247
ffffffffc0200d1c:	00001517          	auipc	a0,0x1
ffffffffc0200d20:	bcc50513          	addi	a0,a0,-1076 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200d24:	ca2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200d28:	00001697          	auipc	a3,0x1
ffffffffc0200d2c:	d3068693          	addi	a3,a3,-720 # ffffffffc0201a58 <etext+0x3f2>
ffffffffc0200d30:	00001617          	auipc	a2,0x1
ffffffffc0200d34:	ba060613          	addi	a2,a2,-1120 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200d38:	0f500593          	li	a1,245
ffffffffc0200d3c:	00001517          	auipc	a0,0x1
ffffffffc0200d40:	bac50513          	addi	a0,a0,-1108 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200d44:	c82ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert((p = alloc_page()) == p0);
ffffffffc0200d48:	00001697          	auipc	a3,0x1
ffffffffc0200d4c:	d5068693          	addi	a3,a3,-688 # ffffffffc0201a98 <etext+0x432>
ffffffffc0200d50:	00001617          	auipc	a2,0x1
ffffffffc0200d54:	b8060613          	addi	a2,a2,-1152 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200d58:	0f400593          	li	a1,244
ffffffffc0200d5c:	00001517          	auipc	a0,0x1
ffffffffc0200d60:	b8c50513          	addi	a0,a0,-1140 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200d64:	c62ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc0200d68 <best_fit_free_pages>:
best_fit_free_pages(struct Page *base, size_t n) {
ffffffffc0200d68:	1141                	addi	sp,sp,-16
ffffffffc0200d6a:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200d6c:	14058c63          	beqz	a1,ffffffffc0200ec4 <best_fit_free_pages+0x15c>
    for (; p != base + n; p ++) {
ffffffffc0200d70:	00259693          	slli	a3,a1,0x2
ffffffffc0200d74:	96ae                	add	a3,a3,a1
ffffffffc0200d76:	068e                	slli	a3,a3,0x3
ffffffffc0200d78:	96aa                	add	a3,a3,a0
ffffffffc0200d7a:	87aa                	mv	a5,a0
ffffffffc0200d7c:	00d50e63          	beq	a0,a3,ffffffffc0200d98 <best_fit_free_pages+0x30>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200d80:	6798                	ld	a4,8(a5)
ffffffffc0200d82:	8b0d                	andi	a4,a4,3
ffffffffc0200d84:	12071063          	bnez	a4,ffffffffc0200ea4 <best_fit_free_pages+0x13c>
        p->flags = 0;
ffffffffc0200d88:	0007b423          	sd	zero,8(a5)

// 获取页的引用计数
static inline int page_ref(struct Page *page) { return page->ref; }

// 设置页的引用计数
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200d8c:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc0200d90:	02878793          	addi	a5,a5,40
ffffffffc0200d94:	fed796e3          	bne	a5,a3,ffffffffc0200d80 <best_fit_free_pages+0x18>
    SetPageProperty(base);
ffffffffc0200d98:	00853883          	ld	a7,8(a0)
    nr_free += n;
ffffffffc0200d9c:	00004697          	auipc	a3,0x4
ffffffffc0200da0:	27c68693          	addi	a3,a3,636 # ffffffffc0205018 <free_area>
ffffffffc0200da4:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc0200da6:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc0200da8:	0028e613          	ori	a2,a7,2
    return list->next == list;
ffffffffc0200dac:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc0200dae:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0200db0:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc0200db2:	9f2d                	addw	a4,a4,a1
ffffffffc0200db4:	ca98                	sw	a4,16(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc0200db6:	01850613          	addi	a2,a0,24
    if (list_empty(&free_list)) {
ffffffffc0200dba:	0ad78b63          	beq	a5,a3,ffffffffc0200e70 <best_fit_free_pages+0x108>
            struct Page* page = le2page(le, page_link);
ffffffffc0200dbe:	fe878713          	addi	a4,a5,-24
ffffffffc0200dc2:	0006b303          	ld	t1,0(a3)
    if (list_empty(&free_list)) {
ffffffffc0200dc6:	4801                	li	a6,0
            if (base < page) {
ffffffffc0200dc8:	00e56a63          	bltu	a0,a4,ffffffffc0200ddc <best_fit_free_pages+0x74>
    return listelm->next;
ffffffffc0200dcc:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0200dce:	06d70563          	beq	a4,a3,ffffffffc0200e38 <best_fit_free_pages+0xd0>
    for (; p != base + n; p ++) {
ffffffffc0200dd2:	87ba                	mv	a5,a4
            struct Page* page = le2page(le, page_link);
ffffffffc0200dd4:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc0200dd8:	fee57ae3          	bgeu	a0,a4,ffffffffc0200dcc <best_fit_free_pages+0x64>
ffffffffc0200ddc:	00080463          	beqz	a6,ffffffffc0200de4 <best_fit_free_pages+0x7c>
ffffffffc0200de0:	0066b023          	sd	t1,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200de4:	0007b803          	ld	a6,0(a5)
    prev->next = next->prev = elm;
ffffffffc0200de8:	e390                	sd	a2,0(a5)
ffffffffc0200dea:	00c83423          	sd	a2,8(a6)
    elm->next = next;
ffffffffc0200dee:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200df0:	01053c23          	sd	a6,24(a0)
    if (le != &free_list) {
ffffffffc0200df4:	02d80463          	beq	a6,a3,ffffffffc0200e1c <best_fit_free_pages+0xb4>
        if (p + p->property == base) {
ffffffffc0200df8:	ff882e03          	lw	t3,-8(a6)
        p = le2page(le, page_link);
ffffffffc0200dfc:	fe880313          	addi	t1,a6,-24
        if (p + p->property == base) {
ffffffffc0200e00:	020e1613          	slli	a2,t3,0x20
ffffffffc0200e04:	9201                	srli	a2,a2,0x20
ffffffffc0200e06:	00261713          	slli	a4,a2,0x2
ffffffffc0200e0a:	9732                	add	a4,a4,a2
ffffffffc0200e0c:	070e                	slli	a4,a4,0x3
ffffffffc0200e0e:	971a                	add	a4,a4,t1
ffffffffc0200e10:	02e50e63          	beq	a0,a4,ffffffffc0200e4c <best_fit_free_pages+0xe4>
    if (le != &free_list) {
ffffffffc0200e14:	00d78f63          	beq	a5,a3,ffffffffc0200e32 <best_fit_free_pages+0xca>
ffffffffc0200e18:	fe878713          	addi	a4,a5,-24
        if (base + base->property == p) {
ffffffffc0200e1c:	490c                	lw	a1,16(a0)
ffffffffc0200e1e:	02059613          	slli	a2,a1,0x20
ffffffffc0200e22:	9201                	srli	a2,a2,0x20
ffffffffc0200e24:	00261693          	slli	a3,a2,0x2
ffffffffc0200e28:	96b2                	add	a3,a3,a2
ffffffffc0200e2a:	068e                	slli	a3,a3,0x3
ffffffffc0200e2c:	96aa                	add	a3,a3,a0
ffffffffc0200e2e:	04d70863          	beq	a4,a3,ffffffffc0200e7e <best_fit_free_pages+0x116>
}
ffffffffc0200e32:	60a2                	ld	ra,8(sp)
ffffffffc0200e34:	0141                	addi	sp,sp,16
ffffffffc0200e36:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc0200e38:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200e3a:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc0200e3c:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc0200e3e:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc0200e40:	02d70463          	beq	a4,a3,ffffffffc0200e68 <best_fit_free_pages+0x100>
    prev->next = next->prev = elm;
ffffffffc0200e44:	8332                	mv	t1,a2
ffffffffc0200e46:	4805                	li	a6,1
    for (; p != base + n; p ++) {
ffffffffc0200e48:	87ba                	mv	a5,a4
ffffffffc0200e4a:	b769                	j	ffffffffc0200dd4 <best_fit_free_pages+0x6c>
            p->property += base->property;
ffffffffc0200e4c:	01c585bb          	addw	a1,a1,t3
ffffffffc0200e50:	feb82c23          	sw	a1,-8(a6)
            ClearPageProperty(base);
ffffffffc0200e54:	ffd8f893          	andi	a7,a7,-3
ffffffffc0200e58:	01153423          	sd	a7,8(a0)
    prev->next = next;
ffffffffc0200e5c:	00f83423          	sd	a5,8(a6)
    next->prev = prev;
ffffffffc0200e60:	0107b023          	sd	a6,0(a5)
            base = p;
ffffffffc0200e64:	851a                	mv	a0,t1
ffffffffc0200e66:	b77d                	j	ffffffffc0200e14 <best_fit_free_pages+0xac>
        while ((le = list_next(le)) != &free_list) {
ffffffffc0200e68:	883e                	mv	a6,a5
ffffffffc0200e6a:	e290                	sd	a2,0(a3)
ffffffffc0200e6c:	87b6                	mv	a5,a3
ffffffffc0200e6e:	b769                	j	ffffffffc0200df8 <best_fit_free_pages+0x90>
}
ffffffffc0200e70:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0200e72:	e390                	sd	a2,0(a5)
ffffffffc0200e74:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200e76:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200e78:	ed1c                	sd	a5,24(a0)
ffffffffc0200e7a:	0141                	addi	sp,sp,16
ffffffffc0200e7c:	8082                	ret
            base->property += p->property;
ffffffffc0200e7e:	ff87a683          	lw	a3,-8(a5)
            ClearPageProperty(p);
ffffffffc0200e82:	ff07b703          	ld	a4,-16(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200e86:	0007b803          	ld	a6,0(a5)
ffffffffc0200e8a:	6790                	ld	a2,8(a5)
            base->property += p->property;
ffffffffc0200e8c:	9db5                	addw	a1,a1,a3
ffffffffc0200e8e:	c90c                	sw	a1,16(a0)
            ClearPageProperty(p);
ffffffffc0200e90:	9b75                	andi	a4,a4,-3
ffffffffc0200e92:	fee7b823          	sd	a4,-16(a5)
}
ffffffffc0200e96:	60a2                	ld	ra,8(sp)
    prev->next = next;
ffffffffc0200e98:	00c83423          	sd	a2,8(a6)
    next->prev = prev;
ffffffffc0200e9c:	01063023          	sd	a6,0(a2)
ffffffffc0200ea0:	0141                	addi	sp,sp,16
ffffffffc0200ea2:	8082                	ret
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200ea4:	00001697          	auipc	a3,0x1
ffffffffc0200ea8:	d1c68693          	addi	a3,a3,-740 # ffffffffc0201bc0 <etext+0x55a>
ffffffffc0200eac:	00001617          	auipc	a2,0x1
ffffffffc0200eb0:	a2460613          	addi	a2,a2,-1500 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200eb4:	09100593          	li	a1,145
ffffffffc0200eb8:	00001517          	auipc	a0,0x1
ffffffffc0200ebc:	a3050513          	addi	a0,a0,-1488 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200ec0:	b06ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(n > 0);
ffffffffc0200ec4:	00001697          	auipc	a3,0x1
ffffffffc0200ec8:	a0468693          	addi	a3,a3,-1532 # ffffffffc02018c8 <etext+0x262>
ffffffffc0200ecc:	00001617          	auipc	a2,0x1
ffffffffc0200ed0:	a0460613          	addi	a2,a2,-1532 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200ed4:	08e00593          	li	a1,142
ffffffffc0200ed8:	00001517          	auipc	a0,0x1
ffffffffc0200edc:	a1050513          	addi	a0,a0,-1520 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200ee0:	ae6ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc0200ee4 <best_fit_init_memmap>:
best_fit_init_memmap(struct Page *base, size_t n) {
ffffffffc0200ee4:	1141                	addi	sp,sp,-16
ffffffffc0200ee6:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200ee8:	c5f9                	beqz	a1,ffffffffc0200fb6 <best_fit_init_memmap+0xd2>
    for (; p != base + n; p ++) {
ffffffffc0200eea:	00259693          	slli	a3,a1,0x2
ffffffffc0200eee:	96ae                	add	a3,a3,a1
ffffffffc0200ef0:	068e                	slli	a3,a3,0x3
ffffffffc0200ef2:	96aa                	add	a3,a3,a0
ffffffffc0200ef4:	87aa                	mv	a5,a0
ffffffffc0200ef6:	00d50f63          	beq	a0,a3,ffffffffc0200f14 <best_fit_init_memmap+0x30>
        assert(PageReserved(p));
ffffffffc0200efa:	6798                	ld	a4,8(a5)
ffffffffc0200efc:	8b05                	andi	a4,a4,1
ffffffffc0200efe:	cf41                	beqz	a4,ffffffffc0200f96 <best_fit_init_memmap+0xb2>
        p->flags = p->property = 0;
ffffffffc0200f00:	0007a823          	sw	zero,16(a5)
ffffffffc0200f04:	0007b423          	sd	zero,8(a5)
ffffffffc0200f08:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc0200f0c:	02878793          	addi	a5,a5,40
ffffffffc0200f10:	fed795e3          	bne	a5,a3,ffffffffc0200efa <best_fit_init_memmap+0x16>
    SetPageProperty(base);
ffffffffc0200f14:	6510                	ld	a2,8(a0)
    nr_free += n;
ffffffffc0200f16:	00004697          	auipc	a3,0x4
ffffffffc0200f1a:	10268693          	addi	a3,a3,258 # ffffffffc0205018 <free_area>
ffffffffc0200f1e:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc0200f20:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc0200f22:	00266613          	ori	a2,a2,2
    return list->next == list;
ffffffffc0200f26:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc0200f28:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0200f2a:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc0200f2c:	9db9                	addw	a1,a1,a4
ffffffffc0200f2e:	ca8c                	sw	a1,16(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc0200f30:	01850613          	addi	a2,a0,24
    if (list_empty(&free_list)) {
ffffffffc0200f34:	04d78a63          	beq	a5,a3,ffffffffc0200f88 <best_fit_init_memmap+0xa4>
            struct Page* page = le2page(le, page_link);
ffffffffc0200f38:	fe878713          	addi	a4,a5,-24
ffffffffc0200f3c:	0006b803          	ld	a6,0(a3)
    if (list_empty(&free_list)) {
ffffffffc0200f40:	4581                	li	a1,0
            if (base < page) {
ffffffffc0200f42:	00e56a63          	bltu	a0,a4,ffffffffc0200f56 <best_fit_init_memmap+0x72>
    return listelm->next;
ffffffffc0200f46:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0200f48:	02d70263          	beq	a4,a3,ffffffffc0200f6c <best_fit_init_memmap+0x88>
    for (; p != base + n; p ++) {
ffffffffc0200f4c:	87ba                	mv	a5,a4
            struct Page* page = le2page(le, page_link);
ffffffffc0200f4e:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc0200f52:	fee57ae3          	bgeu	a0,a4,ffffffffc0200f46 <best_fit_init_memmap+0x62>
ffffffffc0200f56:	c199                	beqz	a1,ffffffffc0200f5c <best_fit_init_memmap+0x78>
ffffffffc0200f58:	0106b023          	sd	a6,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200f5c:	6398                	ld	a4,0(a5)
}
ffffffffc0200f5e:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0200f60:	e390                	sd	a2,0(a5)
ffffffffc0200f62:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc0200f64:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200f66:	ed18                	sd	a4,24(a0)
ffffffffc0200f68:	0141                	addi	sp,sp,16
ffffffffc0200f6a:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc0200f6c:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200f6e:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc0200f70:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc0200f72:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc0200f74:	00d70663          	beq	a4,a3,ffffffffc0200f80 <best_fit_init_memmap+0x9c>
    prev->next = next->prev = elm;
ffffffffc0200f78:	8832                	mv	a6,a2
ffffffffc0200f7a:	4585                	li	a1,1
    for (; p != base + n; p ++) {
ffffffffc0200f7c:	87ba                	mv	a5,a4
ffffffffc0200f7e:	bfc1                	j	ffffffffc0200f4e <best_fit_init_memmap+0x6a>
}
ffffffffc0200f80:	60a2                	ld	ra,8(sp)
ffffffffc0200f82:	e290                	sd	a2,0(a3)
ffffffffc0200f84:	0141                	addi	sp,sp,16
ffffffffc0200f86:	8082                	ret
ffffffffc0200f88:	60a2                	ld	ra,8(sp)
ffffffffc0200f8a:	e390                	sd	a2,0(a5)
ffffffffc0200f8c:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200f8e:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200f90:	ed1c                	sd	a5,24(a0)
ffffffffc0200f92:	0141                	addi	sp,sp,16
ffffffffc0200f94:	8082                	ret
        assert(PageReserved(p));
ffffffffc0200f96:	00001697          	auipc	a3,0x1
ffffffffc0200f9a:	c5268693          	addi	a3,a3,-942 # ffffffffc0201be8 <etext+0x582>
ffffffffc0200f9e:	00001617          	auipc	a2,0x1
ffffffffc0200fa2:	93260613          	addi	a2,a2,-1742 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200fa6:	04a00593          	li	a1,74
ffffffffc0200faa:	00001517          	auipc	a0,0x1
ffffffffc0200fae:	93e50513          	addi	a0,a0,-1730 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200fb2:	a14ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(n > 0);
ffffffffc0200fb6:	00001697          	auipc	a3,0x1
ffffffffc0200fba:	91268693          	addi	a3,a3,-1774 # ffffffffc02018c8 <etext+0x262>
ffffffffc0200fbe:	00001617          	auipc	a2,0x1
ffffffffc0200fc2:	91260613          	addi	a2,a2,-1774 # ffffffffc02018d0 <etext+0x26a>
ffffffffc0200fc6:	04700593          	li	a1,71
ffffffffc0200fca:	00001517          	auipc	a0,0x1
ffffffffc0200fce:	91e50513          	addi	a0,a0,-1762 # ffffffffc02018e8 <etext+0x282>
ffffffffc0200fd2:	9f4ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc0200fd6 <alloc_pages>:
}

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n) {
    return pmm_manager->alloc_pages(n);
ffffffffc0200fd6:	00004797          	auipc	a5,0x4
ffffffffc0200fda:	0827b783          	ld	a5,130(a5) # ffffffffc0205058 <pmm_manager>
ffffffffc0200fde:	6f9c                	ld	a5,24(a5)
ffffffffc0200fe0:	8782                	jr	a5

ffffffffc0200fe2 <free_pages>:
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
ffffffffc0200fe2:	00004797          	auipc	a5,0x4
ffffffffc0200fe6:	0767b783          	ld	a5,118(a5) # ffffffffc0205058 <pmm_manager>
ffffffffc0200fea:	739c                	ld	a5,32(a5)
ffffffffc0200fec:	8782                	jr	a5

ffffffffc0200fee <nr_free_pages>:
}

// nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE)
// of current free memory
size_t nr_free_pages(void) {
    return pmm_manager->nr_free_pages();
ffffffffc0200fee:	00004797          	auipc	a5,0x4
ffffffffc0200ff2:	06a7b783          	ld	a5,106(a5) # ffffffffc0205058 <pmm_manager>
ffffffffc0200ff6:	779c                	ld	a5,40(a5)
ffffffffc0200ff8:	8782                	jr	a5

ffffffffc0200ffa <pmm_init>:
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0200ffa:	00001797          	auipc	a5,0x1
ffffffffc0200ffe:	c1678793          	addi	a5,a5,-1002 # ffffffffc0201c10 <best_fit_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201002:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
    }
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc0201004:	7179                	addi	sp,sp,-48
ffffffffc0201006:	f022                	sd	s0,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201008:	00001517          	auipc	a0,0x1
ffffffffc020100c:	c4050513          	addi	a0,a0,-960 # ffffffffc0201c48 <best_fit_pmm_manager+0x38>
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0201010:	00004417          	auipc	s0,0x4
ffffffffc0201014:	04840413          	addi	s0,s0,72 # ffffffffc0205058 <pmm_manager>
void pmm_init(void) {
ffffffffc0201018:	f406                	sd	ra,40(sp)
ffffffffc020101a:	ec26                	sd	s1,24(sp)
ffffffffc020101c:	e44e                	sd	s3,8(sp)
ffffffffc020101e:	e84a                	sd	s2,16(sp)
ffffffffc0201020:	e052                	sd	s4,0(sp)
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0201022:	e01c                	sd	a5,0(s0)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201024:	92cff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    pmm_manager->init();
ffffffffc0201028:	601c                	ld	a5,0(s0)
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc020102a:	00004497          	auipc	s1,0x4
ffffffffc020102e:	04648493          	addi	s1,s1,70 # ffffffffc0205070 <va_pa_offset>
    pmm_manager->init();
ffffffffc0201032:	679c                	ld	a5,8(a5)
ffffffffc0201034:	9782                	jalr	a5
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201036:	57f5                	li	a5,-3
ffffffffc0201038:	07fa                	slli	a5,a5,0x1e
ffffffffc020103a:	e09c                	sd	a5,0(s1)
    uint64_t mem_begin = get_memory_base();
ffffffffc020103c:	d84ff0ef          	jal	ra,ffffffffc02005c0 <get_memory_base>
ffffffffc0201040:	89aa                	mv	s3,a0
    uint64_t mem_size  = get_memory_size();
ffffffffc0201042:	d88ff0ef          	jal	ra,ffffffffc02005ca <get_memory_size>
    if (mem_size == 0) {
ffffffffc0201046:	14050d63          	beqz	a0,ffffffffc02011a0 <pmm_init+0x1a6>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc020104a:	892a                	mv	s2,a0
    cprintf("physcial memory map:\n");
ffffffffc020104c:	00001517          	auipc	a0,0x1
ffffffffc0201050:	c4450513          	addi	a0,a0,-956 # ffffffffc0201c90 <best_fit_pmm_manager+0x80>
ffffffffc0201054:	8fcff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0201058:	01298a33          	add	s4,s3,s2
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n", mem_size, mem_begin,
ffffffffc020105c:	864e                	mv	a2,s3
ffffffffc020105e:	fffa0693          	addi	a3,s4,-1
ffffffffc0201062:	85ca                	mv	a1,s2
ffffffffc0201064:	00001517          	auipc	a0,0x1
ffffffffc0201068:	c4450513          	addi	a0,a0,-956 # ffffffffc0201ca8 <best_fit_pmm_manager+0x98>
ffffffffc020106c:	8e4ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0201070:	c80007b7          	lui	a5,0xc8000
ffffffffc0201074:	8652                	mv	a2,s4
ffffffffc0201076:	0d47e463          	bltu	a5,s4,ffffffffc020113e <pmm_init+0x144>
ffffffffc020107a:	00005797          	auipc	a5,0x5
ffffffffc020107e:	ffd78793          	addi	a5,a5,-3 # ffffffffc0206077 <end+0xfff>
ffffffffc0201082:	757d                	lui	a0,0xfffff
ffffffffc0201084:	8d7d                	and	a0,a0,a5
ffffffffc0201086:	8231                	srli	a2,a2,0xc
ffffffffc0201088:	00004797          	auipc	a5,0x4
ffffffffc020108c:	fcc7b023          	sd	a2,-64(a5) # ffffffffc0205048 <npage>
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc0201090:	00004797          	auipc	a5,0x4
ffffffffc0201094:	fca7b023          	sd	a0,-64(a5) # ffffffffc0205050 <pages>
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0201098:	000807b7          	lui	a5,0x80
ffffffffc020109c:	002005b7          	lui	a1,0x200
ffffffffc02010a0:	02f60563          	beq	a2,a5,ffffffffc02010ca <pmm_init+0xd0>
ffffffffc02010a4:	00261593          	slli	a1,a2,0x2
ffffffffc02010a8:	00c586b3          	add	a3,a1,a2
ffffffffc02010ac:	fec007b7          	lui	a5,0xfec00
ffffffffc02010b0:	97aa                	add	a5,a5,a0
ffffffffc02010b2:	068e                	slli	a3,a3,0x3
ffffffffc02010b4:	96be                	add	a3,a3,a5
ffffffffc02010b6:	87aa                	mv	a5,a0
        SetPageReserved(pages + i);
ffffffffc02010b8:	6798                	ld	a4,8(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc02010ba:	02878793          	addi	a5,a5,40 # fffffffffec00028 <end+0x3e9fafb0>
        SetPageReserved(pages + i);
ffffffffc02010be:	00176713          	ori	a4,a4,1
ffffffffc02010c2:	fee7b023          	sd	a4,-32(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc02010c6:	fef699e3          	bne	a3,a5,ffffffffc02010b8 <pmm_init+0xbe>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc02010ca:	95b2                	add	a1,a1,a2
ffffffffc02010cc:	fec006b7          	lui	a3,0xfec00
ffffffffc02010d0:	96aa                	add	a3,a3,a0
ffffffffc02010d2:	058e                	slli	a1,a1,0x3
ffffffffc02010d4:	96ae                	add	a3,a3,a1
ffffffffc02010d6:	c02007b7          	lui	a5,0xc0200
ffffffffc02010da:	0af6e763          	bltu	a3,a5,ffffffffc0201188 <pmm_init+0x18e>
ffffffffc02010de:	6098                	ld	a4,0(s1)
    mem_end = ROUNDDOWN(mem_end, PGSIZE);
ffffffffc02010e0:	77fd                	lui	a5,0xfffff
ffffffffc02010e2:	00fa75b3          	and	a1,s4,a5
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc02010e6:	8e99                	sub	a3,a3,a4
    if (freemem < mem_end) {
ffffffffc02010e8:	04b6ee63          	bltu	a3,a1,ffffffffc0201144 <pmm_init+0x14a>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc02010ec:	601c                	ld	a5,0(s0)
ffffffffc02010ee:	7b9c                	ld	a5,48(a5)
ffffffffc02010f0:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc02010f2:	00001517          	auipc	a0,0x1
ffffffffc02010f6:	c3e50513          	addi	a0,a0,-962 # ffffffffc0201d30 <best_fit_pmm_manager+0x120>
ffffffffc02010fa:	856ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc02010fe:	00003597          	auipc	a1,0x3
ffffffffc0201102:	f0258593          	addi	a1,a1,-254 # ffffffffc0204000 <boot_page_table_sv39>
ffffffffc0201106:	00004797          	auipc	a5,0x4
ffffffffc020110a:	f6b7b123          	sd	a1,-158(a5) # ffffffffc0205068 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc020110e:	c02007b7          	lui	a5,0xc0200
ffffffffc0201112:	0af5e363          	bltu	a1,a5,ffffffffc02011b8 <pmm_init+0x1be>
ffffffffc0201116:	6090                	ld	a2,0(s1)
}
ffffffffc0201118:	7402                	ld	s0,32(sp)
ffffffffc020111a:	70a2                	ld	ra,40(sp)
ffffffffc020111c:	64e2                	ld	s1,24(sp)
ffffffffc020111e:	6942                	ld	s2,16(sp)
ffffffffc0201120:	69a2                	ld	s3,8(sp)
ffffffffc0201122:	6a02                	ld	s4,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc0201124:	40c58633          	sub	a2,a1,a2
ffffffffc0201128:	00004797          	auipc	a5,0x4
ffffffffc020112c:	f2c7bc23          	sd	a2,-200(a5) # ffffffffc0205060 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0201130:	00001517          	auipc	a0,0x1
ffffffffc0201134:	c2050513          	addi	a0,a0,-992 # ffffffffc0201d50 <best_fit_pmm_manager+0x140>
}
ffffffffc0201138:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc020113a:	816ff06f          	j	ffffffffc0200150 <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc020113e:	c8000637          	lui	a2,0xc8000
ffffffffc0201142:	bf25                	j	ffffffffc020107a <pmm_init+0x80>
    mem_begin = ROUNDUP(freemem, PGSIZE);
ffffffffc0201144:	6705                	lui	a4,0x1
ffffffffc0201146:	177d                	addi	a4,a4,-1
ffffffffc0201148:	96ba                	add	a3,a3,a4
ffffffffc020114a:	8efd                	and	a3,a3,a5
    return page->ref;
}

// 将物理地址转换为页结构指针
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc020114c:	00c6d793          	srli	a5,a3,0xc
ffffffffc0201150:	02c7f063          	bgeu	a5,a2,ffffffffc0201170 <pmm_init+0x176>
    pmm_manager->init_memmap(base, n);
ffffffffc0201154:	6010                	ld	a2,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc0201156:	fff80737          	lui	a4,0xfff80
ffffffffc020115a:	973e                	add	a4,a4,a5
ffffffffc020115c:	00271793          	slli	a5,a4,0x2
ffffffffc0201160:	97ba                	add	a5,a5,a4
ffffffffc0201162:	6a18                	ld	a4,16(a2)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
ffffffffc0201164:	8d95                	sub	a1,a1,a3
ffffffffc0201166:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc0201168:	81b1                	srli	a1,a1,0xc
ffffffffc020116a:	953e                	add	a0,a0,a5
ffffffffc020116c:	9702                	jalr	a4
}
ffffffffc020116e:	bfbd                	j	ffffffffc02010ec <pmm_init+0xf2>
        panic("pa2page called with invalid pa");
ffffffffc0201170:	00001617          	auipc	a2,0x1
ffffffffc0201174:	b9060613          	addi	a2,a2,-1136 # ffffffffc0201d00 <best_fit_pmm_manager+0xf0>
ffffffffc0201178:	06a00593          	li	a1,106
ffffffffc020117c:	00001517          	auipc	a0,0x1
ffffffffc0201180:	ba450513          	addi	a0,a0,-1116 # ffffffffc0201d20 <best_fit_pmm_manager+0x110>
ffffffffc0201184:	842ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc0201188:	00001617          	auipc	a2,0x1
ffffffffc020118c:	b5060613          	addi	a2,a2,-1200 # ffffffffc0201cd8 <best_fit_pmm_manager+0xc8>
ffffffffc0201190:	05e00593          	li	a1,94
ffffffffc0201194:	00001517          	auipc	a0,0x1
ffffffffc0201198:	aec50513          	addi	a0,a0,-1300 # ffffffffc0201c80 <best_fit_pmm_manager+0x70>
ffffffffc020119c:	82aff0ef          	jal	ra,ffffffffc02001c6 <__panic>
        panic("DTB memory info not available");
ffffffffc02011a0:	00001617          	auipc	a2,0x1
ffffffffc02011a4:	ac060613          	addi	a2,a2,-1344 # ffffffffc0201c60 <best_fit_pmm_manager+0x50>
ffffffffc02011a8:	04600593          	li	a1,70
ffffffffc02011ac:	00001517          	auipc	a0,0x1
ffffffffc02011b0:	ad450513          	addi	a0,a0,-1324 # ffffffffc0201c80 <best_fit_pmm_manager+0x70>
ffffffffc02011b4:	812ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc02011b8:	86ae                	mv	a3,a1
ffffffffc02011ba:	00001617          	auipc	a2,0x1
ffffffffc02011be:	b1e60613          	addi	a2,a2,-1250 # ffffffffc0201cd8 <best_fit_pmm_manager+0xc8>
ffffffffc02011c2:	07a00593          	li	a1,122
ffffffffc02011c6:	00001517          	auipc	a0,0x1
ffffffffc02011ca:	aba50513          	addi	a0,a0,-1350 # ffffffffc0201c80 <best_fit_pmm_manager+0x70>
ffffffffc02011ce:	ff9fe0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc02011d2 <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc02011d2:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02011d6:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc02011d8:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02011dc:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc02011de:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02011e2:	f022                	sd	s0,32(sp)
ffffffffc02011e4:	ec26                	sd	s1,24(sp)
ffffffffc02011e6:	e84a                	sd	s2,16(sp)
ffffffffc02011e8:	f406                	sd	ra,40(sp)
ffffffffc02011ea:	e44e                	sd	s3,8(sp)
ffffffffc02011ec:	84aa                	mv	s1,a0
ffffffffc02011ee:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc02011f0:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc02011f4:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc02011f6:	03067e63          	bgeu	a2,a6,ffffffffc0201232 <printnum+0x60>
ffffffffc02011fa:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc02011fc:	00805763          	blez	s0,ffffffffc020120a <printnum+0x38>
ffffffffc0201200:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc0201202:	85ca                	mv	a1,s2
ffffffffc0201204:	854e                	mv	a0,s3
ffffffffc0201206:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc0201208:	fc65                	bnez	s0,ffffffffc0201200 <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc020120a:	1a02                	slli	s4,s4,0x20
ffffffffc020120c:	00001797          	auipc	a5,0x1
ffffffffc0201210:	b8478793          	addi	a5,a5,-1148 # ffffffffc0201d90 <best_fit_pmm_manager+0x180>
ffffffffc0201214:	020a5a13          	srli	s4,s4,0x20
ffffffffc0201218:	9a3e                	add	s4,s4,a5
}
ffffffffc020121a:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc020121c:	000a4503          	lbu	a0,0(s4)
}
ffffffffc0201220:	70a2                	ld	ra,40(sp)
ffffffffc0201222:	69a2                	ld	s3,8(sp)
ffffffffc0201224:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201226:	85ca                	mv	a1,s2
ffffffffc0201228:	87a6                	mv	a5,s1
}
ffffffffc020122a:	6942                	ld	s2,16(sp)
ffffffffc020122c:	64e2                	ld	s1,24(sp)
ffffffffc020122e:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201230:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc0201232:	03065633          	divu	a2,a2,a6
ffffffffc0201236:	8722                	mv	a4,s0
ffffffffc0201238:	f9bff0ef          	jal	ra,ffffffffc02011d2 <printnum>
ffffffffc020123c:	b7f9                	j	ffffffffc020120a <printnum+0x38>

ffffffffc020123e <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc020123e:	7119                	addi	sp,sp,-128
ffffffffc0201240:	f4a6                	sd	s1,104(sp)
ffffffffc0201242:	f0ca                	sd	s2,96(sp)
ffffffffc0201244:	ecce                	sd	s3,88(sp)
ffffffffc0201246:	e8d2                	sd	s4,80(sp)
ffffffffc0201248:	e4d6                	sd	s5,72(sp)
ffffffffc020124a:	e0da                	sd	s6,64(sp)
ffffffffc020124c:	fc5e                	sd	s7,56(sp)
ffffffffc020124e:	f06a                	sd	s10,32(sp)
ffffffffc0201250:	fc86                	sd	ra,120(sp)
ffffffffc0201252:	f8a2                	sd	s0,112(sp)
ffffffffc0201254:	f862                	sd	s8,48(sp)
ffffffffc0201256:	f466                	sd	s9,40(sp)
ffffffffc0201258:	ec6e                	sd	s11,24(sp)
ffffffffc020125a:	892a                	mv	s2,a0
ffffffffc020125c:	84ae                	mv	s1,a1
ffffffffc020125e:	8d32                	mv	s10,a2
ffffffffc0201260:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201262:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc0201266:	5b7d                	li	s6,-1
ffffffffc0201268:	00001a97          	auipc	s5,0x1
ffffffffc020126c:	b5ca8a93          	addi	s5,s5,-1188 # ffffffffc0201dc4 <best_fit_pmm_manager+0x1b4>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201270:	00001b97          	auipc	s7,0x1
ffffffffc0201274:	d30b8b93          	addi	s7,s7,-720 # ffffffffc0201fa0 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201278:	000d4503          	lbu	a0,0(s10)
ffffffffc020127c:	001d0413          	addi	s0,s10,1
ffffffffc0201280:	01350a63          	beq	a0,s3,ffffffffc0201294 <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc0201284:	c121                	beqz	a0,ffffffffc02012c4 <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc0201286:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201288:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc020128a:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020128c:	fff44503          	lbu	a0,-1(s0)
ffffffffc0201290:	ff351ae3          	bne	a0,s3,ffffffffc0201284 <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201294:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc0201298:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc020129c:	4c81                	li	s9,0
ffffffffc020129e:	4881                	li	a7,0
        width = precision = -1;
ffffffffc02012a0:	5c7d                	li	s8,-1
ffffffffc02012a2:	5dfd                	li	s11,-1
ffffffffc02012a4:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc02012a8:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02012aa:	fdd6059b          	addiw	a1,a2,-35
ffffffffc02012ae:	0ff5f593          	zext.b	a1,a1
ffffffffc02012b2:	00140d13          	addi	s10,s0,1
ffffffffc02012b6:	04b56263          	bltu	a0,a1,ffffffffc02012fa <vprintfmt+0xbc>
ffffffffc02012ba:	058a                	slli	a1,a1,0x2
ffffffffc02012bc:	95d6                	add	a1,a1,s5
ffffffffc02012be:	4194                	lw	a3,0(a1)
ffffffffc02012c0:	96d6                	add	a3,a3,s5
ffffffffc02012c2:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc02012c4:	70e6                	ld	ra,120(sp)
ffffffffc02012c6:	7446                	ld	s0,112(sp)
ffffffffc02012c8:	74a6                	ld	s1,104(sp)
ffffffffc02012ca:	7906                	ld	s2,96(sp)
ffffffffc02012cc:	69e6                	ld	s3,88(sp)
ffffffffc02012ce:	6a46                	ld	s4,80(sp)
ffffffffc02012d0:	6aa6                	ld	s5,72(sp)
ffffffffc02012d2:	6b06                	ld	s6,64(sp)
ffffffffc02012d4:	7be2                	ld	s7,56(sp)
ffffffffc02012d6:	7c42                	ld	s8,48(sp)
ffffffffc02012d8:	7ca2                	ld	s9,40(sp)
ffffffffc02012da:	7d02                	ld	s10,32(sp)
ffffffffc02012dc:	6de2                	ld	s11,24(sp)
ffffffffc02012de:	6109                	addi	sp,sp,128
ffffffffc02012e0:	8082                	ret
            padc = '0';
ffffffffc02012e2:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc02012e4:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02012e8:	846a                	mv	s0,s10
ffffffffc02012ea:	00140d13          	addi	s10,s0,1
ffffffffc02012ee:	fdd6059b          	addiw	a1,a2,-35
ffffffffc02012f2:	0ff5f593          	zext.b	a1,a1
ffffffffc02012f6:	fcb572e3          	bgeu	a0,a1,ffffffffc02012ba <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc02012fa:	85a6                	mv	a1,s1
ffffffffc02012fc:	02500513          	li	a0,37
ffffffffc0201300:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc0201302:	fff44783          	lbu	a5,-1(s0)
ffffffffc0201306:	8d22                	mv	s10,s0
ffffffffc0201308:	f73788e3          	beq	a5,s3,ffffffffc0201278 <vprintfmt+0x3a>
ffffffffc020130c:	ffed4783          	lbu	a5,-2(s10)
ffffffffc0201310:	1d7d                	addi	s10,s10,-1
ffffffffc0201312:	ff379de3          	bne	a5,s3,ffffffffc020130c <vprintfmt+0xce>
ffffffffc0201316:	b78d                	j	ffffffffc0201278 <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc0201318:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc020131c:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201320:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc0201322:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc0201326:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc020132a:	02d86463          	bltu	a6,a3,ffffffffc0201352 <vprintfmt+0x114>
                ch = *fmt;
ffffffffc020132e:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0201332:	002c169b          	slliw	a3,s8,0x2
ffffffffc0201336:	0186873b          	addw	a4,a3,s8
ffffffffc020133a:	0017171b          	slliw	a4,a4,0x1
ffffffffc020133e:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc0201340:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0201344:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc0201346:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc020134a:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc020134e:	fed870e3          	bgeu	a6,a3,ffffffffc020132e <vprintfmt+0xf0>
            if (width < 0)
ffffffffc0201352:	f40ddce3          	bgez	s11,ffffffffc02012aa <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc0201356:	8de2                	mv	s11,s8
ffffffffc0201358:	5c7d                	li	s8,-1
ffffffffc020135a:	bf81                	j	ffffffffc02012aa <vprintfmt+0x6c>
            if (width < 0)
ffffffffc020135c:	fffdc693          	not	a3,s11
ffffffffc0201360:	96fd                	srai	a3,a3,0x3f
ffffffffc0201362:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201366:	00144603          	lbu	a2,1(s0)
ffffffffc020136a:	2d81                	sext.w	s11,s11
ffffffffc020136c:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc020136e:	bf35                	j	ffffffffc02012aa <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc0201370:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201374:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc0201378:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020137a:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc020137c:	bfd9                	j	ffffffffc0201352 <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc020137e:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201380:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201384:	01174463          	blt	a4,a7,ffffffffc020138c <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc0201388:	1a088e63          	beqz	a7,ffffffffc0201544 <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc020138c:	000a3603          	ld	a2,0(s4)
ffffffffc0201390:	46c1                	li	a3,16
ffffffffc0201392:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc0201394:	2781                	sext.w	a5,a5
ffffffffc0201396:	876e                	mv	a4,s11
ffffffffc0201398:	85a6                	mv	a1,s1
ffffffffc020139a:	854a                	mv	a0,s2
ffffffffc020139c:	e37ff0ef          	jal	ra,ffffffffc02011d2 <printnum>
            break;
ffffffffc02013a0:	bde1                	j	ffffffffc0201278 <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc02013a2:	000a2503          	lw	a0,0(s4)
ffffffffc02013a6:	85a6                	mv	a1,s1
ffffffffc02013a8:	0a21                	addi	s4,s4,8
ffffffffc02013aa:	9902                	jalr	s2
            break;
ffffffffc02013ac:	b5f1                	j	ffffffffc0201278 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc02013ae:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02013b0:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02013b4:	01174463          	blt	a4,a7,ffffffffc02013bc <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc02013b8:	18088163          	beqz	a7,ffffffffc020153a <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc02013bc:	000a3603          	ld	a2,0(s4)
ffffffffc02013c0:	46a9                	li	a3,10
ffffffffc02013c2:	8a2e                	mv	s4,a1
ffffffffc02013c4:	bfc1                	j	ffffffffc0201394 <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013c6:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc02013ca:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013cc:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02013ce:	bdf1                	j	ffffffffc02012aa <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc02013d0:	85a6                	mv	a1,s1
ffffffffc02013d2:	02500513          	li	a0,37
ffffffffc02013d6:	9902                	jalr	s2
            break;
ffffffffc02013d8:	b545                	j	ffffffffc0201278 <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013da:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc02013de:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013e0:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02013e2:	b5e1                	j	ffffffffc02012aa <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc02013e4:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02013e6:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02013ea:	01174463          	blt	a4,a7,ffffffffc02013f2 <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc02013ee:	14088163          	beqz	a7,ffffffffc0201530 <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc02013f2:	000a3603          	ld	a2,0(s4)
ffffffffc02013f6:	46a1                	li	a3,8
ffffffffc02013f8:	8a2e                	mv	s4,a1
ffffffffc02013fa:	bf69                	j	ffffffffc0201394 <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc02013fc:	03000513          	li	a0,48
ffffffffc0201400:	85a6                	mv	a1,s1
ffffffffc0201402:	e03e                	sd	a5,0(sp)
ffffffffc0201404:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc0201406:	85a6                	mv	a1,s1
ffffffffc0201408:	07800513          	li	a0,120
ffffffffc020140c:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc020140e:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc0201410:	6782                	ld	a5,0(sp)
ffffffffc0201412:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201414:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc0201418:	bfb5                	j	ffffffffc0201394 <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc020141a:	000a3403          	ld	s0,0(s4)
ffffffffc020141e:	008a0713          	addi	a4,s4,8
ffffffffc0201422:	e03a                	sd	a4,0(sp)
ffffffffc0201424:	14040263          	beqz	s0,ffffffffc0201568 <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc0201428:	0fb05763          	blez	s11,ffffffffc0201516 <vprintfmt+0x2d8>
ffffffffc020142c:	02d00693          	li	a3,45
ffffffffc0201430:	0cd79163          	bne	a5,a3,ffffffffc02014f2 <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201434:	00044783          	lbu	a5,0(s0)
ffffffffc0201438:	0007851b          	sext.w	a0,a5
ffffffffc020143c:	cf85                	beqz	a5,ffffffffc0201474 <vprintfmt+0x236>
ffffffffc020143e:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201442:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201446:	000c4563          	bltz	s8,ffffffffc0201450 <vprintfmt+0x212>
ffffffffc020144a:	3c7d                	addiw	s8,s8,-1
ffffffffc020144c:	036c0263          	beq	s8,s6,ffffffffc0201470 <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc0201450:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201452:	0e0c8e63          	beqz	s9,ffffffffc020154e <vprintfmt+0x310>
ffffffffc0201456:	3781                	addiw	a5,a5,-32
ffffffffc0201458:	0ef47b63          	bgeu	s0,a5,ffffffffc020154e <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc020145c:	03f00513          	li	a0,63
ffffffffc0201460:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201462:	000a4783          	lbu	a5,0(s4)
ffffffffc0201466:	3dfd                	addiw	s11,s11,-1
ffffffffc0201468:	0a05                	addi	s4,s4,1
ffffffffc020146a:	0007851b          	sext.w	a0,a5
ffffffffc020146e:	ffe1                	bnez	a5,ffffffffc0201446 <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc0201470:	01b05963          	blez	s11,ffffffffc0201482 <vprintfmt+0x244>
ffffffffc0201474:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc0201476:	85a6                	mv	a1,s1
ffffffffc0201478:	02000513          	li	a0,32
ffffffffc020147c:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc020147e:	fe0d9be3          	bnez	s11,ffffffffc0201474 <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201482:	6a02                	ld	s4,0(sp)
ffffffffc0201484:	bbd5                	j	ffffffffc0201278 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201486:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201488:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc020148c:	01174463          	blt	a4,a7,ffffffffc0201494 <vprintfmt+0x256>
    else if (lflag) {
ffffffffc0201490:	08088d63          	beqz	a7,ffffffffc020152a <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc0201494:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc0201498:	0a044d63          	bltz	s0,ffffffffc0201552 <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc020149c:	8622                	mv	a2,s0
ffffffffc020149e:	8a66                	mv	s4,s9
ffffffffc02014a0:	46a9                	li	a3,10
ffffffffc02014a2:	bdcd                	j	ffffffffc0201394 <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc02014a4:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc02014a8:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc02014aa:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc02014ac:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc02014b0:	8fb5                	xor	a5,a5,a3
ffffffffc02014b2:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc02014b6:	02d74163          	blt	a4,a3,ffffffffc02014d8 <vprintfmt+0x29a>
ffffffffc02014ba:	00369793          	slli	a5,a3,0x3
ffffffffc02014be:	97de                	add	a5,a5,s7
ffffffffc02014c0:	639c                	ld	a5,0(a5)
ffffffffc02014c2:	cb99                	beqz	a5,ffffffffc02014d8 <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc02014c4:	86be                	mv	a3,a5
ffffffffc02014c6:	00001617          	auipc	a2,0x1
ffffffffc02014ca:	8fa60613          	addi	a2,a2,-1798 # ffffffffc0201dc0 <best_fit_pmm_manager+0x1b0>
ffffffffc02014ce:	85a6                	mv	a1,s1
ffffffffc02014d0:	854a                	mv	a0,s2
ffffffffc02014d2:	0ce000ef          	jal	ra,ffffffffc02015a0 <printfmt>
ffffffffc02014d6:	b34d                	j	ffffffffc0201278 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc02014d8:	00001617          	auipc	a2,0x1
ffffffffc02014dc:	8d860613          	addi	a2,a2,-1832 # ffffffffc0201db0 <best_fit_pmm_manager+0x1a0>
ffffffffc02014e0:	85a6                	mv	a1,s1
ffffffffc02014e2:	854a                	mv	a0,s2
ffffffffc02014e4:	0bc000ef          	jal	ra,ffffffffc02015a0 <printfmt>
ffffffffc02014e8:	bb41                	j	ffffffffc0201278 <vprintfmt+0x3a>
                p = "(null)";
ffffffffc02014ea:	00001417          	auipc	s0,0x1
ffffffffc02014ee:	8be40413          	addi	s0,s0,-1858 # ffffffffc0201da8 <best_fit_pmm_manager+0x198>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02014f2:	85e2                	mv	a1,s8
ffffffffc02014f4:	8522                	mv	a0,s0
ffffffffc02014f6:	e43e                	sd	a5,8(sp)
ffffffffc02014f8:	0fc000ef          	jal	ra,ffffffffc02015f4 <strnlen>
ffffffffc02014fc:	40ad8dbb          	subw	s11,s11,a0
ffffffffc0201500:	01b05b63          	blez	s11,ffffffffc0201516 <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc0201504:	67a2                	ld	a5,8(sp)
ffffffffc0201506:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc020150a:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc020150c:	85a6                	mv	a1,s1
ffffffffc020150e:	8552                	mv	a0,s4
ffffffffc0201510:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201512:	fe0d9ce3          	bnez	s11,ffffffffc020150a <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201516:	00044783          	lbu	a5,0(s0)
ffffffffc020151a:	00140a13          	addi	s4,s0,1
ffffffffc020151e:	0007851b          	sext.w	a0,a5
ffffffffc0201522:	d3a5                	beqz	a5,ffffffffc0201482 <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201524:	05e00413          	li	s0,94
ffffffffc0201528:	bf39                	j	ffffffffc0201446 <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc020152a:	000a2403          	lw	s0,0(s4)
ffffffffc020152e:	b7ad                	j	ffffffffc0201498 <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc0201530:	000a6603          	lwu	a2,0(s4)
ffffffffc0201534:	46a1                	li	a3,8
ffffffffc0201536:	8a2e                	mv	s4,a1
ffffffffc0201538:	bdb1                	j	ffffffffc0201394 <vprintfmt+0x156>
ffffffffc020153a:	000a6603          	lwu	a2,0(s4)
ffffffffc020153e:	46a9                	li	a3,10
ffffffffc0201540:	8a2e                	mv	s4,a1
ffffffffc0201542:	bd89                	j	ffffffffc0201394 <vprintfmt+0x156>
ffffffffc0201544:	000a6603          	lwu	a2,0(s4)
ffffffffc0201548:	46c1                	li	a3,16
ffffffffc020154a:	8a2e                	mv	s4,a1
ffffffffc020154c:	b5a1                	j	ffffffffc0201394 <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc020154e:	9902                	jalr	s2
ffffffffc0201550:	bf09                	j	ffffffffc0201462 <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc0201552:	85a6                	mv	a1,s1
ffffffffc0201554:	02d00513          	li	a0,45
ffffffffc0201558:	e03e                	sd	a5,0(sp)
ffffffffc020155a:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc020155c:	6782                	ld	a5,0(sp)
ffffffffc020155e:	8a66                	mv	s4,s9
ffffffffc0201560:	40800633          	neg	a2,s0
ffffffffc0201564:	46a9                	li	a3,10
ffffffffc0201566:	b53d                	j	ffffffffc0201394 <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc0201568:	03b05163          	blez	s11,ffffffffc020158a <vprintfmt+0x34c>
ffffffffc020156c:	02d00693          	li	a3,45
ffffffffc0201570:	f6d79de3          	bne	a5,a3,ffffffffc02014ea <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc0201574:	00001417          	auipc	s0,0x1
ffffffffc0201578:	83440413          	addi	s0,s0,-1996 # ffffffffc0201da8 <best_fit_pmm_manager+0x198>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc020157c:	02800793          	li	a5,40
ffffffffc0201580:	02800513          	li	a0,40
ffffffffc0201584:	00140a13          	addi	s4,s0,1
ffffffffc0201588:	bd6d                	j	ffffffffc0201442 <vprintfmt+0x204>
ffffffffc020158a:	00001a17          	auipc	s4,0x1
ffffffffc020158e:	81fa0a13          	addi	s4,s4,-2017 # ffffffffc0201da9 <best_fit_pmm_manager+0x199>
ffffffffc0201592:	02800513          	li	a0,40
ffffffffc0201596:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc020159a:	05e00413          	li	s0,94
ffffffffc020159e:	b565                	j	ffffffffc0201446 <vprintfmt+0x208>

ffffffffc02015a0 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02015a0:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc02015a2:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02015a6:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc02015a8:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02015aa:	ec06                	sd	ra,24(sp)
ffffffffc02015ac:	f83a                	sd	a4,48(sp)
ffffffffc02015ae:	fc3e                	sd	a5,56(sp)
ffffffffc02015b0:	e0c2                	sd	a6,64(sp)
ffffffffc02015b2:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc02015b4:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc02015b6:	c89ff0ef          	jal	ra,ffffffffc020123e <vprintfmt>
}
ffffffffc02015ba:	60e2                	ld	ra,24(sp)
ffffffffc02015bc:	6161                	addi	sp,sp,80
ffffffffc02015be:	8082                	ret

ffffffffc02015c0 <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc02015c0:	4781                	li	a5,0
ffffffffc02015c2:	00004717          	auipc	a4,0x4
ffffffffc02015c6:	a4e73703          	ld	a4,-1458(a4) # ffffffffc0205010 <SBI_CONSOLE_PUTCHAR>
ffffffffc02015ca:	88ba                	mv	a7,a4
ffffffffc02015cc:	852a                	mv	a0,a0
ffffffffc02015ce:	85be                	mv	a1,a5
ffffffffc02015d0:	863e                	mv	a2,a5
ffffffffc02015d2:	00000073          	ecall
ffffffffc02015d6:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc02015d8:	8082                	ret

ffffffffc02015da <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc02015da:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc02015de:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc02015e0:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc02015e2:	cb81                	beqz	a5,ffffffffc02015f2 <strlen+0x18>
        cnt ++;
ffffffffc02015e4:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc02015e6:	00a707b3          	add	a5,a4,a0
ffffffffc02015ea:	0007c783          	lbu	a5,0(a5)
ffffffffc02015ee:	fbfd                	bnez	a5,ffffffffc02015e4 <strlen+0xa>
ffffffffc02015f0:	8082                	ret
    }
    return cnt;
}
ffffffffc02015f2:	8082                	ret

ffffffffc02015f4 <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc02015f4:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc02015f6:	e589                	bnez	a1,ffffffffc0201600 <strnlen+0xc>
ffffffffc02015f8:	a811                	j	ffffffffc020160c <strnlen+0x18>
        cnt ++;
ffffffffc02015fa:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc02015fc:	00f58863          	beq	a1,a5,ffffffffc020160c <strnlen+0x18>
ffffffffc0201600:	00f50733          	add	a4,a0,a5
ffffffffc0201604:	00074703          	lbu	a4,0(a4)
ffffffffc0201608:	fb6d                	bnez	a4,ffffffffc02015fa <strnlen+0x6>
ffffffffc020160a:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc020160c:	852e                	mv	a0,a1
ffffffffc020160e:	8082                	ret

ffffffffc0201610 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201610:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201614:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201618:	cb89                	beqz	a5,ffffffffc020162a <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc020161a:	0505                	addi	a0,a0,1
ffffffffc020161c:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc020161e:	fee789e3          	beq	a5,a4,ffffffffc0201610 <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201622:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc0201626:	9d19                	subw	a0,a0,a4
ffffffffc0201628:	8082                	ret
ffffffffc020162a:	4501                	li	a0,0
ffffffffc020162c:	bfed                	j	ffffffffc0201626 <strcmp+0x16>

ffffffffc020162e <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020162e:	c20d                	beqz	a2,ffffffffc0201650 <strncmp+0x22>
ffffffffc0201630:	962e                	add	a2,a2,a1
ffffffffc0201632:	a031                	j	ffffffffc020163e <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc0201634:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201636:	00e79a63          	bne	a5,a4,ffffffffc020164a <strncmp+0x1c>
ffffffffc020163a:	00b60b63          	beq	a2,a1,ffffffffc0201650 <strncmp+0x22>
ffffffffc020163e:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc0201642:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201644:	fff5c703          	lbu	a4,-1(a1)
ffffffffc0201648:	f7f5                	bnez	a5,ffffffffc0201634 <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020164a:	40e7853b          	subw	a0,a5,a4
}
ffffffffc020164e:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201650:	4501                	li	a0,0
ffffffffc0201652:	8082                	ret

ffffffffc0201654 <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc0201654:	ca01                	beqz	a2,ffffffffc0201664 <memset+0x10>
ffffffffc0201656:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc0201658:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc020165a:	0785                	addi	a5,a5,1
ffffffffc020165c:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc0201660:	fec79de3          	bne	a5,a2,ffffffffc020165a <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc0201664:	8082                	ret
