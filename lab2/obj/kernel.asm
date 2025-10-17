
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid # hartid当前运行的线程ID
ffffffffc0200000:	00006297          	auipc	t0,0x6
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0) # 保存当前运行的线程ID
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0206000 <boot_hartid>
    la t0, boot_dtb # 设备树blob的物理地址
ffffffffc020000c:	00006297          	auipc	t0,0x6
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0206008 <boot_dtb>
    sd a1, 0(t0) # 保存设备树blob的物理地址到$a1
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39) # 存储了根页表的虚拟地址
ffffffffc0200018:	c02052b7          	lui	t0,0xc0205
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
ffffffffc020003c:	c0205137          	lui	sp,0xc0205
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
ffffffffc0200050:	00002517          	auipc	a0,0x2
ffffffffc0200054:	95050513          	addi	a0,a0,-1712 # ffffffffc02019a0 <etext+0x6>
void print_kerninfo(void) {
ffffffffc0200058:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc020005a:	0f6000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005e:	00000597          	auipc	a1,0x0
ffffffffc0200062:	07e58593          	addi	a1,a1,126 # ffffffffc02000dc <kern_init>
ffffffffc0200066:	00002517          	auipc	a0,0x2
ffffffffc020006a:	95a50513          	addi	a0,a0,-1702 # ffffffffc02019c0 <etext+0x26>
ffffffffc020006e:	0e2000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc0200072:	00002597          	auipc	a1,0x2
ffffffffc0200076:	92858593          	addi	a1,a1,-1752 # ffffffffc020199a <etext>
ffffffffc020007a:	00002517          	auipc	a0,0x2
ffffffffc020007e:	96650513          	addi	a0,a0,-1690 # ffffffffc02019e0 <etext+0x46>
ffffffffc0200082:	0ce000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200086:	00006597          	auipc	a1,0x6
ffffffffc020008a:	f9258593          	addi	a1,a1,-110 # ffffffffc0206018 <cache_list>
ffffffffc020008e:	00002517          	auipc	a0,0x2
ffffffffc0200092:	97250513          	addi	a0,a0,-1678 # ffffffffc0201a00 <etext+0x66>
ffffffffc0200096:	0ba000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc020009a:	00006597          	auipc	a1,0x6
ffffffffc020009e:	05a58593          	addi	a1,a1,90 # ffffffffc02060f4 <end>
ffffffffc02000a2:	00002517          	auipc	a0,0x2
ffffffffc02000a6:	97e50513          	addi	a0,a0,-1666 # ffffffffc0201a20 <etext+0x86>
ffffffffc02000aa:	0a6000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000ae:	00006597          	auipc	a1,0x6
ffffffffc02000b2:	44558593          	addi	a1,a1,1093 # ffffffffc02064f3 <end+0x3ff>
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
ffffffffc02000d0:	00002517          	auipc	a0,0x2
ffffffffc02000d4:	97050513          	addi	a0,a0,-1680 # ffffffffc0201a40 <etext+0xa6>
}
ffffffffc02000d8:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000da:	a89d                	j	ffffffffc0200150 <cprintf>

ffffffffc02000dc <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000dc:	00006517          	auipc	a0,0x6
ffffffffc02000e0:	f3c50513          	addi	a0,a0,-196 # ffffffffc0206018 <cache_list>
ffffffffc02000e4:	00006617          	auipc	a2,0x6
ffffffffc02000e8:	01060613          	addi	a2,a2,16 # ffffffffc02060f4 <end>
int kern_init(void) {
ffffffffc02000ec:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ee:	8e09                	sub	a2,a2,a0
ffffffffc02000f0:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000f2:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f4:	095010ef          	jal	ra,ffffffffc0201988 <memset>
    dtb_init();
ffffffffc02000f8:	12c000ef          	jal	ra,ffffffffc0200224 <dtb_init>
    cons_init();  // init the console
ffffffffc02000fc:	11e000ef          	jal	ra,ffffffffc020021a <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc0200100:	00002517          	auipc	a0,0x2
ffffffffc0200104:	97050513          	addi	a0,a0,-1680 # ffffffffc0201a70 <etext+0xd6>
ffffffffc0200108:	07e000ef          	jal	ra,ffffffffc0200186 <cputs>

    print_kerninfo();
ffffffffc020010c:	f43ff0ef          	jal	ra,ffffffffc020004e <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc0200110:	4c4000ef          	jal	ra,ffffffffc02005d4 <pmm_init>

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
ffffffffc0200144:	3cc010ef          	jal	ra,ffffffffc0201510 <vprintfmt>
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
ffffffffc0200152:	02810313          	addi	t1,sp,40 # ffffffffc0205028 <boot_page_table_sv39+0x28>
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
ffffffffc020017a:	396010ef          	jal	ra,ffffffffc0201510 <vprintfmt>
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
ffffffffc02001c6:	00006317          	auipc	t1,0x6
ffffffffc02001ca:	ee230313          	addi	t1,t1,-286 # ffffffffc02060a8 <is_panic>
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
ffffffffc02001f6:	00002517          	auipc	a0,0x2
ffffffffc02001fa:	89a50513          	addi	a0,a0,-1894 # ffffffffc0201a90 <etext+0xf6>
    va_start(ap, fmt);
ffffffffc02001fe:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc0200200:	f51ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    vcprintf(fmt, ap);
ffffffffc0200204:	65a2                	ld	a1,8(sp)
ffffffffc0200206:	8522                	mv	a0,s0
ffffffffc0200208:	f29ff0ef          	jal	ra,ffffffffc0200130 <vcprintf>
    cprintf("\n");
ffffffffc020020c:	00002517          	auipc	a0,0x2
ffffffffc0200210:	d4450513          	addi	a0,a0,-700 # ffffffffc0201f50 <etext+0x5b6>
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
ffffffffc0200220:	6b80106f          	j	ffffffffc02018d8 <sbi_console_putchar>

ffffffffc0200224 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200224:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200226:	00002517          	auipc	a0,0x2
ffffffffc020022a:	88a50513          	addi	a0,a0,-1910 # ffffffffc0201ab0 <etext+0x116>
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
ffffffffc020024c:	00006597          	auipc	a1,0x6
ffffffffc0200250:	db45b583          	ld	a1,-588(a1) # ffffffffc0206000 <boot_hartid>
ffffffffc0200254:	00002517          	auipc	a0,0x2
ffffffffc0200258:	86c50513          	addi	a0,a0,-1940 # ffffffffc0201ac0 <etext+0x126>
ffffffffc020025c:	ef5ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc0200260:	00006417          	auipc	s0,0x6
ffffffffc0200264:	da840413          	addi	s0,s0,-600 # ffffffffc0206008 <boot_dtb>
ffffffffc0200268:	600c                	ld	a1,0(s0)
ffffffffc020026a:	00002517          	auipc	a0,0x2
ffffffffc020026e:	86650513          	addi	a0,a0,-1946 # ffffffffc0201ad0 <etext+0x136>
ffffffffc0200272:	edfff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200276:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc020027a:	00002517          	auipc	a0,0x2
ffffffffc020027e:	86e50513          	addi	a0,a0,-1938 # ffffffffc0201ae8 <etext+0x14e>
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
ffffffffc02002c2:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed9df9>
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
ffffffffc0200334:	00002917          	auipc	s2,0x2
ffffffffc0200338:	80490913          	addi	s2,s2,-2044 # ffffffffc0201b38 <etext+0x19e>
ffffffffc020033c:	49bd                	li	s3,15
        switch (token) {
ffffffffc020033e:	4d91                	li	s11,4
ffffffffc0200340:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200342:	00001497          	auipc	s1,0x1
ffffffffc0200346:	7ee48493          	addi	s1,s1,2030 # ffffffffc0201b30 <etext+0x196>
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
ffffffffc0200396:	00002517          	auipc	a0,0x2
ffffffffc020039a:	81a50513          	addi	a0,a0,-2022 # ffffffffc0201bb0 <etext+0x216>
ffffffffc020039e:	db3ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc02003a2:	00002517          	auipc	a0,0x2
ffffffffc02003a6:	84650513          	addi	a0,a0,-1978 # ffffffffc0201be8 <etext+0x24e>
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
ffffffffc02003e6:	72650513          	addi	a0,a0,1830 # ffffffffc0201b08 <etext+0x16e>
}
ffffffffc02003ea:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003ec:	b395                	j	ffffffffc0200150 <cprintf>
                int name_len = strlen(name);
ffffffffc02003ee:	8556                	mv	a0,s5
ffffffffc02003f0:	502010ef          	jal	ra,ffffffffc02018f2 <strlen>
ffffffffc02003f4:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f6:	4619                	li	a2,6
ffffffffc02003f8:	85a6                	mv	a1,s1
ffffffffc02003fa:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003fc:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003fe:	564010ef          	jal	ra,ffffffffc0201962 <strncmp>
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
ffffffffc0200494:	4b0010ef          	jal	ra,ffffffffc0201944 <strcmp>
ffffffffc0200498:	66a2                	ld	a3,8(sp)
ffffffffc020049a:	f94d                	bnez	a0,ffffffffc020044c <dtb_init+0x228>
ffffffffc020049c:	fb59f8e3          	bgeu	s3,s5,ffffffffc020044c <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc02004a0:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004a4:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc02004a8:	00001517          	auipc	a0,0x1
ffffffffc02004ac:	69850513          	addi	a0,a0,1688 # ffffffffc0201b40 <etext+0x1a6>
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
ffffffffc020057a:	5ea50513          	addi	a0,a0,1514 # ffffffffc0201b60 <etext+0x1c6>
ffffffffc020057e:	bd3ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc0200582:	014b5613          	srli	a2,s6,0x14
ffffffffc0200586:	85da                	mv	a1,s6
ffffffffc0200588:	00001517          	auipc	a0,0x1
ffffffffc020058c:	5f050513          	addi	a0,a0,1520 # ffffffffc0201b78 <etext+0x1de>
ffffffffc0200590:	bc1ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200594:	008b05b3          	add	a1,s6,s0
ffffffffc0200598:	15fd                	addi	a1,a1,-1
ffffffffc020059a:	00001517          	auipc	a0,0x1
ffffffffc020059e:	5fe50513          	addi	a0,a0,1534 # ffffffffc0201b98 <etext+0x1fe>
ffffffffc02005a2:	bafff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("DTB init completed\n");
ffffffffc02005a6:	00001517          	auipc	a0,0x1
ffffffffc02005aa:	64250513          	addi	a0,a0,1602 # ffffffffc0201be8 <etext+0x24e>
        memory_base = mem_base;
ffffffffc02005ae:	00006797          	auipc	a5,0x6
ffffffffc02005b2:	b087b123          	sd	s0,-1278(a5) # ffffffffc02060b0 <memory_base>
        memory_size = mem_size;
ffffffffc02005b6:	00006797          	auipc	a5,0x6
ffffffffc02005ba:	b167b123          	sd	s6,-1278(a5) # ffffffffc02060b8 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005be:	b3f5                	j	ffffffffc02003aa <dtb_init+0x186>

ffffffffc02005c0 <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005c0:	00006517          	auipc	a0,0x6
ffffffffc02005c4:	af053503          	ld	a0,-1296(a0) # ffffffffc02060b0 <memory_base>
ffffffffc02005c8:	8082                	ret

ffffffffc02005ca <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005ca:	00006517          	auipc	a0,0x6
ffffffffc02005ce:	aee53503          	ld	a0,-1298(a0) # ffffffffc02060b8 <memory_size>
ffffffffc02005d2:	8082                	ret

ffffffffc02005d4 <pmm_init>:
// init_pmm_manager - initialize a pmm_manager instance
static void init_pmm_manager(void) {
    // 可以选择不同的内存管理器
    // pmm_manager = &default_pmm_manager;
    // pmm_manager = &best_fit_pmm_manager;
    pmm_manager = &slub_pmm_manager;
ffffffffc02005d4:	00002797          	auipc	a5,0x2
ffffffffc02005d8:	c0c78793          	addi	a5,a5,-1012 # ffffffffc02021e0 <slub_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02005dc:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
    }
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc02005de:	7179                	addi	sp,sp,-48
ffffffffc02005e0:	f022                	sd	s0,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02005e2:	00001517          	auipc	a0,0x1
ffffffffc02005e6:	61e50513          	addi	a0,a0,1566 # ffffffffc0201c00 <etext+0x266>
    pmm_manager = &slub_pmm_manager;
ffffffffc02005ea:	00006417          	auipc	s0,0x6
ffffffffc02005ee:	ae640413          	addi	s0,s0,-1306 # ffffffffc02060d0 <pmm_manager>
void pmm_init(void) {
ffffffffc02005f2:	f406                	sd	ra,40(sp)
ffffffffc02005f4:	ec26                	sd	s1,24(sp)
ffffffffc02005f6:	e44e                	sd	s3,8(sp)
ffffffffc02005f8:	e84a                	sd	s2,16(sp)
ffffffffc02005fa:	e052                	sd	s4,0(sp)
    pmm_manager = &slub_pmm_manager;
ffffffffc02005fc:	e01c                	sd	a5,0(s0)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02005fe:	b53ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    pmm_manager->init();
ffffffffc0200602:	601c                	ld	a5,0(s0)
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200604:	00006497          	auipc	s1,0x6
ffffffffc0200608:	ae448493          	addi	s1,s1,-1308 # ffffffffc02060e8 <va_pa_offset>
    pmm_manager->init();
ffffffffc020060c:	679c                	ld	a5,8(a5)
ffffffffc020060e:	9782                	jalr	a5
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200610:	57f5                	li	a5,-3
ffffffffc0200612:	07fa                	slli	a5,a5,0x1e
ffffffffc0200614:	e09c                	sd	a5,0(s1)
    uint64_t mem_begin = get_memory_base();
ffffffffc0200616:	fabff0ef          	jal	ra,ffffffffc02005c0 <get_memory_base>
ffffffffc020061a:	89aa                	mv	s3,a0
    uint64_t mem_size  = get_memory_size();
ffffffffc020061c:	fafff0ef          	jal	ra,ffffffffc02005ca <get_memory_size>
    if (mem_size == 0) {
ffffffffc0200620:	14050c63          	beqz	a0,ffffffffc0200778 <pmm_init+0x1a4>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0200624:	892a                	mv	s2,a0
    cprintf("physcial memory map:\n");
ffffffffc0200626:	00001517          	auipc	a0,0x1
ffffffffc020062a:	62250513          	addi	a0,a0,1570 # ffffffffc0201c48 <etext+0x2ae>
ffffffffc020062e:	b23ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0200632:	01298a33          	add	s4,s3,s2
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n", mem_size, mem_begin,
ffffffffc0200636:	864e                	mv	a2,s3
ffffffffc0200638:	fffa0693          	addi	a3,s4,-1
ffffffffc020063c:	85ca                	mv	a1,s2
ffffffffc020063e:	00001517          	auipc	a0,0x1
ffffffffc0200642:	62250513          	addi	a0,a0,1570 # ffffffffc0201c60 <etext+0x2c6>
ffffffffc0200646:	b0bff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc020064a:	c80007b7          	lui	a5,0xc8000
ffffffffc020064e:	8652                	mv	a2,s4
ffffffffc0200650:	0d47e363          	bltu	a5,s4,ffffffffc0200716 <pmm_init+0x142>
ffffffffc0200654:	00007797          	auipc	a5,0x7
ffffffffc0200658:	a9f78793          	addi	a5,a5,-1377 # ffffffffc02070f3 <end+0xfff>
ffffffffc020065c:	757d                	lui	a0,0xfffff
ffffffffc020065e:	8d7d                	and	a0,a0,a5
ffffffffc0200660:	8231                	srli	a2,a2,0xc
ffffffffc0200662:	00006797          	auipc	a5,0x6
ffffffffc0200666:	a4c7bf23          	sd	a2,-1442(a5) # ffffffffc02060c0 <npage>
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc020066a:	00006797          	auipc	a5,0x6
ffffffffc020066e:	a4a7bf23          	sd	a0,-1442(a5) # ffffffffc02060c8 <pages>
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0200672:	000807b7          	lui	a5,0x80
ffffffffc0200676:	002005b7          	lui	a1,0x200
ffffffffc020067a:	02f60563          	beq	a2,a5,ffffffffc02006a4 <pmm_init+0xd0>
ffffffffc020067e:	00261593          	slli	a1,a2,0x2
ffffffffc0200682:	00c586b3          	add	a3,a1,a2
ffffffffc0200686:	fec007b7          	lui	a5,0xfec00
ffffffffc020068a:	97aa                	add	a5,a5,a0
ffffffffc020068c:	068e                	slli	a3,a3,0x3
ffffffffc020068e:	96be                	add	a3,a3,a5
ffffffffc0200690:	87aa                	mv	a5,a0
        SetPageReserved(pages + i);
ffffffffc0200692:	6798                	ld	a4,8(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0200694:	02878793          	addi	a5,a5,40 # fffffffffec00028 <end+0x3e9f9f34>
        SetPageReserved(pages + i);
ffffffffc0200698:	00176713          	ori	a4,a4,1
ffffffffc020069c:	fee7b023          	sd	a4,-32(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc02006a0:	fef699e3          	bne	a3,a5,ffffffffc0200692 <pmm_init+0xbe>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc02006a4:	95b2                	add	a1,a1,a2
ffffffffc02006a6:	fec006b7          	lui	a3,0xfec00
ffffffffc02006aa:	96aa                	add	a3,a3,a0
ffffffffc02006ac:	058e                	slli	a1,a1,0x3
ffffffffc02006ae:	96ae                	add	a3,a3,a1
ffffffffc02006b0:	c02007b7          	lui	a5,0xc0200
ffffffffc02006b4:	0af6e663          	bltu	a3,a5,ffffffffc0200760 <pmm_init+0x18c>
ffffffffc02006b8:	6098                	ld	a4,0(s1)
    mem_end = ROUNDDOWN(mem_end, PGSIZE);
ffffffffc02006ba:	77fd                	lui	a5,0xfffff
ffffffffc02006bc:	00fa75b3          	and	a1,s4,a5
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc02006c0:	8e99                	sub	a3,a3,a4
    if (freemem < mem_end) {
ffffffffc02006c2:	04b6ed63          	bltu	a3,a1,ffffffffc020071c <pmm_init+0x148>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc02006c6:	601c                	ld	a5,0(s0)
ffffffffc02006c8:	7b9c                	ld	a5,48(a5)
ffffffffc02006ca:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc02006cc:	00001517          	auipc	a0,0x1
ffffffffc02006d0:	61c50513          	addi	a0,a0,1564 # ffffffffc0201ce8 <etext+0x34e>
ffffffffc02006d4:	a7dff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc02006d8:	00005597          	auipc	a1,0x5
ffffffffc02006dc:	92858593          	addi	a1,a1,-1752 # ffffffffc0205000 <boot_page_table_sv39>
ffffffffc02006e0:	00006797          	auipc	a5,0x6
ffffffffc02006e4:	a0b7b023          	sd	a1,-1536(a5) # ffffffffc02060e0 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc02006e8:	c02007b7          	lui	a5,0xc0200
ffffffffc02006ec:	0af5e263          	bltu	a1,a5,ffffffffc0200790 <pmm_init+0x1bc>
ffffffffc02006f0:	6090                	ld	a2,0(s1)
}
ffffffffc02006f2:	7402                	ld	s0,32(sp)
ffffffffc02006f4:	70a2                	ld	ra,40(sp)
ffffffffc02006f6:	64e2                	ld	s1,24(sp)
ffffffffc02006f8:	6942                	ld	s2,16(sp)
ffffffffc02006fa:	69a2                	ld	s3,8(sp)
ffffffffc02006fc:	6a02                	ld	s4,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc02006fe:	40c58633          	sub	a2,a1,a2
ffffffffc0200702:	00006797          	auipc	a5,0x6
ffffffffc0200706:	9cc7bb23          	sd	a2,-1578(a5) # ffffffffc02060d8 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc020070a:	00001517          	auipc	a0,0x1
ffffffffc020070e:	5fe50513          	addi	a0,a0,1534 # ffffffffc0201d08 <etext+0x36e>
}
ffffffffc0200712:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200714:	bc35                	j	ffffffffc0200150 <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0200716:	c8000637          	lui	a2,0xc8000
ffffffffc020071a:	bf2d                	j	ffffffffc0200654 <pmm_init+0x80>
    mem_begin = ROUNDUP(freemem, PGSIZE);
ffffffffc020071c:	6705                	lui	a4,0x1
ffffffffc020071e:	177d                	addi	a4,a4,-1
ffffffffc0200720:	96ba                	add	a3,a3,a4
ffffffffc0200722:	8efd                	and	a3,a3,a5
    return page->ref;
}

// 将物理地址转换为页结构指针
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc0200724:	00c6d793          	srli	a5,a3,0xc
ffffffffc0200728:	02c7f063          	bgeu	a5,a2,ffffffffc0200748 <pmm_init+0x174>
    pmm_manager->init_memmap(base, n);
ffffffffc020072c:	6010                	ld	a2,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc020072e:	fff80737          	lui	a4,0xfff80
ffffffffc0200732:	973e                	add	a4,a4,a5
ffffffffc0200734:	00271793          	slli	a5,a4,0x2
ffffffffc0200738:	97ba                	add	a5,a5,a4
ffffffffc020073a:	6a18                	ld	a4,16(a2)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
ffffffffc020073c:	8d95                	sub	a1,a1,a3
ffffffffc020073e:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc0200740:	81b1                	srli	a1,a1,0xc
ffffffffc0200742:	953e                	add	a0,a0,a5
ffffffffc0200744:	9702                	jalr	a4
}
ffffffffc0200746:	b741                	j	ffffffffc02006c6 <pmm_init+0xf2>
        panic("pa2page called with invalid pa");
ffffffffc0200748:	00001617          	auipc	a2,0x1
ffffffffc020074c:	57060613          	addi	a2,a2,1392 # ffffffffc0201cb8 <etext+0x31e>
ffffffffc0200750:	06a00593          	li	a1,106
ffffffffc0200754:	00001517          	auipc	a0,0x1
ffffffffc0200758:	58450513          	addi	a0,a0,1412 # ffffffffc0201cd8 <etext+0x33e>
ffffffffc020075c:	a6bff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc0200760:	00001617          	auipc	a2,0x1
ffffffffc0200764:	53060613          	addi	a2,a2,1328 # ffffffffc0201c90 <etext+0x2f6>
ffffffffc0200768:	06100593          	li	a1,97
ffffffffc020076c:	00001517          	auipc	a0,0x1
ffffffffc0200770:	4cc50513          	addi	a0,a0,1228 # ffffffffc0201c38 <etext+0x29e>
ffffffffc0200774:	a53ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
        panic("DTB memory info not available");
ffffffffc0200778:	00001617          	auipc	a2,0x1
ffffffffc020077c:	4a060613          	addi	a2,a2,1184 # ffffffffc0201c18 <etext+0x27e>
ffffffffc0200780:	04900593          	li	a1,73
ffffffffc0200784:	00001517          	auipc	a0,0x1
ffffffffc0200788:	4b450513          	addi	a0,a0,1204 # ffffffffc0201c38 <etext+0x29e>
ffffffffc020078c:	a3bff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc0200790:	86ae                	mv	a3,a1
ffffffffc0200792:	00001617          	auipc	a2,0x1
ffffffffc0200796:	4fe60613          	addi	a2,a2,1278 # ffffffffc0201c90 <etext+0x2f6>
ffffffffc020079a:	07d00593          	li	a1,125
ffffffffc020079e:	00001517          	auipc	a0,0x1
ffffffffc02007a2:	49a50513          	addi	a0,a0,1178 # ffffffffc0201c38 <etext+0x29e>
ffffffffc02007a6:	a21ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc02007aa <slub_nr_free_pages>:
}

// 获取空闲页数量
static size_t slub_nr_free_pages(void) {
    return nr_free;
}
ffffffffc02007aa:	00006517          	auipc	a0,0x6
ffffffffc02007ae:	88e56503          	lwu	a0,-1906(a0) # ffffffffc0206038 <free_area+0x10>
ffffffffc02007b2:	8082                	ret

ffffffffc02007b4 <slub_init>:
void slub_init(void) {
ffffffffc02007b4:	1141                	addi	sp,sp,-16
    cprintf("memory management: slub_pmm_manager\n");
ffffffffc02007b6:	00001517          	auipc	a0,0x1
ffffffffc02007ba:	59250513          	addi	a0,a0,1426 # ffffffffc0201d48 <etext+0x3ae>
void slub_init(void) {
ffffffffc02007be:	e406                	sd	ra,8(sp)
    cprintf("memory management: slub_pmm_manager\n");
ffffffffc02007c0:	991ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02007c4:	00006797          	auipc	a5,0x6
ffffffffc02007c8:	86478793          	addi	a5,a5,-1948 # ffffffffc0206028 <free_area>
ffffffffc02007cc:	00006717          	auipc	a4,0x6
ffffffffc02007d0:	84c70713          	addi	a4,a4,-1972 # ffffffffc0206018 <cache_list>
}
ffffffffc02007d4:	60a2                	ld	ra,8(sp)
ffffffffc02007d6:	e718                	sd	a4,8(a4)
ffffffffc02007d8:	e318                	sd	a4,0(a4)
ffffffffc02007da:	e79c                	sd	a5,8(a5)
    cache_lock = 0;
ffffffffc02007dc:	00006717          	auipc	a4,0x6
ffffffffc02007e0:	90072a23          	sw	zero,-1772(a4) # ffffffffc02060f0 <cache_lock>
ffffffffc02007e4:	e39c                	sd	a5,0(a5)
    nr_free = 0;
ffffffffc02007e6:	0007a823          	sw	zero,16(a5)
    cprintf("slub: initialization completed\n");
ffffffffc02007ea:	00001517          	auipc	a0,0x1
ffffffffc02007ee:	58650513          	addi	a0,a0,1414 # ffffffffc0201d70 <etext+0x3d6>
}
ffffffffc02007f2:	0141                	addi	sp,sp,16
    cprintf("slub: initialization completed\n");
ffffffffc02007f4:	bab1                	j	ffffffffc0200150 <cprintf>

ffffffffc02007f6 <slub_alloc_pages>:
    assert(n > 0);
ffffffffc02007f6:	cd49                	beqz	a0,ffffffffc0200890 <slub_alloc_pages+0x9a>
    if (n > nr_free) {
ffffffffc02007f8:	00006617          	auipc	a2,0x6
ffffffffc02007fc:	83060613          	addi	a2,a2,-2000 # ffffffffc0206028 <free_area>
ffffffffc0200800:	01062803          	lw	a6,16(a2)
ffffffffc0200804:	86aa                	mv	a3,a0
ffffffffc0200806:	02081793          	slli	a5,a6,0x20
ffffffffc020080a:	9381                	srli	a5,a5,0x20
ffffffffc020080c:	08a7e063          	bltu	a5,a0,ffffffffc020088c <slub_alloc_pages+0x96>
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc0200810:	661c                	ld	a5,8(a2)
    size_t min_size = nr_free + 1;
ffffffffc0200812:	0018059b          	addiw	a1,a6,1
ffffffffc0200816:	1582                	slli	a1,a1,0x20
ffffffffc0200818:	9181                	srli	a1,a1,0x20
    struct Page *page = NULL;
ffffffffc020081a:	4501                	li	a0,0
    while ((le = list_next(le)) != &free_list) {
ffffffffc020081c:	06c78763          	beq	a5,a2,ffffffffc020088a <slub_alloc_pages+0x94>
        if (p->property >= n && p->property < min_size) {
ffffffffc0200820:	ff87e703          	lwu	a4,-8(a5)
ffffffffc0200824:	00d76763          	bltu	a4,a3,ffffffffc0200832 <slub_alloc_pages+0x3c>
ffffffffc0200828:	00b77563          	bgeu	a4,a1,ffffffffc0200832 <slub_alloc_pages+0x3c>
        struct Page *p = le2page(le, page_link);
ffffffffc020082c:	fe878513          	addi	a0,a5,-24
ffffffffc0200830:	85ba                	mv	a1,a4
ffffffffc0200832:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200834:	fec796e3          	bne	a5,a2,ffffffffc0200820 <slub_alloc_pages+0x2a>
    if (page != NULL) {
ffffffffc0200838:	c929                	beqz	a0,ffffffffc020088a <slub_alloc_pages+0x94>
        if (page->property > n) {
ffffffffc020083a:	01052883          	lw	a7,16(a0)
 * list_prev - get the previous entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_prev(list_entry_t *listelm) {
    return listelm->prev;
ffffffffc020083e:	6d18                	ld	a4,24(a0)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200840:	710c                	ld	a1,32(a0)
ffffffffc0200842:	02089793          	slli	a5,a7,0x20
ffffffffc0200846:	9381                	srli	a5,a5,0x20
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc0200848:	e70c                	sd	a1,8(a4)
    next->prev = prev;
ffffffffc020084a:	e198                	sd	a4,0(a1)
            p->property = page->property - n;
ffffffffc020084c:	0006831b          	sext.w	t1,a3
        if (page->property > n) {
ffffffffc0200850:	02f6f563          	bgeu	a3,a5,ffffffffc020087a <slub_alloc_pages+0x84>
            struct Page *p = page + n;
ffffffffc0200854:	00269793          	slli	a5,a3,0x2
ffffffffc0200858:	97b6                	add	a5,a5,a3
ffffffffc020085a:	078e                	slli	a5,a5,0x3
ffffffffc020085c:	97aa                	add	a5,a5,a0
            SetPageProperty(p);
ffffffffc020085e:	6794                	ld	a3,8(a5)
            p->property = page->property - n;
ffffffffc0200860:	406888bb          	subw	a7,a7,t1
ffffffffc0200864:	0117a823          	sw	a7,16(a5)
            SetPageProperty(p);
ffffffffc0200868:	0026e693          	ori	a3,a3,2
ffffffffc020086c:	e794                	sd	a3,8(a5)
            list_add(prev, &(p->page_link));
ffffffffc020086e:	01878693          	addi	a3,a5,24
    prev->next = next->prev = elm;
ffffffffc0200872:	e194                	sd	a3,0(a1)
ffffffffc0200874:	e714                	sd	a3,8(a4)
    elm->next = next;
ffffffffc0200876:	f38c                	sd	a1,32(a5)
    elm->prev = prev;
ffffffffc0200878:	ef98                	sd	a4,24(a5)
        ClearPageProperty(page);
ffffffffc020087a:	651c                	ld	a5,8(a0)
        nr_free -= n;
ffffffffc020087c:	4068083b          	subw	a6,a6,t1
ffffffffc0200880:	01062823          	sw	a6,16(a2)
        ClearPageProperty(page);
ffffffffc0200884:	9bf5                	andi	a5,a5,-3
ffffffffc0200886:	e51c                	sd	a5,8(a0)
ffffffffc0200888:	8082                	ret
}
ffffffffc020088a:	8082                	ret
        return NULL;
ffffffffc020088c:	4501                	li	a0,0
ffffffffc020088e:	8082                	ret
static struct Page *slub_alloc_pages(size_t n) {
ffffffffc0200890:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc0200892:	00001697          	auipc	a3,0x1
ffffffffc0200896:	4fe68693          	addi	a3,a3,1278 # ffffffffc0201d90 <etext+0x3f6>
ffffffffc020089a:	00001617          	auipc	a2,0x1
ffffffffc020089e:	4fe60613          	addi	a2,a2,1278 # ffffffffc0201d98 <etext+0x3fe>
ffffffffc02008a2:	09300593          	li	a1,147
ffffffffc02008a6:	00001517          	auipc	a0,0x1
ffffffffc02008aa:	50a50513          	addi	a0,a0,1290 # ffffffffc0201db0 <etext+0x416>
static struct Page *slub_alloc_pages(size_t n) {
ffffffffc02008ae:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc02008b0:	917ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc02008b4 <slub_free_pages.part.0>:
    for (; p != base + n; p++) {
ffffffffc02008b4:	00259793          	slli	a5,a1,0x2
ffffffffc02008b8:	97ae                	add	a5,a5,a1
ffffffffc02008ba:	078e                	slli	a5,a5,0x3
ffffffffc02008bc:	00f506b3          	add	a3,a0,a5
ffffffffc02008c0:	87aa                	mv	a5,a0
ffffffffc02008c2:	00d50e63          	beq	a0,a3,ffffffffc02008de <slub_free_pages.part.0+0x2a>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc02008c6:	6798                	ld	a4,8(a5)
ffffffffc02008c8:	8b0d                	andi	a4,a4,3
ffffffffc02008ca:	10071a63          	bnez	a4,ffffffffc02009de <slub_free_pages.part.0+0x12a>
        p->flags = 0;
ffffffffc02008ce:	0007b423          	sd	zero,8(a5)
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc02008d2:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p++) {
ffffffffc02008d6:	02878793          	addi	a5,a5,40
ffffffffc02008da:	fed796e3          	bne	a5,a3,ffffffffc02008c6 <slub_free_pages.part.0+0x12>
    SetPageProperty(base);
ffffffffc02008de:	00853883          	ld	a7,8(a0)
    nr_free += n;
ffffffffc02008e2:	00005697          	auipc	a3,0x5
ffffffffc02008e6:	74668693          	addi	a3,a3,1862 # ffffffffc0206028 <free_area>
ffffffffc02008ea:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc02008ec:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc02008ee:	0028e613          	ori	a2,a7,2
    return list->next == list;
ffffffffc02008f2:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc02008f4:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc02008f6:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc02008f8:	9f2d                	addw	a4,a4,a1
ffffffffc02008fa:	ca98                	sw	a4,16(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc02008fc:	01850613          	addi	a2,a0,24
    if (list_empty(&free_list)) {
ffffffffc0200900:	0cd78a63          	beq	a5,a3,ffffffffc02009d4 <slub_free_pages.part.0+0x120>
            struct Page *page = le2page(le, page_link);
ffffffffc0200904:	fe878713          	addi	a4,a5,-24
ffffffffc0200908:	0006b303          	ld	t1,0(a3)
    if (list_empty(&free_list)) {
ffffffffc020090c:	4801                	li	a6,0
            if (base < page) {
ffffffffc020090e:	00e56a63          	bltu	a0,a4,ffffffffc0200922 <slub_free_pages.part.0+0x6e>
    return listelm->next;
ffffffffc0200912:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0200914:	06d70363          	beq	a4,a3,ffffffffc020097a <slub_free_pages.part.0+0xc6>
    for (; p != base + n; p++) {
ffffffffc0200918:	87ba                	mv	a5,a4
            struct Page *page = le2page(le, page_link);
ffffffffc020091a:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc020091e:	fee57ae3          	bgeu	a0,a4,ffffffffc0200912 <slub_free_pages.part.0+0x5e>
ffffffffc0200922:	00080463          	beqz	a6,ffffffffc020092a <slub_free_pages.part.0+0x76>
ffffffffc0200926:	0066b023          	sd	t1,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc020092a:	0007b803          	ld	a6,0(a5)
    prev->next = next->prev = elm;
ffffffffc020092e:	e390                	sd	a2,0(a5)
ffffffffc0200930:	00c83423          	sd	a2,8(a6)
    elm->next = next;
ffffffffc0200934:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200936:	01053c23          	sd	a6,24(a0)
    if (le != &free_list) {
ffffffffc020093a:	02d80463          	beq	a6,a3,ffffffffc0200962 <slub_free_pages.part.0+0xae>
        if (p + p->property == base) {
ffffffffc020093e:	ff882e03          	lw	t3,-8(a6)
        p = le2page(le, page_link);
ffffffffc0200942:	fe880313          	addi	t1,a6,-24
        if (p + p->property == base) {
ffffffffc0200946:	020e1613          	slli	a2,t3,0x20
ffffffffc020094a:	9201                	srli	a2,a2,0x20
ffffffffc020094c:	00261713          	slli	a4,a2,0x2
ffffffffc0200950:	9732                	add	a4,a4,a2
ffffffffc0200952:	070e                	slli	a4,a4,0x3
ffffffffc0200954:	971a                	add	a4,a4,t1
ffffffffc0200956:	02e50c63          	beq	a0,a4,ffffffffc020098e <slub_free_pages.part.0+0xda>
    if (le != &free_list) {
ffffffffc020095a:	00d78f63          	beq	a5,a3,ffffffffc0200978 <slub_free_pages.part.0+0xc4>
ffffffffc020095e:	fe878713          	addi	a4,a5,-24
        if (base + base->property == p) {
ffffffffc0200962:	490c                	lw	a1,16(a0)
ffffffffc0200964:	02059613          	slli	a2,a1,0x20
ffffffffc0200968:	9201                	srli	a2,a2,0x20
ffffffffc020096a:	00261693          	slli	a3,a2,0x2
ffffffffc020096e:	96b2                	add	a3,a3,a2
ffffffffc0200970:	068e                	slli	a3,a3,0x3
ffffffffc0200972:	96aa                	add	a3,a3,a0
ffffffffc0200974:	02d70b63          	beq	a4,a3,ffffffffc02009aa <slub_free_pages.part.0+0xf6>
ffffffffc0200978:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc020097a:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc020097c:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc020097e:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc0200980:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc0200982:	04d70563          	beq	a4,a3,ffffffffc02009cc <slub_free_pages.part.0+0x118>
    prev->next = next->prev = elm;
ffffffffc0200986:	8332                	mv	t1,a2
ffffffffc0200988:	4805                	li	a6,1
    for (; p != base + n; p++) {
ffffffffc020098a:	87ba                	mv	a5,a4
ffffffffc020098c:	b779                	j	ffffffffc020091a <slub_free_pages.part.0+0x66>
            p->property += base->property;
ffffffffc020098e:	01c585bb          	addw	a1,a1,t3
ffffffffc0200992:	feb82c23          	sw	a1,-8(a6)
            ClearPageProperty(base);
ffffffffc0200996:	ffd8f893          	andi	a7,a7,-3
ffffffffc020099a:	01153423          	sd	a7,8(a0)
    prev->next = next;
ffffffffc020099e:	00f83423          	sd	a5,8(a6)
    next->prev = prev;
ffffffffc02009a2:	0107b023          	sd	a6,0(a5)
            base = p;
ffffffffc02009a6:	851a                	mv	a0,t1
ffffffffc02009a8:	bf4d                	j	ffffffffc020095a <slub_free_pages.part.0+0xa6>
            base->property += p->property;
ffffffffc02009aa:	ff87a683          	lw	a3,-8(a5)
            ClearPageProperty(p);
ffffffffc02009ae:	ff07b703          	ld	a4,-16(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc02009b2:	0007b803          	ld	a6,0(a5)
ffffffffc02009b6:	6790                	ld	a2,8(a5)
            base->property += p->property;
ffffffffc02009b8:	9db5                	addw	a1,a1,a3
ffffffffc02009ba:	c90c                	sw	a1,16(a0)
            ClearPageProperty(p);
ffffffffc02009bc:	9b75                	andi	a4,a4,-3
ffffffffc02009be:	fee7b823          	sd	a4,-16(a5)
    prev->next = next;
ffffffffc02009c2:	00c83423          	sd	a2,8(a6)
    next->prev = prev;
ffffffffc02009c6:	01063023          	sd	a6,0(a2)
ffffffffc02009ca:	8082                	ret
        while ((le = list_next(le)) != &free_list) {
ffffffffc02009cc:	883e                	mv	a6,a5
ffffffffc02009ce:	e290                	sd	a2,0(a3)
ffffffffc02009d0:	87b6                	mv	a5,a3
ffffffffc02009d2:	b7b5                	j	ffffffffc020093e <slub_free_pages.part.0+0x8a>
    prev->next = next->prev = elm;
ffffffffc02009d4:	e390                	sd	a2,0(a5)
ffffffffc02009d6:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc02009d8:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc02009da:	ed1c                	sd	a5,24(a0)
    if (le != &free_list) {
ffffffffc02009dc:	8082                	ret
static void slub_free_pages(struct Page *base, size_t n) {
ffffffffc02009de:	1141                	addi	sp,sp,-16
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc02009e0:	00001697          	auipc	a3,0x1
ffffffffc02009e4:	3e868693          	addi	a3,a3,1000 # ffffffffc0201dc8 <etext+0x42e>
ffffffffc02009e8:	00001617          	auipc	a2,0x1
ffffffffc02009ec:	3b060613          	addi	a2,a2,944 # ffffffffc0201d98 <etext+0x3fe>
ffffffffc02009f0:	0bd00593          	li	a1,189
ffffffffc02009f4:	00001517          	auipc	a0,0x1
ffffffffc02009f8:	3bc50513          	addi	a0,a0,956 # ffffffffc0201db0 <etext+0x416>
static void slub_free_pages(struct Page *base, size_t n) {
ffffffffc02009fc:	e406                	sd	ra,8(sp)
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc02009fe:	fc8ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc0200a02 <slub_free_pages>:
    assert(n > 0);
ffffffffc0200a02:	c191                	beqz	a1,ffffffffc0200a06 <slub_free_pages+0x4>
ffffffffc0200a04:	bd45                	j	ffffffffc02008b4 <slub_free_pages.part.0>
static void slub_free_pages(struct Page *base, size_t n) {
ffffffffc0200a06:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc0200a08:	00001697          	auipc	a3,0x1
ffffffffc0200a0c:	38868693          	addi	a3,a3,904 # ffffffffc0201d90 <etext+0x3f6>
ffffffffc0200a10:	00001617          	auipc	a2,0x1
ffffffffc0200a14:	38860613          	addi	a2,a2,904 # ffffffffc0201d98 <etext+0x3fe>
ffffffffc0200a18:	0b900593          	li	a1,185
ffffffffc0200a1c:	00001517          	auipc	a0,0x1
ffffffffc0200a20:	39450513          	addi	a0,a0,916 # ffffffffc0201db0 <etext+0x416>
static void slub_free_pages(struct Page *base, size_t n) {
ffffffffc0200a24:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200a26:	fa0ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc0200a2a <pa2page.part.0>:
static inline struct Page *pa2page(uintptr_t pa) {
ffffffffc0200a2a:	1141                	addi	sp,sp,-16
        panic("pa2page called with invalid pa");
ffffffffc0200a2c:	00001617          	auipc	a2,0x1
ffffffffc0200a30:	28c60613          	addi	a2,a2,652 # ffffffffc0201cb8 <etext+0x31e>
ffffffffc0200a34:	06a00593          	li	a1,106
ffffffffc0200a38:	00001517          	auipc	a0,0x1
ffffffffc0200a3c:	2a050513          	addi	a0,a0,672 # ffffffffc0201cd8 <etext+0x33e>
static inline struct Page *pa2page(uintptr_t pa) {
ffffffffc0200a40:	e406                	sd	ra,8(sp)
        panic("pa2page called with invalid pa");
ffffffffc0200a42:	f84ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc0200a46 <slub_init_memmap>:
static void slub_init_memmap(struct Page *base, size_t n) {
ffffffffc0200a46:	1141                	addi	sp,sp,-16
ffffffffc0200a48:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200a4a:	c5f9                	beqz	a1,ffffffffc0200b18 <slub_init_memmap+0xd2>
    for (; p != base + n; p++) {
ffffffffc0200a4c:	00259693          	slli	a3,a1,0x2
ffffffffc0200a50:	96ae                	add	a3,a3,a1
ffffffffc0200a52:	068e                	slli	a3,a3,0x3
ffffffffc0200a54:	96aa                	add	a3,a3,a0
ffffffffc0200a56:	87aa                	mv	a5,a0
ffffffffc0200a58:	00d50f63          	beq	a0,a3,ffffffffc0200a76 <slub_init_memmap+0x30>
        assert(PageReserved(p));
ffffffffc0200a5c:	6798                	ld	a4,8(a5)
ffffffffc0200a5e:	8b05                	andi	a4,a4,1
ffffffffc0200a60:	cf41                	beqz	a4,ffffffffc0200af8 <slub_init_memmap+0xb2>
        p->flags = p->property = 0;
ffffffffc0200a62:	0007a823          	sw	zero,16(a5)
ffffffffc0200a66:	0007b423          	sd	zero,8(a5)
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200a6a:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p++) {
ffffffffc0200a6e:	02878793          	addi	a5,a5,40
ffffffffc0200a72:	fed795e3          	bne	a5,a3,ffffffffc0200a5c <slub_init_memmap+0x16>
    SetPageProperty(base);
ffffffffc0200a76:	6510                	ld	a2,8(a0)
    nr_free += n;
ffffffffc0200a78:	00005697          	auipc	a3,0x5
ffffffffc0200a7c:	5b068693          	addi	a3,a3,1456 # ffffffffc0206028 <free_area>
ffffffffc0200a80:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc0200a82:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc0200a84:	00266613          	ori	a2,a2,2
    return list->next == list;
ffffffffc0200a88:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc0200a8a:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0200a8c:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc0200a8e:	9db9                	addw	a1,a1,a4
ffffffffc0200a90:	ca8c                	sw	a1,16(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc0200a92:	01850613          	addi	a2,a0,24
    if (list_empty(&free_list)) {
ffffffffc0200a96:	04d78a63          	beq	a5,a3,ffffffffc0200aea <slub_init_memmap+0xa4>
            struct Page *page = le2page(le, page_link);
ffffffffc0200a9a:	fe878713          	addi	a4,a5,-24
ffffffffc0200a9e:	0006b803          	ld	a6,0(a3)
    if (list_empty(&free_list)) {
ffffffffc0200aa2:	4581                	li	a1,0
            if (base < page) {
ffffffffc0200aa4:	00e56a63          	bltu	a0,a4,ffffffffc0200ab8 <slub_init_memmap+0x72>
    return listelm->next;
ffffffffc0200aa8:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0200aaa:	02d70263          	beq	a4,a3,ffffffffc0200ace <slub_init_memmap+0x88>
    for (; p != base + n; p++) {
ffffffffc0200aae:	87ba                	mv	a5,a4
            struct Page *page = le2page(le, page_link);
ffffffffc0200ab0:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc0200ab4:	fee57ae3          	bgeu	a0,a4,ffffffffc0200aa8 <slub_init_memmap+0x62>
ffffffffc0200ab8:	c199                	beqz	a1,ffffffffc0200abe <slub_init_memmap+0x78>
ffffffffc0200aba:	0106b023          	sd	a6,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200abe:	6398                	ld	a4,0(a5)
}
ffffffffc0200ac0:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0200ac2:	e390                	sd	a2,0(a5)
ffffffffc0200ac4:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc0200ac6:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200ac8:	ed18                	sd	a4,24(a0)
ffffffffc0200aca:	0141                	addi	sp,sp,16
ffffffffc0200acc:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc0200ace:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200ad0:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc0200ad2:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc0200ad4:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc0200ad6:	00d70663          	beq	a4,a3,ffffffffc0200ae2 <slub_init_memmap+0x9c>
    prev->next = next->prev = elm;
ffffffffc0200ada:	8832                	mv	a6,a2
ffffffffc0200adc:	4585                	li	a1,1
    for (; p != base + n; p++) {
ffffffffc0200ade:	87ba                	mv	a5,a4
ffffffffc0200ae0:	bfc1                	j	ffffffffc0200ab0 <slub_init_memmap+0x6a>
}
ffffffffc0200ae2:	60a2                	ld	ra,8(sp)
ffffffffc0200ae4:	e290                	sd	a2,0(a3)
ffffffffc0200ae6:	0141                	addi	sp,sp,16
ffffffffc0200ae8:	8082                	ret
ffffffffc0200aea:	60a2                	ld	ra,8(sp)
ffffffffc0200aec:	e390                	sd	a2,0(a5)
ffffffffc0200aee:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200af0:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200af2:	ed1c                	sd	a5,24(a0)
ffffffffc0200af4:	0141                	addi	sp,sp,16
ffffffffc0200af6:	8082                	ret
        assert(PageReserved(p));
ffffffffc0200af8:	00001697          	auipc	a3,0x1
ffffffffc0200afc:	2f868693          	addi	a3,a3,760 # ffffffffc0201df0 <etext+0x456>
ffffffffc0200b00:	00001617          	auipc	a2,0x1
ffffffffc0200b04:	29860613          	addi	a2,a2,664 # ffffffffc0201d98 <etext+0x3fe>
ffffffffc0200b08:	07800593          	li	a1,120
ffffffffc0200b0c:	00001517          	auipc	a0,0x1
ffffffffc0200b10:	2a450513          	addi	a0,a0,676 # ffffffffc0201db0 <etext+0x416>
ffffffffc0200b14:	eb2ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(n > 0);
ffffffffc0200b18:	00001697          	auipc	a3,0x1
ffffffffc0200b1c:	27868693          	addi	a3,a3,632 # ffffffffc0201d90 <etext+0x3f6>
ffffffffc0200b20:	00001617          	auipc	a2,0x1
ffffffffc0200b24:	27860613          	addi	a2,a2,632 # ffffffffc0201d98 <etext+0x3fe>
ffffffffc0200b28:	07400593          	li	a1,116
ffffffffc0200b2c:	00001517          	auipc	a0,0x1
ffffffffc0200b30:	28450513          	addi	a0,a0,644 # ffffffffc0201db0 <etext+0x416>
ffffffffc0200b34:	e92ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc0200b38 <free_slab.part.0>:
static void free_slab(struct slab *slab) {
ffffffffc0200b38:	7179                	addi	sp,sp,-48
    uintptr_t s_mem_pa = (uintptr_t)slab->s_mem - PHYSICAL_MEMORY_OFFSET;
ffffffffc0200b3a:	651c                	ld	a5,8(a0)
static void free_slab(struct slab *slab) {
ffffffffc0200b3c:	e44e                	sd	s3,8(sp)
    uintptr_t s_mem_pa = (uintptr_t)slab->s_mem - PHYSICAL_MEMORY_OFFSET;
ffffffffc0200b3e:	470d                	li	a4,3
    if (PPN(pa) >= npage) {
ffffffffc0200b40:	00005997          	auipc	s3,0x5
ffffffffc0200b44:	58098993          	addi	s3,s3,1408 # ffffffffc02060c0 <npage>
ffffffffc0200b48:	077a                	slli	a4,a4,0x1e
ffffffffc0200b4a:	0009b683          	ld	a3,0(s3)
ffffffffc0200b4e:	97ba                	add	a5,a5,a4
static void free_slab(struct slab *slab) {
ffffffffc0200b50:	f406                	sd	ra,40(sp)
ffffffffc0200b52:	f022                	sd	s0,32(sp)
ffffffffc0200b54:	ec26                	sd	s1,24(sp)
ffffffffc0200b56:	e84a                	sd	s2,16(sp)
ffffffffc0200b58:	83b1                	srli	a5,a5,0xc
ffffffffc0200b5a:	08d7fd63          	bgeu	a5,a3,ffffffffc0200bf4 <free_slab.part.0+0xbc>
    return &pages[PPN(pa) - nbase];
ffffffffc0200b5e:	00002917          	auipc	s2,0x2
ffffffffc0200b62:	90293903          	ld	s2,-1790(s2) # ffffffffc0202460 <nbase>
ffffffffc0200b66:	412787b3          	sub	a5,a5,s2
ffffffffc0200b6a:	00005497          	auipc	s1,0x5
ffffffffc0200b6e:	55e48493          	addi	s1,s1,1374 # ffffffffc02060c8 <pages>
ffffffffc0200b72:	842a                	mv	s0,a0
ffffffffc0200b74:	00279713          	slli	a4,a5,0x2
ffffffffc0200b78:	6088                	ld	a0,0(s1)
ffffffffc0200b7a:	97ba                	add	a5,a5,a4
ffffffffc0200b7c:	078e                	slli	a5,a5,0x3
ffffffffc0200b7e:	953e                	add	a0,a0,a5
    if (page) {
ffffffffc0200b80:	c511                	beqz	a0,ffffffffc0200b8c <free_slab.part.0+0x54>
    assert(n > 0);
ffffffffc0200b82:	4585                	li	a1,1
ffffffffc0200b84:	d31ff0ef          	jal	ra,ffffffffc02008b4 <slub_free_pages.part.0>
    if (PPN(pa) >= npage) {
ffffffffc0200b88:	0009b683          	ld	a3,0(s3)
    if (slab->freelist) {
ffffffffc0200b8c:	6c1c                	ld	a5,24(s0)
ffffffffc0200b8e:	c78d                	beqz	a5,ffffffffc0200bb8 <free_slab.part.0+0x80>
        uintptr_t freelist_pa = (uintptr_t)slab->freelist - PHYSICAL_MEMORY_OFFSET;
ffffffffc0200b90:	470d                	li	a4,3
ffffffffc0200b92:	077a                	slli	a4,a4,0x1e
ffffffffc0200b94:	97ba                	add	a5,a5,a4
ffffffffc0200b96:	83b1                	srli	a5,a5,0xc
ffffffffc0200b98:	04d7fe63          	bgeu	a5,a3,ffffffffc0200bf4 <free_slab.part.0+0xbc>
    return &pages[PPN(pa) - nbase];
ffffffffc0200b9c:	412787b3          	sub	a5,a5,s2
ffffffffc0200ba0:	6088                	ld	a0,0(s1)
ffffffffc0200ba2:	00279713          	slli	a4,a5,0x2
ffffffffc0200ba6:	97ba                	add	a5,a5,a4
ffffffffc0200ba8:	078e                	slli	a5,a5,0x3
ffffffffc0200baa:	953e                	add	a0,a0,a5
        if (freelist_page) {
ffffffffc0200bac:	c511                	beqz	a0,ffffffffc0200bb8 <free_slab.part.0+0x80>
    assert(n > 0);
ffffffffc0200bae:	4585                	li	a1,1
ffffffffc0200bb0:	d05ff0ef          	jal	ra,ffffffffc02008b4 <slub_free_pages.part.0>
    if (PPN(pa) >= npage) {
ffffffffc0200bb4:	0009b683          	ld	a3,0(s3)
    uintptr_t slab_pa = (uintptr_t)slab - PHYSICAL_MEMORY_OFFSET;
ffffffffc0200bb8:	450d                	li	a0,3
ffffffffc0200bba:	057a                	slli	a0,a0,0x1e
ffffffffc0200bbc:	942a                	add	s0,s0,a0
ffffffffc0200bbe:	8031                	srli	s0,s0,0xc
ffffffffc0200bc0:	02d47a63          	bgeu	s0,a3,ffffffffc0200bf4 <free_slab.part.0+0xbc>
    return &pages[PPN(pa) - nbase];
ffffffffc0200bc4:	41240433          	sub	s0,s0,s2
ffffffffc0200bc8:	6088                	ld	a0,0(s1)
ffffffffc0200bca:	00241793          	slli	a5,s0,0x2
ffffffffc0200bce:	943e                	add	s0,s0,a5
ffffffffc0200bd0:	040e                	slli	s0,s0,0x3
ffffffffc0200bd2:	9522                	add	a0,a0,s0
    if (slab_page) {
ffffffffc0200bd4:	c909                	beqz	a0,ffffffffc0200be6 <free_slab.part.0+0xae>
}
ffffffffc0200bd6:	7402                	ld	s0,32(sp)
ffffffffc0200bd8:	70a2                	ld	ra,40(sp)
ffffffffc0200bda:	64e2                	ld	s1,24(sp)
ffffffffc0200bdc:	6942                	ld	s2,16(sp)
ffffffffc0200bde:	69a2                	ld	s3,8(sp)
ffffffffc0200be0:	4585                	li	a1,1
ffffffffc0200be2:	6145                	addi	sp,sp,48
ffffffffc0200be4:	b9c1                	j	ffffffffc02008b4 <slub_free_pages.part.0>
ffffffffc0200be6:	70a2                	ld	ra,40(sp)
ffffffffc0200be8:	7402                	ld	s0,32(sp)
ffffffffc0200bea:	64e2                	ld	s1,24(sp)
ffffffffc0200bec:	6942                	ld	s2,16(sp)
ffffffffc0200bee:	69a2                	ld	s3,8(sp)
ffffffffc0200bf0:	6145                	addi	sp,sp,48
ffffffffc0200bf2:	8082                	ret
ffffffffc0200bf4:	e37ff0ef          	jal	ra,ffffffffc0200a2a <pa2page.part.0>

ffffffffc0200bf8 <kmem_cache_free.part.0>:
void kmem_cache_free(struct kmem_cache *cache, void *obj) {
ffffffffc0200bf8:	1141                	addi	sp,sp,-16
ffffffffc0200bfa:	e022                	sd	s0,0(sp)
ffffffffc0200bfc:	e406                	sd	ra,8(sp)
ffffffffc0200bfe:	842a                	mv	s0,a0
    spin_lock(&cache->cpu_slab.lock);
ffffffffc0200c00:	03450713          	addi	a4,a0,52
    while (__sync_lock_test_and_set(lock, 1)) {
ffffffffc0200c04:	4685                	li	a3,1
ffffffffc0200c06:	87b6                	mv	a5,a3
ffffffffc0200c08:	0cf727af          	amoswap.w.aq	a5,a5,(a4)
ffffffffc0200c0c:	2781                	sext.w	a5,a5
ffffffffc0200c0e:	ffe5                	bnez	a5,ffffffffc0200c06 <kmem_cache_free.part.0+0xe>
    struct slab *c_slab = cache->cpu_slab.slab;
ffffffffc0200c10:	7408                	ld	a0,40(s0)
    if (c_slab && obj_to_slab(obj) == c_slab->s_mem) {
ffffffffc0200c12:	c511                	beqz	a0,ffffffffc0200c1e <kmem_cache_free.part.0+0x26>
ffffffffc0200c14:	6518                	ld	a4,8(a0)
    return (void *)((uintptr_t)obj & ~(PGSIZE - 1));
ffffffffc0200c16:	77fd                	lui	a5,0xfffff
ffffffffc0200c18:	8fed                	and	a5,a5,a1
    if (c_slab && obj_to_slab(obj) == c_slab->s_mem) {
ffffffffc0200c1a:	08f70b63          	beq	a4,a5,ffffffffc0200cb0 <kmem_cache_free.part.0+0xb8>
        spin_lock(&cache->node.list_lock);
ffffffffc0200c1e:	03840713          	addi	a4,s0,56
    while (__sync_lock_test_and_set(lock, 1)) {
ffffffffc0200c22:	4685                	li	a3,1
ffffffffc0200c24:	87b6                	mv	a5,a3
ffffffffc0200c26:	0cf727af          	amoswap.w.aq	a5,a5,(a4)
ffffffffc0200c2a:	2781                	sext.w	a5,a5
ffffffffc0200c2c:	ffe5                	bnez	a5,ffffffffc0200c24 <kmem_cache_free.part.0+0x2c>
        list_entry_t *le = &cache->node.partial;
ffffffffc0200c2e:	04840693          	addi	a3,s0,72
    return (void *)((uintptr_t)obj & ~(PGSIZE - 1));
ffffffffc0200c32:	777d                	lui	a4,0xfffff
        list_entry_t *le = &cache->node.partial;
ffffffffc0200c34:	8536                	mv	a0,a3
    return (void *)((uintptr_t)obj & ~(PGSIZE - 1));
ffffffffc0200c36:	8df9                	and	a1,a1,a4
        while ((le = list_next(le)) != &cache->node.partial) {
ffffffffc0200c38:	a029                	j	ffffffffc0200c42 <kmem_cache_free.part.0+0x4a>
            if (obj_to_slab(obj) == s->s_mem) {
ffffffffc0200c3a:	fe853703          	ld	a4,-24(a0)
ffffffffc0200c3e:	02b70b63          	beq	a4,a1,ffffffffc0200c74 <kmem_cache_free.part.0+0x7c>
    return listelm->next;
ffffffffc0200c42:	6508                	ld	a0,8(a0)
        while ((le = list_next(le)) != &cache->node.partial) {
ffffffffc0200c44:	fea69be3          	bne	a3,a0,ffffffffc0200c3a <kmem_cache_free.part.0+0x42>
    __sync_lock_release(lock);
ffffffffc0200c48:	03840793          	addi	a5,s0,56
ffffffffc0200c4c:	0f50000f          	fence	iorw,ow
ffffffffc0200c50:	0807a02f          	amoswap.w	zero,zero,(a5)
    cache->num_frees++;
ffffffffc0200c54:	7038                	ld	a4,96(s0)
    cache->cpu_slab.tid++;
ffffffffc0200c56:	581c                	lw	a5,48(s0)
    cache->num_frees++;
ffffffffc0200c58:	0705                	addi	a4,a4,1
    cache->cpu_slab.tid++;
ffffffffc0200c5a:	2785                	addiw	a5,a5,1
    cache->num_frees++;
ffffffffc0200c5c:	f038                	sd	a4,96(s0)
    cache->cpu_slab.tid++;
ffffffffc0200c5e:	d81c                	sw	a5,48(s0)
    __sync_lock_release(lock);
ffffffffc0200c60:	03440793          	addi	a5,s0,52
ffffffffc0200c64:	0f50000f          	fence	iorw,ow
ffffffffc0200c68:	0807a02f          	amoswap.w	zero,zero,(a5)
}
ffffffffc0200c6c:	60a2                	ld	ra,8(sp)
ffffffffc0200c6e:	6402                	ld	s0,0(sp)
ffffffffc0200c70:	0141                	addi	sp,sp,16
ffffffffc0200c72:	8082                	ret
            slab->inuse--;
ffffffffc0200c74:	ff052703          	lw	a4,-16(a0)
            slab->free++;
ffffffffc0200c78:	ff452683          	lw	a3,-12(a0)
            slab->inuse--;
ffffffffc0200c7c:	fff7061b          	addiw	a2,a4,-1
            slab->free++;
ffffffffc0200c80:	2685                	addiw	a3,a3,1
            slab->inuse--;
ffffffffc0200c82:	fec52823          	sw	a2,-16(a0)
            slab->free++;
ffffffffc0200c86:	fed52a23          	sw	a3,-12(a0)
            if (slab->inuse == 0) {
ffffffffc0200c8a:	fe5d                	bnez	a2,ffffffffc0200c48 <kmem_cache_free.part.0+0x50>
    __list_del(listelm->prev, listelm->next);
ffffffffc0200c8c:	6110                	ld	a2,0(a0)
ffffffffc0200c8e:	6514                	ld	a3,8(a0)
                cache->node.nr_partial--;
ffffffffc0200c90:	6038                	ld	a4,64(s0)
    if (!slab || slab->magic != SLAB_MAGIC) return;
ffffffffc0200c92:	490c                	lw	a1,16(a0)
    prev->next = next;
ffffffffc0200c94:	e614                	sd	a3,8(a2)
                cache->node.nr_partial--;
ffffffffc0200c96:	177d                	addi	a4,a4,-1
    next->prev = prev;
ffffffffc0200c98:	e290                	sd	a2,0(a3)
ffffffffc0200c9a:	e038                	sd	a4,64(s0)
    if (!slab || slab->magic != SLAB_MAGIC) return;
ffffffffc0200c9c:	12345737          	lui	a4,0x12345
ffffffffc0200ca0:	67870713          	addi	a4,a4,1656 # 12345678 <kern_entry-0xffffffffadeba988>
ffffffffc0200ca4:	fae592e3          	bne	a1,a4,ffffffffc0200c48 <kmem_cache_free.part.0+0x50>
ffffffffc0200ca8:	1501                	addi	a0,a0,-32
ffffffffc0200caa:	e8fff0ef          	jal	ra,ffffffffc0200b38 <free_slab.part.0>
ffffffffc0200cae:	bf69                	j	ffffffffc0200c48 <kmem_cache_free.part.0+0x50>
    void **c_freelist = cache->cpu_slab.freelist;
ffffffffc0200cb0:	7014                	ld	a3,32(s0)
        c_slab->inuse--;
ffffffffc0200cb2:	491c                	lw	a5,16(a0)
        c_slab->free++;
ffffffffc0200cb4:	4958                	lw	a4,20(a0)
        *(void **)obj = c_freelist;
ffffffffc0200cb6:	e194                	sd	a3,0(a1)
        c_slab->inuse--;
ffffffffc0200cb8:	fff7869b          	addiw	a3,a5,-1
        c_slab->free++;
ffffffffc0200cbc:	2705                	addiw	a4,a4,1
        c_slab->inuse--;
ffffffffc0200cbe:	c914                	sw	a3,16(a0)
        c_slab->free++;
ffffffffc0200cc0:	c958                	sw	a4,20(a0)
        if (c_slab->inuse == 0) {
ffffffffc0200cc2:	fac9                	bnez	a3,ffffffffc0200c54 <kmem_cache_free.part.0+0x5c>
            spin_lock(&cache->node.list_lock);
ffffffffc0200cc4:	03840713          	addi	a4,s0,56
    while (__sync_lock_test_and_set(lock, 1)) {
ffffffffc0200cc8:	4685                	li	a3,1
ffffffffc0200cca:	87b6                	mv	a5,a3
ffffffffc0200ccc:	0cf727af          	amoswap.w.aq	a5,a5,(a4)
ffffffffc0200cd0:	2781                	sext.w	a5,a5
ffffffffc0200cd2:	ffe5                	bnez	a5,ffffffffc0200cca <kmem_cache_free.part.0+0xd2>
            if (cache->node.nr_partial < 10) { // 保持一些partial slab
ffffffffc0200cd4:	603c                	ld	a5,64(s0)
ffffffffc0200cd6:	4725                	li	a4,9
ffffffffc0200cd8:	00f76e63          	bltu	a4,a5,ffffffffc0200cf4 <kmem_cache_free.part.0+0xfc>
    __list_add(elm, listelm, listelm->next);
ffffffffc0200cdc:	6834                	ld	a3,80(s0)
                list_add(&cache->node.partial, &c_slab->list);
ffffffffc0200cde:	02050613          	addi	a2,a0,32
ffffffffc0200ce2:	04840713          	addi	a4,s0,72
    prev->next = next->prev = elm;
ffffffffc0200ce6:	e290                	sd	a2,0(a3)
ffffffffc0200ce8:	e830                	sd	a2,80(s0)
    elm->next = next;
ffffffffc0200cea:	f514                	sd	a3,40(a0)
    elm->prev = prev;
ffffffffc0200cec:	f118                	sd	a4,32(a0)
                cache->node.nr_partial++;
ffffffffc0200cee:	0785                	addi	a5,a5,1
ffffffffc0200cf0:	e03c                	sd	a5,64(s0)
ffffffffc0200cf2:	bf99                	j	ffffffffc0200c48 <kmem_cache_free.part.0+0x50>
    if (!slab || slab->magic != SLAB_MAGIC) return;
ffffffffc0200cf4:	5918                	lw	a4,48(a0)
ffffffffc0200cf6:	123457b7          	lui	a5,0x12345
ffffffffc0200cfa:	67878793          	addi	a5,a5,1656 # 12345678 <kern_entry-0xffffffffadeba988>
ffffffffc0200cfe:	f4f715e3          	bne	a4,a5,ffffffffc0200c48 <kmem_cache_free.part.0+0x50>
ffffffffc0200d02:	b765                	j	ffffffffc0200caa <kmem_cache_free.part.0+0xb2>

ffffffffc0200d04 <kfree.part.0>:
    return (void *)((uintptr_t)obj & ~(PGSIZE - 1));
ffffffffc0200d04:	767d                	lui	a2,0xfffff
    uintptr_t slab_pa = (uintptr_t)slab_addr - PHYSICAL_MEMORY_OFFSET;
ffffffffc0200d06:	478d                	li	a5,3
    return (void *)((uintptr_t)obj & ~(PGSIZE - 1));
ffffffffc0200d08:	8e69                	and	a2,a2,a0
    uintptr_t slab_pa = (uintptr_t)slab_addr - PHYSICAL_MEMORY_OFFSET;
ffffffffc0200d0a:	07fa                	slli	a5,a5,0x1e
ffffffffc0200d0c:	97b2                	add	a5,a5,a2
    if (PPN(pa) >= npage) {
ffffffffc0200d0e:	83b1                	srli	a5,a5,0xc
ffffffffc0200d10:	00005717          	auipc	a4,0x5
ffffffffc0200d14:	3b073703          	ld	a4,944(a4) # ffffffffc02060c0 <npage>
ffffffffc0200d18:	08e7fa63          	bgeu	a5,a4,ffffffffc0200dac <kfree.part.0+0xa8>
    return &pages[PPN(pa) - nbase];
ffffffffc0200d1c:	00001717          	auipc	a4,0x1
ffffffffc0200d20:	74473703          	ld	a4,1860(a4) # ffffffffc0202460 <nbase>
ffffffffc0200d24:	8f99                	sub	a5,a5,a4
ffffffffc0200d26:	00279713          	slli	a4,a5,0x2
ffffffffc0200d2a:	97ba                	add	a5,a5,a4
ffffffffc0200d2c:	078e                	slli	a5,a5,0x3
ffffffffc0200d2e:	00005717          	auipc	a4,0x5
ffffffffc0200d32:	39a73703          	ld	a4,922(a4) # ffffffffc02060c8 <pages>
ffffffffc0200d36:	85aa                	mv	a1,a0
ffffffffc0200d38:	00f70533          	add	a0,a4,a5
    if (page && !PageProperty(page)) {
ffffffffc0200d3c:	c501                	beqz	a0,ffffffffc0200d44 <kfree.part.0+0x40>
ffffffffc0200d3e:	6518                	ld	a4,8(a0)
ffffffffc0200d40:	8b09                	andi	a4,a4,2
ffffffffc0200d42:	c33d                	beqz	a4,ffffffffc0200da8 <kfree.part.0+0xa4>
ffffffffc0200d44:	00005697          	auipc	a3,0x5
ffffffffc0200d48:	3ac68693          	addi	a3,a3,940 # ffffffffc02060f0 <cache_lock>
    while (__sync_lock_test_and_set(lock, 1)) {
ffffffffc0200d4c:	4705                	li	a4,1
ffffffffc0200d4e:	87ba                	mv	a5,a4
ffffffffc0200d50:	0cf6a7af          	amoswap.w.aq	a5,a5,(a3)
ffffffffc0200d54:	2781                	sext.w	a5,a5
ffffffffc0200d56:	ffe5                	bnez	a5,ffffffffc0200d4e <kfree.part.0+0x4a>
    return listelm->next;
ffffffffc0200d58:	00005817          	auipc	a6,0x5
ffffffffc0200d5c:	2c080813          	addi	a6,a6,704 # ffffffffc0206018 <cache_list>
ffffffffc0200d60:	00883783          	ld	a5,8(a6)
    while ((le = list_next(le)) != &cache_list) {
ffffffffc0200d64:	01078f63          	beq	a5,a6,ffffffffc0200d82 <kfree.part.0+0x7e>
            obj_to_slab(ptr) < (void *)((uintptr_t)cache->cpu_slab.slab->s_mem + PGSIZE)) {
ffffffffc0200d68:	6505                	lui	a0,0x1
        if (cache->cpu_slab.slab && 
ffffffffc0200d6a:	fc07b703          	ld	a4,-64(a5)
ffffffffc0200d6e:	c719                	beqz	a4,ffffffffc0200d7c <kfree.part.0+0x78>
            obj_to_slab(ptr) >= cache->cpu_slab.slab->s_mem && 
ffffffffc0200d70:	6718                	ld	a4,8(a4)
        if (cache->cpu_slab.slab && 
ffffffffc0200d72:	00e66563          	bltu	a2,a4,ffffffffc0200d7c <kfree.part.0+0x78>
            obj_to_slab(ptr) < (void *)((uintptr_t)cache->cpu_slab.slab->s_mem + PGSIZE)) {
ffffffffc0200d76:	972a                	add	a4,a4,a0
            obj_to_slab(ptr) >= cache->cpu_slab.slab->s_mem && 
ffffffffc0200d78:	00e66f63          	bltu	a2,a4,ffffffffc0200d96 <kfree.part.0+0x92>
ffffffffc0200d7c:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &cache_list) {
ffffffffc0200d7e:	ff0796e3          	bne	a5,a6,ffffffffc0200d6a <kfree.part.0+0x66>
    __sync_lock_release(lock);
ffffffffc0200d82:	0f50000f          	fence	iorw,ow
ffffffffc0200d86:	0806a02f          	amoswap.w	zero,zero,(a3)
    cprintf("slub: kfree called with invalid pointer %p\n", ptr);
ffffffffc0200d8a:	00001517          	auipc	a0,0x1
ffffffffc0200d8e:	07650513          	addi	a0,a0,118 # ffffffffc0201e00 <etext+0x466>
ffffffffc0200d92:	bbeff06f          	j	ffffffffc0200150 <cprintf>
    __sync_lock_release(lock);
ffffffffc0200d96:	0f50000f          	fence	iorw,ow
ffffffffc0200d9a:	0806a02f          	amoswap.w	zero,zero,(a3)
    if (!cache || !obj) return;
ffffffffc0200d9e:	c581                	beqz	a1,ffffffffc0200da6 <kfree.part.0+0xa2>
ffffffffc0200da0:	f9878513          	addi	a0,a5,-104
ffffffffc0200da4:	bd91                	j	ffffffffc0200bf8 <kmem_cache_free.part.0>
ffffffffc0200da6:	8082                	ret
    assert(n > 0);
ffffffffc0200da8:	4585                	li	a1,1
ffffffffc0200daa:	b629                	j	ffffffffc02008b4 <slub_free_pages.part.0>
void kfree(void *ptr) {
ffffffffc0200dac:	1141                	addi	sp,sp,-16
ffffffffc0200dae:	e406                	sd	ra,8(sp)
ffffffffc0200db0:	c7bff0ef          	jal	ra,ffffffffc0200a2a <pa2page.part.0>

ffffffffc0200db4 <kmem_cache_create>:
struct kmem_cache *kmem_cache_create(const char *name, size_t size, size_t align, unsigned int flags) {
ffffffffc0200db4:	715d                	addi	sp,sp,-80
ffffffffc0200db6:	fc26                	sd	s1,56(sp)
ffffffffc0200db8:	f84a                	sd	s2,48(sp)
ffffffffc0200dba:	f052                	sd	s4,32(sp)
ffffffffc0200dbc:	e486                	sd	ra,72(sp)
ffffffffc0200dbe:	e0a2                	sd	s0,64(sp)
ffffffffc0200dc0:	f44e                	sd	s3,40(sp)
ffffffffc0200dc2:	ec56                	sd	s5,24(sp)
ffffffffc0200dc4:	e85a                	sd	s6,16(sp)
ffffffffc0200dc6:	e45e                	sd	s7,8(sp)
ffffffffc0200dc8:	e062                	sd	s8,0(sp)
ffffffffc0200dca:	8a2a                	mv	s4,a0
ffffffffc0200dcc:	84ae                	mv	s1,a1
ffffffffc0200dce:	8936                	mv	s2,a3
    if (align == 0) align = sizeof(void *);
ffffffffc0200dd0:	12060463          	beqz	a2,ffffffffc0200ef8 <kmem_cache_create+0x144>
ffffffffc0200dd4:	8b32                	mv	s6,a2
    return (size + align - 1) & ~(align - 1);
ffffffffc0200dd6:	40c007b3          	neg	a5,a2
ffffffffc0200dda:	14fd                	addi	s1,s1,-1
ffffffffc0200ddc:	94da                	add	s1,s1,s6
    struct Page *page = slub_alloc_pages(1);
ffffffffc0200dde:	4505                	li	a0,1
    return (size + align - 1) & ~(align - 1);
ffffffffc0200de0:	8cfd                	and	s1,s1,a5
    struct Page *page = slub_alloc_pages(1);
ffffffffc0200de2:	a15ff0ef          	jal	ra,ffffffffc02007f6 <slub_alloc_pages>
ffffffffc0200de6:	842a                	mv	s0,a0
    if (!page) return NULL;
ffffffffc0200de8:	0e050b63          	beqz	a0,ffffffffc0200ede <kmem_cache_create+0x12a>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200dec:	00005c17          	auipc	s8,0x5
ffffffffc0200df0:	2dcc0c13          	addi	s8,s8,732 # ffffffffc02060c8 <pages>
ffffffffc0200df4:	000c3783          	ld	a5,0(s8)
ffffffffc0200df8:	00001b97          	auipc	s7,0x1
ffffffffc0200dfc:	670bbb83          	ld	s7,1648(s7) # ffffffffc0202468 <nbase+0x8>
ffffffffc0200e00:	00001997          	auipc	s3,0x1
ffffffffc0200e04:	6609b983          	ld	s3,1632(s3) # ffffffffc0202460 <nbase>
ffffffffc0200e08:	40f50433          	sub	s0,a0,a5
ffffffffc0200e0c:	840d                	srai	s0,s0,0x3
ffffffffc0200e0e:	03740433          	mul	s0,s0,s7
ffffffffc0200e12:	944e                	add	s0,s0,s3
    return page2ppn(page) << PGSHIFT;
ffffffffc0200e14:	00c41793          	slli	a5,s0,0xc
    return (void *)(page2pa(page) + PHYSICAL_MEMORY_OFFSET);
ffffffffc0200e18:	5475                	li	s0,-3
ffffffffc0200e1a:	047a                	slli	s0,s0,0x1e
ffffffffc0200e1c:	943e                	add	s0,s0,a5
    if (name) {
ffffffffc0200e1e:	040a0363          	beqz	s4,ffffffffc0200e64 <kmem_cache_create+0xb0>
        size_t name_len = strlen(name);
ffffffffc0200e22:	8552                	mv	a0,s4
ffffffffc0200e24:	2cf000ef          	jal	ra,ffffffffc02018f2 <strlen>
ffffffffc0200e28:	8aaa                	mv	s5,a0
        char *name_copy = (char *)page2kva(slub_alloc_pages(1));
ffffffffc0200e2a:	4505                	li	a0,1
ffffffffc0200e2c:	9cbff0ef          	jal	ra,ffffffffc02007f6 <slub_alloc_pages>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200e30:	000c3783          	ld	a5,0(s8)
        if (name_copy) {
ffffffffc0200e34:	470d                	li	a4,3
ffffffffc0200e36:	077a                	slli	a4,a4,0x1e
ffffffffc0200e38:	40f507b3          	sub	a5,a0,a5
ffffffffc0200e3c:	878d                	srai	a5,a5,0x3
ffffffffc0200e3e:	037787b3          	mul	a5,a5,s7
ffffffffc0200e42:	97ce                	add	a5,a5,s3
    return page2ppn(page) << PGSHIFT;
ffffffffc0200e44:	07b2                	slli	a5,a5,0xc
ffffffffc0200e46:	00e78f63          	beq	a5,a4,ffffffffc0200e64 <kmem_cache_create+0xb0>
    return (void *)(page2pa(page) + PHYSICAL_MEMORY_OFFSET);
ffffffffc0200e4a:	40e789b3          	sub	s3,a5,a4
            strncpy(name_copy, name, name_len);
ffffffffc0200e4e:	8656                	mv	a2,s5
ffffffffc0200e50:	85d2                	mv	a1,s4
ffffffffc0200e52:	854e                	mv	a0,s3
            name_copy[name_len] = '\0';
ffffffffc0200e54:	9ace                	add	s5,s5,s3
            strncpy(name_copy, name, name_len);
ffffffffc0200e56:	2d3000ef          	jal	ra,ffffffffc0201928 <strncpy>
            name_copy[name_len] = '\0';
ffffffffc0200e5a:	000a8023          	sb	zero,0(s5)
            cache->name = name_copy;
ffffffffc0200e5e:	01343023          	sd	s3,0(s0)
ffffffffc0200e62:	a031                	j	ffffffffc0200e6e <kmem_cache_create+0xba>
        cache->name = "unnamed";
ffffffffc0200e64:	00001797          	auipc	a5,0x1
ffffffffc0200e68:	fcc78793          	addi	a5,a5,-52 # ffffffffc0201e30 <etext+0x496>
ffffffffc0200e6c:	e01c                	sd	a5,0(s0)
    list_init(&cache->node.partial);
ffffffffc0200e6e:	04840793          	addi	a5,s0,72
    cache->size = size;
ffffffffc0200e72:	e404                	sd	s1,8(s0)
    cache->align = align;
ffffffffc0200e74:	01643823          	sd	s6,16(s0)
    cache->flags = flags;
ffffffffc0200e78:	01242c23          	sw	s2,24(s0)
    cache->cpu_slab.freelist = NULL;
ffffffffc0200e7c:	02043023          	sd	zero,32(s0)
    cache->cpu_slab.slab = NULL;
ffffffffc0200e80:	02043423          	sd	zero,40(s0)
    cache->cpu_slab.tid = 0;
ffffffffc0200e84:	02043823          	sd	zero,48(s0)
    cache->node.list_lock = 0;
ffffffffc0200e88:	02042c23          	sw	zero,56(s0)
    cache->node.nr_partial = 0;
ffffffffc0200e8c:	04043023          	sd	zero,64(s0)
    elm->prev = elm->next = elm;
ffffffffc0200e90:	e83c                	sd	a5,80(s0)
ffffffffc0200e92:	e43c                	sd	a5,72(s0)
    cache->num_allocations = 0;
ffffffffc0200e94:	04043c23          	sd	zero,88(s0)
    cache->num_frees = 0;
ffffffffc0200e98:	06043023          	sd	zero,96(s0)
    while (__sync_lock_test_and_set(lock, 1)) {
ffffffffc0200e9c:	00005717          	auipc	a4,0x5
ffffffffc0200ea0:	25470713          	addi	a4,a4,596 # ffffffffc02060f0 <cache_lock>
ffffffffc0200ea4:	4685                	li	a3,1
ffffffffc0200ea6:	87b6                	mv	a5,a3
ffffffffc0200ea8:	0cf727af          	amoswap.w.aq	a5,a5,(a4)
ffffffffc0200eac:	2781                	sext.w	a5,a5
ffffffffc0200eae:	ffe5                	bnez	a5,ffffffffc0200ea6 <kmem_cache_create+0xf2>
    __list_add(elm, listelm, listelm->next);
ffffffffc0200eb0:	00005797          	auipc	a5,0x5
ffffffffc0200eb4:	16878793          	addi	a5,a5,360 # ffffffffc0206018 <cache_list>
ffffffffc0200eb8:	6794                	ld	a3,8(a5)
    list_add(&cache_list, &cache->list);
ffffffffc0200eba:	06840613          	addi	a2,s0,104
    prev->next = next->prev = elm;
ffffffffc0200ebe:	e290                	sd	a2,0(a3)
ffffffffc0200ec0:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200ec2:	f834                	sd	a3,112(s0)
    elm->prev = prev;
ffffffffc0200ec4:	f43c                	sd	a5,104(s0)
    __sync_lock_release(lock);
ffffffffc0200ec6:	0f50000f          	fence	iorw,ow
ffffffffc0200eca:	0807202f          	amoswap.w	zero,zero,(a4)
    cprintf("slub: created cache '%s' with object size %lu\n", name, size);
ffffffffc0200ece:	8626                	mv	a2,s1
ffffffffc0200ed0:	85d2                	mv	a1,s4
ffffffffc0200ed2:	00001517          	auipc	a0,0x1
ffffffffc0200ed6:	f6650513          	addi	a0,a0,-154 # ffffffffc0201e38 <etext+0x49e>
ffffffffc0200eda:	a76ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
}
ffffffffc0200ede:	60a6                	ld	ra,72(sp)
ffffffffc0200ee0:	8522                	mv	a0,s0
ffffffffc0200ee2:	6406                	ld	s0,64(sp)
ffffffffc0200ee4:	74e2                	ld	s1,56(sp)
ffffffffc0200ee6:	7942                	ld	s2,48(sp)
ffffffffc0200ee8:	79a2                	ld	s3,40(sp)
ffffffffc0200eea:	7a02                	ld	s4,32(sp)
ffffffffc0200eec:	6ae2                	ld	s5,24(sp)
ffffffffc0200eee:	6b42                	ld	s6,16(sp)
ffffffffc0200ef0:	6ba2                	ld	s7,8(sp)
ffffffffc0200ef2:	6c02                	ld	s8,0(sp)
ffffffffc0200ef4:	6161                	addi	sp,sp,80
ffffffffc0200ef6:	8082                	ret
ffffffffc0200ef8:	57e1                	li	a5,-8
    if (align == 0) align = sizeof(void *);
ffffffffc0200efa:	4b21                	li	s6,8
ffffffffc0200efc:	bdf9                	j	ffffffffc0200dda <kmem_cache_create+0x26>

ffffffffc0200efe <kmem_cache_alloc>:
void *kmem_cache_alloc(struct kmem_cache *cache) {
ffffffffc0200efe:	715d                	addi	sp,sp,-80
ffffffffc0200f00:	e486                	sd	ra,72(sp)
ffffffffc0200f02:	e0a2                	sd	s0,64(sp)
ffffffffc0200f04:	fc26                	sd	s1,56(sp)
ffffffffc0200f06:	f84a                	sd	s2,48(sp)
ffffffffc0200f08:	f44e                	sd	s3,40(sp)
ffffffffc0200f0a:	f052                	sd	s4,32(sp)
ffffffffc0200f0c:	ec56                	sd	s5,24(sp)
ffffffffc0200f0e:	e85a                	sd	s6,16(sp)
ffffffffc0200f10:	e45e                	sd	s7,8(sp)
ffffffffc0200f12:	e062                	sd	s8,0(sp)
    if (!cache) return NULL;
ffffffffc0200f14:	c555                	beqz	a0,ffffffffc0200fc0 <kmem_cache_alloc+0xc2>
ffffffffc0200f16:	842a                	mv	s0,a0
    spin_lock(&cache->cpu_slab.lock);
ffffffffc0200f18:	03450713          	addi	a4,a0,52
    while (__sync_lock_test_and_set(lock, 1)) {
ffffffffc0200f1c:	4685                	li	a3,1
ffffffffc0200f1e:	87b6                	mv	a5,a3
ffffffffc0200f20:	0cf727af          	amoswap.w.aq	a5,a5,(a4)
ffffffffc0200f24:	2781                	sext.w	a5,a5
ffffffffc0200f26:	ffe5                	bnez	a5,ffffffffc0200f1e <kmem_cache_alloc+0x20>
    struct slab *c_slab = cache->cpu_slab.slab;
ffffffffc0200f28:	741c                	ld	a5,40(s0)
    void **c_freelist = cache->cpu_slab.freelist;
ffffffffc0200f2a:	7004                	ld	s1,32(s0)
    if (c_slab && c_freelist) {
ffffffffc0200f2c:	c3a9                	beqz	a5,ffffffffc0200f6e <kmem_cache_alloc+0x70>
ffffffffc0200f2e:	c0a1                	beqz	s1,ffffffffc0200f6e <kmem_cache_alloc+0x70>
        c_slab->inuse++;
ffffffffc0200f30:	4b94                	lw	a3,16(a5)
        c_slab->free--;
ffffffffc0200f32:	4bd8                	lw	a4,20(a5)
        c_slab->inuse++;
ffffffffc0200f34:	2685                	addiw	a3,a3,1
        c_slab->free--;
ffffffffc0200f36:	377d                	addiw	a4,a4,-1
        c_slab->inuse++;
ffffffffc0200f38:	cb94                	sw	a3,16(a5)
        c_slab->free--;
ffffffffc0200f3a:	cbd8                	sw	a4,20(a5)
    cache->num_allocations++;
ffffffffc0200f3c:	6c38                	ld	a4,88(s0)
    cache->cpu_slab.tid++;
ffffffffc0200f3e:	581c                	lw	a5,48(s0)
    cache->num_allocations++;
ffffffffc0200f40:	0705                	addi	a4,a4,1
    cache->cpu_slab.tid++;
ffffffffc0200f42:	2785                	addiw	a5,a5,1
    cache->num_allocations++;
ffffffffc0200f44:	ec38                	sd	a4,88(s0)
    cache->cpu_slab.tid++;
ffffffffc0200f46:	d81c                	sw	a5,48(s0)
    __sync_lock_release(lock);
ffffffffc0200f48:	03440793          	addi	a5,s0,52
ffffffffc0200f4c:	0f50000f          	fence	iorw,ow
ffffffffc0200f50:	0807a02f          	amoswap.w	zero,zero,(a5)
}
ffffffffc0200f54:	60a6                	ld	ra,72(sp)
ffffffffc0200f56:	6406                	ld	s0,64(sp)
ffffffffc0200f58:	7942                	ld	s2,48(sp)
ffffffffc0200f5a:	79a2                	ld	s3,40(sp)
ffffffffc0200f5c:	7a02                	ld	s4,32(sp)
ffffffffc0200f5e:	6ae2                	ld	s5,24(sp)
ffffffffc0200f60:	6b42                	ld	s6,16(sp)
ffffffffc0200f62:	6ba2                	ld	s7,8(sp)
ffffffffc0200f64:	6c02                	ld	s8,0(sp)
ffffffffc0200f66:	8526                	mv	a0,s1
ffffffffc0200f68:	74e2                	ld	s1,56(sp)
ffffffffc0200f6a:	6161                	addi	sp,sp,80
ffffffffc0200f6c:	8082                	ret
        spin_lock(&cache->node.list_lock);
ffffffffc0200f6e:	03840713          	addi	a4,s0,56
    while (__sync_lock_test_and_set(lock, 1)) {
ffffffffc0200f72:	4685                	li	a3,1
ffffffffc0200f74:	87b6                	mv	a5,a3
ffffffffc0200f76:	0cf727af          	amoswap.w.aq	a5,a5,(a4)
ffffffffc0200f7a:	2781                	sext.w	a5,a5
ffffffffc0200f7c:	ffe5                	bnez	a5,ffffffffc0200f74 <kmem_cache_alloc+0x76>
    return list->next == list;
ffffffffc0200f7e:	683c                	ld	a5,80(s0)
        if (!list_empty(&cache->node.partial)) {
ffffffffc0200f80:	04840713          	addi	a4,s0,72
ffffffffc0200f84:	04e78063          	beq	a5,a4,ffffffffc0200fc4 <kmem_cache_alloc+0xc6>
    __list_del(listelm->prev, listelm->next);
ffffffffc0200f88:	6388                	ld	a0,0(a5)
ffffffffc0200f8a:	678c                	ld	a1,8(a5)
            cache->node.nr_partial--;
ffffffffc0200f8c:	6030                	ld	a2,64(s0)
            c_slab->inuse++;
ffffffffc0200f8e:	ff07a683          	lw	a3,-16(a5)
            c_slab->free--;
ffffffffc0200f92:	ff47a703          	lw	a4,-12(a5)
            c_freelist = slab->freelist[0];
ffffffffc0200f96:	ff87b803          	ld	a6,-8(a5)
    prev->next = next;
ffffffffc0200f9a:	e50c                	sd	a1,8(a0)
    next->prev = prev;
ffffffffc0200f9c:	e188                	sd	a0,0(a1)
            cache->node.nr_partial--;
ffffffffc0200f9e:	167d                	addi	a2,a2,-1
ffffffffc0200fa0:	e030                	sd	a2,64(s0)
            c_slab->inuse++;
ffffffffc0200fa2:	2685                	addiw	a3,a3,1
            c_slab->free--;
ffffffffc0200fa4:	377d                	addiw	a4,a4,-1
            c_freelist = slab->freelist[0];
ffffffffc0200fa6:	00083483          	ld	s1,0(a6)
            c_slab->inuse++;
ffffffffc0200faa:	fed7a823          	sw	a3,-16(a5)
            c_slab->free--;
ffffffffc0200fae:	fee7aa23          	sw	a4,-12(a5)
    __sync_lock_release(lock);
ffffffffc0200fb2:	03840793          	addi	a5,s0,56
ffffffffc0200fb6:	0f50000f          	fence	iorw,ow
ffffffffc0200fba:	0807a02f          	amoswap.w	zero,zero,(a5)
}
ffffffffc0200fbe:	bfbd                	j	ffffffffc0200f3c <kmem_cache_alloc+0x3e>
    if (!cache) return NULL;
ffffffffc0200fc0:	4481                	li	s1,0
ffffffffc0200fc2:	bf49                	j	ffffffffc0200f54 <kmem_cache_alloc+0x56>
    __sync_lock_release(lock);
ffffffffc0200fc4:	03840793          	addi	a5,s0,56
ffffffffc0200fc8:	0f50000f          	fence	iorw,ow
ffffffffc0200fcc:	0807a02f          	amoswap.w	zero,zero,(a5)
    struct Page *page = slub_alloc_pages(1);
ffffffffc0200fd0:	4505                	li	a0,1
ffffffffc0200fd2:	825ff0ef          	jal	ra,ffffffffc02007f6 <slub_alloc_pages>
ffffffffc0200fd6:	84aa                	mv	s1,a0
    if (!page) return NULL;
ffffffffc0200fd8:	d135                	beqz	a0,ffffffffc0200f3c <kmem_cache_alloc+0x3e>
    struct Page *slab_page = slub_alloc_pages(1);
ffffffffc0200fda:	4505                	li	a0,1
ffffffffc0200fdc:	81bff0ef          	jal	ra,ffffffffc02007f6 <slub_alloc_pages>
ffffffffc0200fe0:	8aaa                	mv	s5,a0
    if (!slab_page) {
ffffffffc0200fe2:	10050663          	beqz	a0,ffffffffc02010ee <kmem_cache_alloc+0x1f0>
    size_t obj_size = cache->size;
ffffffffc0200fe6:	00843983          	ld	s3,8(s0)
    unsigned int num_objs = slab_size / obj_size;
ffffffffc0200fea:	6705                	lui	a4,0x1
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200fec:	00005c17          	auipc	s8,0x5
ffffffffc0200ff0:	0dcc0c13          	addi	s8,s8,220 # ffffffffc02060c8 <pages>
ffffffffc0200ff4:	03375733          	divu	a4,a4,s3
ffffffffc0200ff8:	000c3783          	ld	a5,0(s8)
ffffffffc0200ffc:	00001b97          	auipc	s7,0x1
ffffffffc0201000:	46cbbb83          	ld	s7,1132(s7) # ffffffffc0202468 <nbase+0x8>
ffffffffc0201004:	00001b17          	auipc	s6,0x1
ffffffffc0201008:	45cb3b03          	ld	s6,1116(s6) # ffffffffc0202460 <nbase>
ffffffffc020100c:	40f50933          	sub	s2,a0,a5
ffffffffc0201010:	40f487b3          	sub	a5,s1,a5
ffffffffc0201014:	40395913          	srai	s2,s2,0x3
ffffffffc0201018:	878d                	srai	a5,a5,0x3
    return (void *)(page2pa(page) + PHYSICAL_MEMORY_OFFSET);
ffffffffc020101a:	56f5                	li	a3,-3
ffffffffc020101c:	06fa                	slli	a3,a3,0x1e
    slab->magic = SLAB_MAGIC;
ffffffffc020101e:	12345637          	lui	a2,0x12345
ffffffffc0201022:	67860613          	addi	a2,a2,1656 # 12345678 <kern_entry-0xffffffffadeba988>
ffffffffc0201026:	02000593          	li	a1,32
ffffffffc020102a:	03790933          	mul	s2,s2,s7
ffffffffc020102e:	00070a1b          	sext.w	s4,a4
ffffffffc0201032:	037787b3          	mul	a5,a5,s7
ffffffffc0201036:	995a                	add	s2,s2,s6
    return page2ppn(page) << PGSHIFT;
ffffffffc0201038:	0932                	slli	s2,s2,0xc
    return (void *)(page2pa(page) + PHYSICAL_MEMORY_OFFSET);
ffffffffc020103a:	9936                	add	s2,s2,a3
    slab->cache = cache;
ffffffffc020103c:	00893023          	sd	s0,0(s2)
    slab->magic = SLAB_MAGIC;
ffffffffc0201040:	02c92823          	sw	a2,48(s2)
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0201044:	97da                	add	a5,a5,s6
    return page2ppn(page) << PGSHIFT;
ffffffffc0201046:	07b2                	slli	a5,a5,0xc
    return (void *)(page2pa(page) + PHYSICAL_MEMORY_OFFSET);
ffffffffc0201048:	97b6                	add	a5,a5,a3
    slab->s_mem = (void *)page2kva(page);
ffffffffc020104a:	00f93423          	sd	a5,8(s2)
    if (num_objs > MAX_OBJS_PER_SLAB) {
ffffffffc020104e:	08e5e963          	bltu	a1,a4,ffffffffc02010e0 <kmem_cache_alloc+0x1e2>
    slab->inuse = 0;
ffffffffc0201052:	00092823          	sw	zero,16(s2)
    slab->free = num_objs;
ffffffffc0201056:	01492a23          	sw	s4,20(s2)
    struct Page *freelist_page = slub_alloc_pages(1);
ffffffffc020105a:	4505                	li	a0,1
ffffffffc020105c:	f9aff0ef          	jal	ra,ffffffffc02007f6 <slub_alloc_pages>
    if (!freelist_page) {
ffffffffc0201060:	c159                	beqz	a0,ffffffffc02010e6 <kmem_cache_alloc+0x1e8>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0201062:	000c3703          	ld	a4,0(s8)
    for (unsigned int i = 0; i < num_objs; i++) {
ffffffffc0201066:	6685                	lui	a3,0x1
ffffffffc0201068:	40e507b3          	sub	a5,a0,a4
ffffffffc020106c:	878d                	srai	a5,a5,0x3
ffffffffc020106e:	037787b3          	mul	a5,a5,s7
    return (void *)(page2pa(page) + PHYSICAL_MEMORY_OFFSET);
ffffffffc0201072:	5775                	li	a4,-3
ffffffffc0201074:	077a                	slli	a4,a4,0x1e
ffffffffc0201076:	97da                	add	a5,a5,s6
    return page2ppn(page) << PGSHIFT;
ffffffffc0201078:	07b2                	slli	a5,a5,0xc
ffffffffc020107a:	97ba                	add	a5,a5,a4
    slab->freelist = (void **)page2kva(freelist_page);
ffffffffc020107c:	00f93c23          	sd	a5,24(s2)
    for (unsigned int i = 0; i < num_objs; i++) {
ffffffffc0201080:	0336e463          	bltu	a3,s3,ffffffffc02010a8 <kmem_cache_alloc+0x1aa>
ffffffffc0201084:	4501                	li	a0,0
ffffffffc0201086:	4701                	li	a4,0
ffffffffc0201088:	a019                	j	ffffffffc020108e <kmem_cache_alloc+0x190>
        slab->freelist[i] = (void *)((uintptr_t)slab->s_mem + i * obj_size);
ffffffffc020108a:	01893783          	ld	a5,24(s2)
ffffffffc020108e:	00893683          	ld	a3,8(s2)
ffffffffc0201092:	00371813          	slli	a6,a4,0x3
ffffffffc0201096:	97c2                	add	a5,a5,a6
ffffffffc0201098:	96aa                	add	a3,a3,a0
    for (unsigned int i = 0; i < num_objs; i++) {
ffffffffc020109a:	0705                	addi	a4,a4,1
        slab->freelist[i] = (void *)((uintptr_t)slab->s_mem + i * obj_size);
ffffffffc020109c:	e394                	sd	a3,0(a5)
    for (unsigned int i = 0; i < num_objs; i++) {
ffffffffc020109e:	0007079b          	sext.w	a5,a4
ffffffffc02010a2:	954e                	add	a0,a0,s3
ffffffffc02010a4:	ff47e3e3          	bltu	a5,s4,ffffffffc020108a <kmem_cache_alloc+0x18c>
    list_init(&slab->list);
ffffffffc02010a8:	02090793          	addi	a5,s2,32
    elm->prev = elm->next = elm;
ffffffffc02010ac:	02f93423          	sd	a5,40(s2)
ffffffffc02010b0:	02f93023          	sd	a5,32(s2)
    cprintf("slub: allocated slab with %u objects of size %lu\n", num_objs, obj_size);
ffffffffc02010b4:	864e                	mv	a2,s3
ffffffffc02010b6:	85d2                	mv	a1,s4
ffffffffc02010b8:	00001517          	auipc	a0,0x1
ffffffffc02010bc:	db050513          	addi	a0,a0,-592 # ffffffffc0201e68 <etext+0x4ce>
ffffffffc02010c0:	890ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
                c_slab->inuse++;
ffffffffc02010c4:	01092703          	lw	a4,16(s2)
                c_slab->free--;
ffffffffc02010c8:	01492783          	lw	a5,20(s2)
                c_freelist = slab->freelist[0];
ffffffffc02010cc:	01893683          	ld	a3,24(s2)
                c_slab->inuse++;
ffffffffc02010d0:	2705                	addiw	a4,a4,1
                c_slab->free--;
ffffffffc02010d2:	37fd                	addiw	a5,a5,-1
                c_freelist = slab->freelist[0];
ffffffffc02010d4:	6284                	ld	s1,0(a3)
                c_slab->inuse++;
ffffffffc02010d6:	00e92823          	sw	a4,16(s2)
                c_slab->free--;
ffffffffc02010da:	00f92a23          	sw	a5,20(s2)
ffffffffc02010de:	bdb9                	j	ffffffffc0200f3c <kmem_cache_alloc+0x3e>
ffffffffc02010e0:	02000a13          	li	s4,32
ffffffffc02010e4:	b7bd                	j	ffffffffc0201052 <kmem_cache_alloc+0x154>
    assert(n > 0);
ffffffffc02010e6:	4585                	li	a1,1
ffffffffc02010e8:	8556                	mv	a0,s5
ffffffffc02010ea:	fcaff0ef          	jal	ra,ffffffffc02008b4 <slub_free_pages.part.0>
ffffffffc02010ee:	8526                	mv	a0,s1
ffffffffc02010f0:	4585                	li	a1,1
ffffffffc02010f2:	fc2ff0ef          	jal	ra,ffffffffc02008b4 <slub_free_pages.part.0>
    void *object = NULL;
ffffffffc02010f6:	4481                	li	s1,0
ffffffffc02010f8:	b591                	j	ffffffffc0200f3c <kmem_cache_alloc+0x3e>

ffffffffc02010fa <kmalloc.part.0>:
void *kmalloc(size_t size) {
ffffffffc02010fa:	7139                	addi	sp,sp,-64
ffffffffc02010fc:	f822                	sd	s0,48(sp)
    return (size + align - 1) & ~(align - 1);
ffffffffc02010fe:	00750413          	addi	s0,a0,7
ffffffffc0201102:	9861                	andi	s0,s0,-8
void *kmalloc(size_t size) {
ffffffffc0201104:	f426                	sd	s1,40(sp)
    if (!size_caches[aligned_size]) {
ffffffffc0201106:	00341793          	slli	a5,s0,0x3
ffffffffc020110a:	00005497          	auipc	s1,0x5
ffffffffc020110e:	f3648493          	addi	s1,s1,-202 # ffffffffc0206040 <size_caches.0>
ffffffffc0201112:	94be                	add	s1,s1,a5
ffffffffc0201114:	6088                	ld	a0,0(s1)
void *kmalloc(size_t size) {
ffffffffc0201116:	fc06                	sd	ra,56(sp)
    if (!size_caches[aligned_size]) {
ffffffffc0201118:	c511                	beqz	a0,ffffffffc0201124 <kmalloc.part.0+0x2a>
}
ffffffffc020111a:	7442                	ld	s0,48(sp)
ffffffffc020111c:	70e2                	ld	ra,56(sp)
ffffffffc020111e:	74a2                	ld	s1,40(sp)
ffffffffc0201120:	6121                	addi	sp,sp,64
    return kmem_cache_alloc(size_caches[aligned_size]);
ffffffffc0201122:	bbf1                	j	ffffffffc0200efe <kmem_cache_alloc>
        snprintf(name, sizeof(name), "size-%lu", aligned_size);
ffffffffc0201124:	86a2                	mv	a3,s0
ffffffffc0201126:	00001617          	auipc	a2,0x1
ffffffffc020112a:	d7a60613          	addi	a2,a2,-646 # ffffffffc0201ea0 <etext+0x506>
ffffffffc020112e:	02000593          	li	a1,32
ffffffffc0201132:	850a                	mv	a0,sp
ffffffffc0201134:	75e000ef          	jal	ra,ffffffffc0201892 <snprintf>
        size_caches[aligned_size] = kmem_cache_create(name, aligned_size, 0, 0);
ffffffffc0201138:	85a2                	mv	a1,s0
ffffffffc020113a:	850a                	mv	a0,sp
ffffffffc020113c:	4681                	li	a3,0
ffffffffc020113e:	4601                	li	a2,0
ffffffffc0201140:	c75ff0ef          	jal	ra,ffffffffc0200db4 <kmem_cache_create>
}
ffffffffc0201144:	7442                	ld	s0,48(sp)
ffffffffc0201146:	70e2                	ld	ra,56(sp)
        size_caches[aligned_size] = kmem_cache_create(name, aligned_size, 0, 0);
ffffffffc0201148:	e088                	sd	a0,0(s1)
}
ffffffffc020114a:	74a2                	ld	s1,40(sp)
ffffffffc020114c:	6121                	addi	sp,sp,64
    return kmem_cache_alloc(size_caches[aligned_size]);
ffffffffc020114e:	bb45                	j	ffffffffc0200efe <kmem_cache_alloc>

ffffffffc0201150 <kmalloc>:
    if (size == 0) return NULL;
ffffffffc0201150:	c921                	beqz	a0,ffffffffc02011a0 <kmalloc+0x50>
    if (size >= PGSIZE / 2) {
ffffffffc0201152:	7ff00713          	li	a4,2047
ffffffffc0201156:	87aa                	mv	a5,a0
ffffffffc0201158:	00a76363          	bltu	a4,a0,ffffffffc020115e <kmalloc+0xe>
ffffffffc020115c:	bf79                	j	ffffffffc02010fa <kmalloc.part.0>
        size_t pages = (size + PGSIZE - 1) / PGSIZE;
ffffffffc020115e:	6505                	lui	a0,0x1
ffffffffc0201160:	157d                	addi	a0,a0,-1
ffffffffc0201162:	953e                	add	a0,a0,a5
void *kmalloc(size_t size) {
ffffffffc0201164:	1141                	addi	sp,sp,-16
        struct Page *page = slub_alloc_pages(pages);
ffffffffc0201166:	8131                	srli	a0,a0,0xc
void *kmalloc(size_t size) {
ffffffffc0201168:	e406                	sd	ra,8(sp)
        struct Page *page = slub_alloc_pages(pages);
ffffffffc020116a:	e8cff0ef          	jal	ra,ffffffffc02007f6 <slub_alloc_pages>
        if (page) {
ffffffffc020116e:	c91d                	beqz	a0,ffffffffc02011a4 <kmalloc+0x54>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0201170:	00005797          	auipc	a5,0x5
ffffffffc0201174:	f587b783          	ld	a5,-168(a5) # ffffffffc02060c8 <pages>
ffffffffc0201178:	8d1d                	sub	a0,a0,a5
ffffffffc020117a:	850d                	srai	a0,a0,0x3
ffffffffc020117c:	00001797          	auipc	a5,0x1
ffffffffc0201180:	2ec7b783          	ld	a5,748(a5) # ffffffffc0202468 <nbase+0x8>
ffffffffc0201184:	02f50533          	mul	a0,a0,a5
ffffffffc0201188:	00001797          	auipc	a5,0x1
ffffffffc020118c:	2d87b783          	ld	a5,728(a5) # ffffffffc0202460 <nbase>
ffffffffc0201190:	953e                	add	a0,a0,a5
    return (void *)(page2pa(page) + PHYSICAL_MEMORY_OFFSET);
ffffffffc0201192:	57f5                	li	a5,-3
    return page2ppn(page) << PGSHIFT;
ffffffffc0201194:	0532                	slli	a0,a0,0xc
ffffffffc0201196:	07fa                	slli	a5,a5,0x1e
ffffffffc0201198:	953e                	add	a0,a0,a5
}
ffffffffc020119a:	60a2                	ld	ra,8(sp)
ffffffffc020119c:	0141                	addi	sp,sp,16
ffffffffc020119e:	8082                	ret
    if (size == 0) return NULL;
ffffffffc02011a0:	4501                	li	a0,0
}
ffffffffc02011a2:	8082                	ret
    if (size == 0) return NULL;
ffffffffc02011a4:	4501                	li	a0,0
ffffffffc02011a6:	bfd5                	j	ffffffffc020119a <kmalloc+0x4a>

ffffffffc02011a8 <slub_check>:

// SLUB检查函数
static void slub_check(void) {
ffffffffc02011a8:	7175                	addi	sp,sp,-144
    cprintf("\n");
ffffffffc02011aa:	00001517          	auipc	a0,0x1
ffffffffc02011ae:	da650513          	addi	a0,a0,-602 # ffffffffc0201f50 <etext+0x5b6>
static void slub_check(void) {
ffffffffc02011b2:	e506                	sd	ra,136(sp)
ffffffffc02011b4:	e122                	sd	s0,128(sp)
ffffffffc02011b6:	fca6                	sd	s1,120(sp)
ffffffffc02011b8:	f8ca                	sd	s2,112(sp)
ffffffffc02011ba:	f4ce                	sd	s3,104(sp)
ffffffffc02011bc:	f0d2                	sd	s4,96(sp)
ffffffffc02011be:	ecd6                	sd	s5,88(sp)
    cprintf("\n");
ffffffffc02011c0:	f91fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("========================================\n");
ffffffffc02011c4:	00001517          	auipc	a0,0x1
ffffffffc02011c8:	cec50513          	addi	a0,a0,-788 # ffffffffc0201eb0 <etext+0x516>
ffffffffc02011cc:	f85fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("=== SLUB Memory Allocator Check ===\n");
ffffffffc02011d0:	00001517          	auipc	a0,0x1
ffffffffc02011d4:	d1050513          	addi	a0,a0,-752 # ffffffffc0201ee0 <etext+0x546>
ffffffffc02011d8:	f79fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("========================================\n");
ffffffffc02011dc:	00001517          	auipc	a0,0x1
ffffffffc02011e0:	cd450513          	addi	a0,a0,-812 # ffffffffc0201eb0 <etext+0x516>
ffffffffc02011e4:	f6dfe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("\n");
ffffffffc02011e8:	00001517          	auipc	a0,0x1
ffffffffc02011ec:	d6850513          	addi	a0,a0,-664 # ffffffffc0201f50 <etext+0x5b6>
ffffffffc02011f0:	f61fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    // 测试基本分配和释放
    cprintf("[TEST 1] Basic Allocation Test\n");
ffffffffc02011f4:	00001517          	auipc	a0,0x1
ffffffffc02011f8:	d1450513          	addi	a0,a0,-748 # ffffffffc0201f08 <etext+0x56e>
ffffffffc02011fc:	f55fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("----------------------------------------\n");
ffffffffc0201200:	00001517          	auipc	a0,0x1
ffffffffc0201204:	d2850513          	addi	a0,a0,-728 # ffffffffc0201f28 <etext+0x58e>
ffffffffc0201208:	f49fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    if (size >= PGSIZE / 2) {
ffffffffc020120c:	04000513          	li	a0,64
ffffffffc0201210:	eebff0ef          	jal	ra,ffffffffc02010fa <kmalloc.part.0>
    void *ptr1 = kmalloc(64);
    if (ptr1) {
ffffffffc0201214:	24050c63          	beqz	a0,ffffffffc020146c <slub_check+0x2c4>
        cprintf("✓ Allocated 64 bytes at 0x%016lx\n", (uintptr_t)ptr1);
ffffffffc0201218:	85aa                	mv	a1,a0
ffffffffc020121a:	842a                	mv	s0,a0
ffffffffc020121c:	00001517          	auipc	a0,0x1
ffffffffc0201220:	d3c50513          	addi	a0,a0,-708 # ffffffffc0201f58 <etext+0x5be>
ffffffffc0201224:	f2dfe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    if (!ptr) return;
ffffffffc0201228:	8522                	mv	a0,s0
ffffffffc020122a:	adbff0ef          	jal	ra,ffffffffc0200d04 <kfree.part.0>
        kfree(ptr1);
        cprintf("✓ Freed 64 bytes\n");
ffffffffc020122e:	00001517          	auipc	a0,0x1
ffffffffc0201232:	d5250513          	addi	a0,a0,-686 # ffffffffc0201f80 <etext+0x5e6>
ffffffffc0201236:	f1bfe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    } else {
        cprintf("✗ Failed to allocate 64 bytes\n");
    }
    cprintf("\n");
ffffffffc020123a:	00001517          	auipc	a0,0x1
ffffffffc020123e:	d1650513          	addi	a0,a0,-746 # ffffffffc0201f50 <etext+0x5b6>
ffffffffc0201242:	f0ffe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    // 测试不同大小的分配
    cprintf("[TEST 2] Different Size Allocation Test\n");
ffffffffc0201246:	00001517          	auipc	a0,0x1
ffffffffc020124a:	d7a50513          	addi	a0,a0,-646 # ffffffffc0201fc0 <etext+0x626>
ffffffffc020124e:	f03fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("----------------------------------------\n");
ffffffffc0201252:	00001517          	auipc	a0,0x1
ffffffffc0201256:	cd650513          	addi	a0,a0,-810 # ffffffffc0201f28 <etext+0x58e>
ffffffffc020125a:	848a                	mv	s1,sp
ffffffffc020125c:	ef5fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    void *ptrs[10];
    for (int i = 0; i < 10; i++) {
ffffffffc0201260:	05010993          	addi	s3,sp,80
    cprintf("----------------------------------------\n");
ffffffffc0201264:	8926                	mv	s2,s1
ffffffffc0201266:	02000413          	li	s0,32
        size_t size = 32 * (i + 1);
        ptrs[i] = kmalloc(size);
        if (ptrs[i]) {
            cprintf("✓ Allocated %3lu bytes at 0x%016lx\n", size, (uintptr_t)ptrs[i]);
        } else {
            cprintf("✗ Failed to allocate %3lu bytes\n", size);
ffffffffc020126a:	00001a97          	auipc	s5,0x1
ffffffffc020126e:	daea8a93          	addi	s5,s5,-594 # ffffffffc0202018 <etext+0x67e>
            cprintf("✓ Allocated %3lu bytes at 0x%016lx\n", size, (uintptr_t)ptrs[i]);
ffffffffc0201272:	00001a17          	auipc	s4,0x1
ffffffffc0201276:	d7ea0a13          	addi	s4,s4,-642 # ffffffffc0201ff0 <etext+0x656>
ffffffffc020127a:	a801                	j	ffffffffc020128a <slub_check+0xe2>
    for (int i = 0; i < 10; i++) {
ffffffffc020127c:	0921                	addi	s2,s2,8
            cprintf("✓ Allocated %3lu bytes at 0x%016lx\n", size, (uintptr_t)ptrs[i]);
ffffffffc020127e:	ed3fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    for (int i = 0; i < 10; i++) {
ffffffffc0201282:	02040413          	addi	s0,s0,32
ffffffffc0201286:	03390363          	beq	s2,s3,ffffffffc02012ac <slub_check+0x104>
        ptrs[i] = kmalloc(size);
ffffffffc020128a:	8522                	mv	a0,s0
ffffffffc020128c:	ec5ff0ef          	jal	ra,ffffffffc0201150 <kmalloc>
ffffffffc0201290:	862a                	mv	a2,a0
ffffffffc0201292:	00a93023          	sd	a0,0(s2)
            cprintf("✓ Allocated %3lu bytes at 0x%016lx\n", size, (uintptr_t)ptrs[i]);
ffffffffc0201296:	85a2                	mv	a1,s0
ffffffffc0201298:	8552                	mv	a0,s4
        if (ptrs[i]) {
ffffffffc020129a:	f26d                	bnez	a2,ffffffffc020127c <slub_check+0xd4>
            cprintf("✗ Failed to allocate %3lu bytes\n", size);
ffffffffc020129c:	8556                	mv	a0,s5
    for (int i = 0; i < 10; i++) {
ffffffffc020129e:	0921                	addi	s2,s2,8
            cprintf("✗ Failed to allocate %3lu bytes\n", size);
ffffffffc02012a0:	eb1fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    for (int i = 0; i < 10; i++) {
ffffffffc02012a4:	02040413          	addi	s0,s0,32
ffffffffc02012a8:	ff3911e3          	bne	s2,s3,ffffffffc020128a <slub_check+0xe2>
        }
    }
    cprintf("\n");
ffffffffc02012ac:	00001517          	auipc	a0,0x1
ffffffffc02012b0:	ca450513          	addi	a0,a0,-860 # ffffffffc0201f50 <etext+0x5b6>
ffffffffc02012b4:	e9dfe0ef          	jal	ra,ffffffffc0200150 <cprintf>
ffffffffc02012b8:	02000413          	li	s0,32
    
    for (int i = 0; i < 10; i++) {
        if (ptrs[i]) {
            kfree(ptrs[i]);
            cprintf("✓ Freed %3lu bytes\n", 32 * (i + 1));
ffffffffc02012bc:	00001917          	auipc	s2,0x1
ffffffffc02012c0:	d8490913          	addi	s2,s2,-636 # ffffffffc0202040 <etext+0x6a6>
        if (ptrs[i]) {
ffffffffc02012c4:	6088                	ld	a0,0(s1)
    for (int i = 0; i < 10; i++) {
ffffffffc02012c6:	04a1                	addi	s1,s1,8
        if (ptrs[i]) {
ffffffffc02012c8:	c519                	beqz	a0,ffffffffc02012d6 <slub_check+0x12e>
ffffffffc02012ca:	a3bff0ef          	jal	ra,ffffffffc0200d04 <kfree.part.0>
            cprintf("✓ Freed %3lu bytes\n", 32 * (i + 1));
ffffffffc02012ce:	85a2                	mv	a1,s0
ffffffffc02012d0:	854a                	mv	a0,s2
ffffffffc02012d2:	e7ffe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    for (int i = 0; i < 10; i++) {
ffffffffc02012d6:	0204041b          	addiw	s0,s0,32
ffffffffc02012da:	ff3495e3          	bne	s1,s3,ffffffffc02012c4 <slub_check+0x11c>
        }
    }
    cprintf("\n");
ffffffffc02012de:	00001517          	auipc	a0,0x1
ffffffffc02012e2:	c7250513          	addi	a0,a0,-910 # ffffffffc0201f50 <etext+0x5b6>
ffffffffc02012e6:	e6bfe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    // 测试大内存分配
    cprintf("[TEST 3] Large Allocation Test\n");
ffffffffc02012ea:	00001517          	auipc	a0,0x1
ffffffffc02012ee:	d6e50513          	addi	a0,a0,-658 # ffffffffc0202058 <etext+0x6be>
ffffffffc02012f2:	e5ffe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("----------------------------------------\n");
ffffffffc02012f6:	00001517          	auipc	a0,0x1
ffffffffc02012fa:	c3250513          	addi	a0,a0,-974 # ffffffffc0201f28 <etext+0x58e>
ffffffffc02012fe:	e53fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
        struct Page *page = slub_alloc_pages(pages);
ffffffffc0201302:	4509                	li	a0,2
ffffffffc0201304:	cf2ff0ef          	jal	ra,ffffffffc02007f6 <slub_alloc_pages>
        if (page) {
ffffffffc0201308:	16050963          	beqz	a0,ffffffffc020147a <slub_check+0x2d2>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc020130c:	00005797          	auipc	a5,0x5
ffffffffc0201310:	dbc7b783          	ld	a5,-580(a5) # ffffffffc02060c8 <pages>
ffffffffc0201314:	40f507b3          	sub	a5,a0,a5
ffffffffc0201318:	878d                	srai	a5,a5,0x3
ffffffffc020131a:	00001517          	auipc	a0,0x1
ffffffffc020131e:	14e53503          	ld	a0,334(a0) # ffffffffc0202468 <nbase+0x8>
ffffffffc0201322:	02a787b3          	mul	a5,a5,a0
ffffffffc0201326:	00001697          	auipc	a3,0x1
ffffffffc020132a:	13a6b683          	ld	a3,314(a3) # ffffffffc0202460 <nbase>
    void *large_ptr = kmalloc(PGSIZE * 2);
    if (large_ptr) {
ffffffffc020132e:	470d                	li	a4,3
    return (void *)(page2pa(page) + PHYSICAL_MEMORY_OFFSET);
ffffffffc0201330:	5475                	li	s0,-3
ffffffffc0201332:	047a                	slli	s0,s0,0x1e
    if (large_ptr) {
ffffffffc0201334:	077a                	slli	a4,a4,0x1e
ffffffffc0201336:	97b6                	add	a5,a5,a3
    return page2ppn(page) << PGSHIFT;
ffffffffc0201338:	07b2                	slli	a5,a5,0xc
    return (void *)(page2pa(page) + PHYSICAL_MEMORY_OFFSET);
ffffffffc020133a:	943e                	add	s0,s0,a5
    if (large_ptr) {
ffffffffc020133c:	12e78f63          	beq	a5,a4,ffffffffc020147a <slub_check+0x2d2>
        cprintf("✓ Allocated %lu bytes at 0x%016lx\n", PGSIZE * 2, (uintptr_t)large_ptr);
ffffffffc0201340:	6589                	lui	a1,0x2
ffffffffc0201342:	8622                	mv	a2,s0
ffffffffc0201344:	00001517          	auipc	a0,0x1
ffffffffc0201348:	d3450513          	addi	a0,a0,-716 # ffffffffc0202078 <etext+0x6de>
ffffffffc020134c:	e05fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    if (!ptr) return;
ffffffffc0201350:	8522                	mv	a0,s0
ffffffffc0201352:	9b3ff0ef          	jal	ra,ffffffffc0200d04 <kfree.part.0>
        kfree(large_ptr);
        cprintf("✓ Freed large allocation (%lu bytes)\n", PGSIZE * 2);
ffffffffc0201356:	6589                	lui	a1,0x2
ffffffffc0201358:	00001517          	auipc	a0,0x1
ffffffffc020135c:	d4850513          	addi	a0,a0,-696 # ffffffffc02020a0 <etext+0x706>
ffffffffc0201360:	df1fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    } else {
        cprintf("✗ Failed to allocate large memory (%lu bytes)\n", PGSIZE * 2);
    }
    cprintf("\n");
ffffffffc0201364:	00001517          	auipc	a0,0x1
ffffffffc0201368:	bec50513          	addi	a0,a0,-1044 # ffffffffc0201f50 <etext+0x5b6>
ffffffffc020136c:	de5fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    // 显示统计信息
    cprintf("[STATISTICS] Memory Usage Summary\n");
ffffffffc0201370:	00001517          	auipc	a0,0x1
ffffffffc0201374:	d9050513          	addi	a0,a0,-624 # ffffffffc0202100 <etext+0x766>
ffffffffc0201378:	dd9fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("----------------------------------------\n");
ffffffffc020137c:	00001517          	auipc	a0,0x1
ffffffffc0201380:	bac50513          	addi	a0,a0,-1108 # ffffffffc0201f28 <etext+0x58e>
ffffffffc0201384:	dcdfe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("Free pages: %lu\n", nr_free);
ffffffffc0201388:	00005597          	auipc	a1,0x5
ffffffffc020138c:	cb05a583          	lw	a1,-848(a1) # ffffffffc0206038 <free_area+0x10>
ffffffffc0201390:	00001517          	auipc	a0,0x1
ffffffffc0201394:	d9850513          	addi	a0,a0,-616 # ffffffffc0202128 <etext+0x78e>
ffffffffc0201398:	db9fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("\n");
ffffffffc020139c:	00001517          	auipc	a0,0x1
ffffffffc02013a0:	bb450513          	addi	a0,a0,-1100 # ffffffffc0201f50 <etext+0x5b6>
ffffffffc02013a4:	dadfe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    while (__sync_lock_test_and_set(lock, 1)) {
ffffffffc02013a8:	00005917          	auipc	s2,0x5
ffffffffc02013ac:	d4890913          	addi	s2,s2,-696 # ffffffffc02060f0 <cache_lock>
ffffffffc02013b0:	4785                	li	a5,1
ffffffffc02013b2:	843e                	mv	s0,a5
ffffffffc02013b4:	0c89242f          	amoswap.w.aq	s0,s0,(s2)
ffffffffc02013b8:	2401                	sext.w	s0,s0
ffffffffc02013ba:	fc65                	bnez	s0,ffffffffc02013b2 <slub_check+0x20a>
    
    spin_lock(&cache_lock);
    unsigned int cache_count = 0;
    list_entry_t *le = &cache_list;
    
    cprintf("Cache Statistics:\n");
ffffffffc02013bc:	00001517          	auipc	a0,0x1
ffffffffc02013c0:	d8450513          	addi	a0,a0,-636 # ffffffffc0202140 <etext+0x7a6>
    return listelm->next;
ffffffffc02013c4:	00005997          	auipc	s3,0x5
ffffffffc02013c8:	c5498993          	addi	s3,s3,-940 # ffffffffc0206018 <cache_list>
ffffffffc02013cc:	d85fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
ffffffffc02013d0:	0089b483          	ld	s1,8(s3)
    while ((le = list_next(le)) != &cache_list) {
ffffffffc02013d4:	03348563          	beq	s1,s3,ffffffffc02013fe <slub_check+0x256>
        cache_count++;
        struct kmem_cache *cache = (struct kmem_cache *)((char *)le - offsetof(struct kmem_cache, list));
        cprintf("  %-15s: allocations=%lu, frees=%lu, active=%lu\n", 
ffffffffc02013d8:	00001a17          	auipc	s4,0x1
ffffffffc02013dc:	d80a0a13          	addi	s4,s4,-640 # ffffffffc0202158 <etext+0x7be>
ffffffffc02013e0:	ff04b603          	ld	a2,-16(s1)
ffffffffc02013e4:	ff84b683          	ld	a3,-8(s1)
ffffffffc02013e8:	f984b583          	ld	a1,-104(s1)
ffffffffc02013ec:	8552                	mv	a0,s4
ffffffffc02013ee:	40d60733          	sub	a4,a2,a3
ffffffffc02013f2:	d5ffe0ef          	jal	ra,ffffffffc0200150 <cprintf>
ffffffffc02013f6:	6484                	ld	s1,8(s1)
        cache_count++;
ffffffffc02013f8:	2405                	addiw	s0,s0,1
    while ((le = list_next(le)) != &cache_list) {
ffffffffc02013fa:	ff3493e3          	bne	s1,s3,ffffffffc02013e0 <slub_check+0x238>
    __sync_lock_release(lock);
ffffffffc02013fe:	0f50000f          	fence	iorw,ow
ffffffffc0201402:	0809202f          	amoswap.w	zero,zero,(s2)
                cache->name, cache->num_allocations, cache->num_frees, 
                cache->num_allocations - cache->num_frees);
    }
    spin_unlock(&cache_lock);
    
    cprintf("\n");
ffffffffc0201406:	00001517          	auipc	a0,0x1
ffffffffc020140a:	b4a50513          	addi	a0,a0,-1206 # ffffffffc0201f50 <etext+0x5b6>
ffffffffc020140e:	d43fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("Total caches: %u\n", cache_count);
ffffffffc0201412:	85a2                	mv	a1,s0
ffffffffc0201414:	00001517          	auipc	a0,0x1
ffffffffc0201418:	d7c50513          	addi	a0,a0,-644 # ffffffffc0202190 <etext+0x7f6>
ffffffffc020141c:	d35fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("\n");
ffffffffc0201420:	00001517          	auipc	a0,0x1
ffffffffc0201424:	b3050513          	addi	a0,a0,-1232 # ffffffffc0201f50 <etext+0x5b6>
ffffffffc0201428:	d29fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    cprintf("========================================\n");
ffffffffc020142c:	00001517          	auipc	a0,0x1
ffffffffc0201430:	a8450513          	addi	a0,a0,-1404 # ffffffffc0201eb0 <etext+0x516>
ffffffffc0201434:	d1dfe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("=== SLUB Check Completed ===\n");
ffffffffc0201438:	00001517          	auipc	a0,0x1
ffffffffc020143c:	d7050513          	addi	a0,a0,-656 # ffffffffc02021a8 <etext+0x80e>
ffffffffc0201440:	d11fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("========================================\n");
ffffffffc0201444:	00001517          	auipc	a0,0x1
ffffffffc0201448:	a6c50513          	addi	a0,a0,-1428 # ffffffffc0201eb0 <etext+0x516>
ffffffffc020144c:	d05fe0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("\n");
    
    // 测试脚本现在直接匹配优化后的输出格式
}
ffffffffc0201450:	640a                	ld	s0,128(sp)
ffffffffc0201452:	60aa                	ld	ra,136(sp)
ffffffffc0201454:	74e6                	ld	s1,120(sp)
ffffffffc0201456:	7946                	ld	s2,112(sp)
ffffffffc0201458:	79a6                	ld	s3,104(sp)
ffffffffc020145a:	7a06                	ld	s4,96(sp)
ffffffffc020145c:	6ae6                	ld	s5,88(sp)
    cprintf("\n");
ffffffffc020145e:	00001517          	auipc	a0,0x1
ffffffffc0201462:	af250513          	addi	a0,a0,-1294 # ffffffffc0201f50 <etext+0x5b6>
}
ffffffffc0201466:	6149                	addi	sp,sp,144
    cprintf("\n");
ffffffffc0201468:	ce9fe06f          	j	ffffffffc0200150 <cprintf>
        cprintf("✗ Failed to allocate 64 bytes\n");
ffffffffc020146c:	00001517          	auipc	a0,0x1
ffffffffc0201470:	b2c50513          	addi	a0,a0,-1236 # ffffffffc0201f98 <etext+0x5fe>
ffffffffc0201474:	cddfe0ef          	jal	ra,ffffffffc0200150 <cprintf>
ffffffffc0201478:	b3c9                	j	ffffffffc020123a <slub_check+0x92>
        cprintf("✗ Failed to allocate large memory (%lu bytes)\n", PGSIZE * 2);
ffffffffc020147a:	6589                	lui	a1,0x2
ffffffffc020147c:	00001517          	auipc	a0,0x1
ffffffffc0201480:	c4c50513          	addi	a0,a0,-948 # ffffffffc02020c8 <etext+0x72e>
ffffffffc0201484:	ccdfe0ef          	jal	ra,ffffffffc0200150 <cprintf>
ffffffffc0201488:	bdf1                	j	ffffffffc0201364 <slub_check+0x1bc>

ffffffffc020148a <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc020148a:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc020148e:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc0201490:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201494:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc0201496:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc020149a:	f022                	sd	s0,32(sp)
ffffffffc020149c:	ec26                	sd	s1,24(sp)
ffffffffc020149e:	e84a                	sd	s2,16(sp)
ffffffffc02014a0:	f406                	sd	ra,40(sp)
ffffffffc02014a2:	e44e                	sd	s3,8(sp)
ffffffffc02014a4:	84aa                	mv	s1,a0
ffffffffc02014a6:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc02014a8:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc02014ac:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc02014ae:	03067e63          	bgeu	a2,a6,ffffffffc02014ea <printnum+0x60>
ffffffffc02014b2:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc02014b4:	00805763          	blez	s0,ffffffffc02014c2 <printnum+0x38>
ffffffffc02014b8:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc02014ba:	85ca                	mv	a1,s2
ffffffffc02014bc:	854e                	mv	a0,s3
ffffffffc02014be:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc02014c0:	fc65                	bnez	s0,ffffffffc02014b8 <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02014c2:	1a02                	slli	s4,s4,0x20
ffffffffc02014c4:	00001797          	auipc	a5,0x1
ffffffffc02014c8:	d5478793          	addi	a5,a5,-684 # ffffffffc0202218 <slub_pmm_manager+0x38>
ffffffffc02014cc:	020a5a13          	srli	s4,s4,0x20
ffffffffc02014d0:	9a3e                	add	s4,s4,a5
}
ffffffffc02014d2:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02014d4:	000a4503          	lbu	a0,0(s4)
}
ffffffffc02014d8:	70a2                	ld	ra,40(sp)
ffffffffc02014da:	69a2                	ld	s3,8(sp)
ffffffffc02014dc:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02014de:	85ca                	mv	a1,s2
ffffffffc02014e0:	87a6                	mv	a5,s1
}
ffffffffc02014e2:	6942                	ld	s2,16(sp)
ffffffffc02014e4:	64e2                	ld	s1,24(sp)
ffffffffc02014e6:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02014e8:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc02014ea:	03065633          	divu	a2,a2,a6
ffffffffc02014ee:	8722                	mv	a4,s0
ffffffffc02014f0:	f9bff0ef          	jal	ra,ffffffffc020148a <printnum>
ffffffffc02014f4:	b7f9                	j	ffffffffc02014c2 <printnum+0x38>

ffffffffc02014f6 <sprintputch>:
 * @ch:         the character will be printed
 * @b:          the buffer to place the character @ch
 * */
static void
sprintputch(int ch, struct sprintbuf *b) {
    b->cnt ++;
ffffffffc02014f6:	499c                	lw	a5,16(a1)
    if (b->buf < b->ebuf) {
ffffffffc02014f8:	6198                	ld	a4,0(a1)
ffffffffc02014fa:	6594                	ld	a3,8(a1)
    b->cnt ++;
ffffffffc02014fc:	2785                	addiw	a5,a5,1
ffffffffc02014fe:	c99c                	sw	a5,16(a1)
    if (b->buf < b->ebuf) {
ffffffffc0201500:	00d77763          	bgeu	a4,a3,ffffffffc020150e <sprintputch+0x18>
        *b->buf ++ = ch;
ffffffffc0201504:	00170793          	addi	a5,a4,1 # 1001 <kern_entry-0xffffffffc01fefff>
ffffffffc0201508:	e19c                	sd	a5,0(a1)
ffffffffc020150a:	00a70023          	sb	a0,0(a4)
    }
}
ffffffffc020150e:	8082                	ret

ffffffffc0201510 <vprintfmt>:
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc0201510:	7119                	addi	sp,sp,-128
ffffffffc0201512:	f4a6                	sd	s1,104(sp)
ffffffffc0201514:	f0ca                	sd	s2,96(sp)
ffffffffc0201516:	ecce                	sd	s3,88(sp)
ffffffffc0201518:	e8d2                	sd	s4,80(sp)
ffffffffc020151a:	e4d6                	sd	s5,72(sp)
ffffffffc020151c:	e0da                	sd	s6,64(sp)
ffffffffc020151e:	fc5e                	sd	s7,56(sp)
ffffffffc0201520:	f06a                	sd	s10,32(sp)
ffffffffc0201522:	fc86                	sd	ra,120(sp)
ffffffffc0201524:	f8a2                	sd	s0,112(sp)
ffffffffc0201526:	f862                	sd	s8,48(sp)
ffffffffc0201528:	f466                	sd	s9,40(sp)
ffffffffc020152a:	ec6e                	sd	s11,24(sp)
ffffffffc020152c:	892a                	mv	s2,a0
ffffffffc020152e:	84ae                	mv	s1,a1
ffffffffc0201530:	8d32                	mv	s10,a2
ffffffffc0201532:	8a36                	mv	s4,a3
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201534:	02500993          	li	s3,37
        width = precision = -1;
ffffffffc0201538:	5b7d                	li	s6,-1
ffffffffc020153a:	00001a97          	auipc	s5,0x1
ffffffffc020153e:	d12a8a93          	addi	s5,s5,-750 # ffffffffc020224c <slub_pmm_manager+0x6c>
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201542:	00001b97          	auipc	s7,0x1
ffffffffc0201546:	ee6b8b93          	addi	s7,s7,-282 # ffffffffc0202428 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020154a:	000d4503          	lbu	a0,0(s10)
ffffffffc020154e:	001d0413          	addi	s0,s10,1
ffffffffc0201552:	01350a63          	beq	a0,s3,ffffffffc0201566 <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc0201556:	c121                	beqz	a0,ffffffffc0201596 <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc0201558:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020155a:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc020155c:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020155e:	fff44503          	lbu	a0,-1(s0)
ffffffffc0201562:	ff351ae3          	bne	a0,s3,ffffffffc0201556 <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201566:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc020156a:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc020156e:	4c81                	li	s9,0
ffffffffc0201570:	4881                	li	a7,0
        width = precision = -1;
ffffffffc0201572:	5c7d                	li	s8,-1
ffffffffc0201574:	5dfd                	li	s11,-1
ffffffffc0201576:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc020157a:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020157c:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201580:	0ff5f593          	zext.b	a1,a1
ffffffffc0201584:	00140d13          	addi	s10,s0,1
ffffffffc0201588:	04b56263          	bltu	a0,a1,ffffffffc02015cc <vprintfmt+0xbc>
ffffffffc020158c:	058a                	slli	a1,a1,0x2
ffffffffc020158e:	95d6                	add	a1,a1,s5
ffffffffc0201590:	4194                	lw	a3,0(a1)
ffffffffc0201592:	96d6                	add	a3,a3,s5
ffffffffc0201594:	8682                	jr	a3
}
ffffffffc0201596:	70e6                	ld	ra,120(sp)
ffffffffc0201598:	7446                	ld	s0,112(sp)
ffffffffc020159a:	74a6                	ld	s1,104(sp)
ffffffffc020159c:	7906                	ld	s2,96(sp)
ffffffffc020159e:	69e6                	ld	s3,88(sp)
ffffffffc02015a0:	6a46                	ld	s4,80(sp)
ffffffffc02015a2:	6aa6                	ld	s5,72(sp)
ffffffffc02015a4:	6b06                	ld	s6,64(sp)
ffffffffc02015a6:	7be2                	ld	s7,56(sp)
ffffffffc02015a8:	7c42                	ld	s8,48(sp)
ffffffffc02015aa:	7ca2                	ld	s9,40(sp)
ffffffffc02015ac:	7d02                	ld	s10,32(sp)
ffffffffc02015ae:	6de2                	ld	s11,24(sp)
ffffffffc02015b0:	6109                	addi	sp,sp,128
ffffffffc02015b2:	8082                	ret
            padc = '0';
ffffffffc02015b4:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc02015b6:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02015ba:	846a                	mv	s0,s10
ffffffffc02015bc:	00140d13          	addi	s10,s0,1
ffffffffc02015c0:	fdd6059b          	addiw	a1,a2,-35
ffffffffc02015c4:	0ff5f593          	zext.b	a1,a1
ffffffffc02015c8:	fcb572e3          	bgeu	a0,a1,ffffffffc020158c <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc02015cc:	85a6                	mv	a1,s1
ffffffffc02015ce:	02500513          	li	a0,37
ffffffffc02015d2:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc02015d4:	fff44783          	lbu	a5,-1(s0)
ffffffffc02015d8:	8d22                	mv	s10,s0
ffffffffc02015da:	f73788e3          	beq	a5,s3,ffffffffc020154a <vprintfmt+0x3a>
ffffffffc02015de:	ffed4783          	lbu	a5,-2(s10)
ffffffffc02015e2:	1d7d                	addi	s10,s10,-1
ffffffffc02015e4:	ff379de3          	bne	a5,s3,ffffffffc02015de <vprintfmt+0xce>
ffffffffc02015e8:	b78d                	j	ffffffffc020154a <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc02015ea:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc02015ee:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02015f2:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc02015f4:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc02015f8:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc02015fc:	02d86463          	bltu	a6,a3,ffffffffc0201624 <vprintfmt+0x114>
                ch = *fmt;
ffffffffc0201600:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0201604:	002c169b          	slliw	a3,s8,0x2
ffffffffc0201608:	0186873b          	addw	a4,a3,s8
ffffffffc020160c:	0017171b          	slliw	a4,a4,0x1
ffffffffc0201610:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc0201612:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0201616:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc0201618:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc020161c:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201620:	fed870e3          	bgeu	a6,a3,ffffffffc0201600 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc0201624:	f40ddce3          	bgez	s11,ffffffffc020157c <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc0201628:	8de2                	mv	s11,s8
ffffffffc020162a:	5c7d                	li	s8,-1
ffffffffc020162c:	bf81                	j	ffffffffc020157c <vprintfmt+0x6c>
            if (width < 0)
ffffffffc020162e:	fffdc693          	not	a3,s11
ffffffffc0201632:	96fd                	srai	a3,a3,0x3f
ffffffffc0201634:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201638:	00144603          	lbu	a2,1(s0)
ffffffffc020163c:	2d81                	sext.w	s11,s11
ffffffffc020163e:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201640:	bf35                	j	ffffffffc020157c <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc0201642:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201646:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc020164a:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020164c:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc020164e:	bfd9                	j	ffffffffc0201624 <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0201650:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201652:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201656:	01174463          	blt	a4,a7,ffffffffc020165e <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc020165a:	1a088e63          	beqz	a7,ffffffffc0201816 <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc020165e:	000a3603          	ld	a2,0(s4)
ffffffffc0201662:	46c1                	li	a3,16
ffffffffc0201664:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc0201666:	2781                	sext.w	a5,a5
ffffffffc0201668:	876e                	mv	a4,s11
ffffffffc020166a:	85a6                	mv	a1,s1
ffffffffc020166c:	854a                	mv	a0,s2
ffffffffc020166e:	e1dff0ef          	jal	ra,ffffffffc020148a <printnum>
            break;
ffffffffc0201672:	bde1                	j	ffffffffc020154a <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc0201674:	000a2503          	lw	a0,0(s4)
ffffffffc0201678:	85a6                	mv	a1,s1
ffffffffc020167a:	0a21                	addi	s4,s4,8
ffffffffc020167c:	9902                	jalr	s2
            break;
ffffffffc020167e:	b5f1                	j	ffffffffc020154a <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201680:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201682:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201686:	01174463          	blt	a4,a7,ffffffffc020168e <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc020168a:	18088163          	beqz	a7,ffffffffc020180c <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc020168e:	000a3603          	ld	a2,0(s4)
ffffffffc0201692:	46a9                	li	a3,10
ffffffffc0201694:	8a2e                	mv	s4,a1
ffffffffc0201696:	bfc1                	j	ffffffffc0201666 <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201698:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc020169c:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020169e:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02016a0:	bdf1                	j	ffffffffc020157c <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc02016a2:	85a6                	mv	a1,s1
ffffffffc02016a4:	02500513          	li	a0,37
ffffffffc02016a8:	9902                	jalr	s2
            break;
ffffffffc02016aa:	b545                	j	ffffffffc020154a <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02016ac:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc02016b0:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02016b2:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02016b4:	b5e1                	j	ffffffffc020157c <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc02016b6:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02016b8:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02016bc:	01174463          	blt	a4,a7,ffffffffc02016c4 <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc02016c0:	14088163          	beqz	a7,ffffffffc0201802 <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc02016c4:	000a3603          	ld	a2,0(s4)
ffffffffc02016c8:	46a1                	li	a3,8
ffffffffc02016ca:	8a2e                	mv	s4,a1
ffffffffc02016cc:	bf69                	j	ffffffffc0201666 <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc02016ce:	03000513          	li	a0,48
ffffffffc02016d2:	85a6                	mv	a1,s1
ffffffffc02016d4:	e03e                	sd	a5,0(sp)
ffffffffc02016d6:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc02016d8:	85a6                	mv	a1,s1
ffffffffc02016da:	07800513          	li	a0,120
ffffffffc02016de:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02016e0:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc02016e2:	6782                	ld	a5,0(sp)
ffffffffc02016e4:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02016e6:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc02016ea:	bfb5                	j	ffffffffc0201666 <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc02016ec:	000a3403          	ld	s0,0(s4)
ffffffffc02016f0:	008a0713          	addi	a4,s4,8
ffffffffc02016f4:	e03a                	sd	a4,0(sp)
ffffffffc02016f6:	14040263          	beqz	s0,ffffffffc020183a <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc02016fa:	0fb05763          	blez	s11,ffffffffc02017e8 <vprintfmt+0x2d8>
ffffffffc02016fe:	02d00693          	li	a3,45
ffffffffc0201702:	0cd79163          	bne	a5,a3,ffffffffc02017c4 <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201706:	00044783          	lbu	a5,0(s0)
ffffffffc020170a:	0007851b          	sext.w	a0,a5
ffffffffc020170e:	cf85                	beqz	a5,ffffffffc0201746 <vprintfmt+0x236>
ffffffffc0201710:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201714:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201718:	000c4563          	bltz	s8,ffffffffc0201722 <vprintfmt+0x212>
ffffffffc020171c:	3c7d                	addiw	s8,s8,-1
ffffffffc020171e:	036c0263          	beq	s8,s6,ffffffffc0201742 <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc0201722:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201724:	0e0c8e63          	beqz	s9,ffffffffc0201820 <vprintfmt+0x310>
ffffffffc0201728:	3781                	addiw	a5,a5,-32
ffffffffc020172a:	0ef47b63          	bgeu	s0,a5,ffffffffc0201820 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc020172e:	03f00513          	li	a0,63
ffffffffc0201732:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201734:	000a4783          	lbu	a5,0(s4)
ffffffffc0201738:	3dfd                	addiw	s11,s11,-1
ffffffffc020173a:	0a05                	addi	s4,s4,1
ffffffffc020173c:	0007851b          	sext.w	a0,a5
ffffffffc0201740:	ffe1                	bnez	a5,ffffffffc0201718 <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc0201742:	01b05963          	blez	s11,ffffffffc0201754 <vprintfmt+0x244>
ffffffffc0201746:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc0201748:	85a6                	mv	a1,s1
ffffffffc020174a:	02000513          	li	a0,32
ffffffffc020174e:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0201750:	fe0d9be3          	bnez	s11,ffffffffc0201746 <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201754:	6a02                	ld	s4,0(sp)
ffffffffc0201756:	bbd5                	j	ffffffffc020154a <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201758:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc020175a:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc020175e:	01174463          	blt	a4,a7,ffffffffc0201766 <vprintfmt+0x256>
    else if (lflag) {
ffffffffc0201762:	08088d63          	beqz	a7,ffffffffc02017fc <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc0201766:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc020176a:	0a044d63          	bltz	s0,ffffffffc0201824 <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc020176e:	8622                	mv	a2,s0
ffffffffc0201770:	8a66                	mv	s4,s9
ffffffffc0201772:	46a9                	li	a3,10
ffffffffc0201774:	bdcd                	j	ffffffffc0201666 <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc0201776:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc020177a:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc020177c:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc020177e:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc0201782:	8fb5                	xor	a5,a5,a3
ffffffffc0201784:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201788:	02d74163          	blt	a4,a3,ffffffffc02017aa <vprintfmt+0x29a>
ffffffffc020178c:	00369793          	slli	a5,a3,0x3
ffffffffc0201790:	97de                	add	a5,a5,s7
ffffffffc0201792:	639c                	ld	a5,0(a5)
ffffffffc0201794:	cb99                	beqz	a5,ffffffffc02017aa <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc0201796:	86be                	mv	a3,a5
ffffffffc0201798:	00001617          	auipc	a2,0x1
ffffffffc020179c:	ab060613          	addi	a2,a2,-1360 # ffffffffc0202248 <slub_pmm_manager+0x68>
ffffffffc02017a0:	85a6                	mv	a1,s1
ffffffffc02017a2:	854a                	mv	a0,s2
ffffffffc02017a4:	0ce000ef          	jal	ra,ffffffffc0201872 <printfmt>
ffffffffc02017a8:	b34d                	j	ffffffffc020154a <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc02017aa:	00001617          	auipc	a2,0x1
ffffffffc02017ae:	a8e60613          	addi	a2,a2,-1394 # ffffffffc0202238 <slub_pmm_manager+0x58>
ffffffffc02017b2:	85a6                	mv	a1,s1
ffffffffc02017b4:	854a                	mv	a0,s2
ffffffffc02017b6:	0bc000ef          	jal	ra,ffffffffc0201872 <printfmt>
ffffffffc02017ba:	bb41                	j	ffffffffc020154a <vprintfmt+0x3a>
                p = "(null)";
ffffffffc02017bc:	00001417          	auipc	s0,0x1
ffffffffc02017c0:	a7440413          	addi	s0,s0,-1420 # ffffffffc0202230 <slub_pmm_manager+0x50>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02017c4:	85e2                	mv	a1,s8
ffffffffc02017c6:	8522                	mv	a0,s0
ffffffffc02017c8:	e43e                	sd	a5,8(sp)
ffffffffc02017ca:	142000ef          	jal	ra,ffffffffc020190c <strnlen>
ffffffffc02017ce:	40ad8dbb          	subw	s11,s11,a0
ffffffffc02017d2:	01b05b63          	blez	s11,ffffffffc02017e8 <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc02017d6:	67a2                	ld	a5,8(sp)
ffffffffc02017d8:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02017dc:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc02017de:	85a6                	mv	a1,s1
ffffffffc02017e0:	8552                	mv	a0,s4
ffffffffc02017e2:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02017e4:	fe0d9ce3          	bnez	s11,ffffffffc02017dc <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02017e8:	00044783          	lbu	a5,0(s0)
ffffffffc02017ec:	00140a13          	addi	s4,s0,1
ffffffffc02017f0:	0007851b          	sext.w	a0,a5
ffffffffc02017f4:	d3a5                	beqz	a5,ffffffffc0201754 <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02017f6:	05e00413          	li	s0,94
ffffffffc02017fa:	bf39                	j	ffffffffc0201718 <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc02017fc:	000a2403          	lw	s0,0(s4)
ffffffffc0201800:	b7ad                	j	ffffffffc020176a <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc0201802:	000a6603          	lwu	a2,0(s4)
ffffffffc0201806:	46a1                	li	a3,8
ffffffffc0201808:	8a2e                	mv	s4,a1
ffffffffc020180a:	bdb1                	j	ffffffffc0201666 <vprintfmt+0x156>
ffffffffc020180c:	000a6603          	lwu	a2,0(s4)
ffffffffc0201810:	46a9                	li	a3,10
ffffffffc0201812:	8a2e                	mv	s4,a1
ffffffffc0201814:	bd89                	j	ffffffffc0201666 <vprintfmt+0x156>
ffffffffc0201816:	000a6603          	lwu	a2,0(s4)
ffffffffc020181a:	46c1                	li	a3,16
ffffffffc020181c:	8a2e                	mv	s4,a1
ffffffffc020181e:	b5a1                	j	ffffffffc0201666 <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc0201820:	9902                	jalr	s2
ffffffffc0201822:	bf09                	j	ffffffffc0201734 <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc0201824:	85a6                	mv	a1,s1
ffffffffc0201826:	02d00513          	li	a0,45
ffffffffc020182a:	e03e                	sd	a5,0(sp)
ffffffffc020182c:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc020182e:	6782                	ld	a5,0(sp)
ffffffffc0201830:	8a66                	mv	s4,s9
ffffffffc0201832:	40800633          	neg	a2,s0
ffffffffc0201836:	46a9                	li	a3,10
ffffffffc0201838:	b53d                	j	ffffffffc0201666 <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc020183a:	03b05163          	blez	s11,ffffffffc020185c <vprintfmt+0x34c>
ffffffffc020183e:	02d00693          	li	a3,45
ffffffffc0201842:	f6d79de3          	bne	a5,a3,ffffffffc02017bc <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc0201846:	00001417          	auipc	s0,0x1
ffffffffc020184a:	9ea40413          	addi	s0,s0,-1558 # ffffffffc0202230 <slub_pmm_manager+0x50>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc020184e:	02800793          	li	a5,40
ffffffffc0201852:	02800513          	li	a0,40
ffffffffc0201856:	00140a13          	addi	s4,s0,1
ffffffffc020185a:	bd6d                	j	ffffffffc0201714 <vprintfmt+0x204>
ffffffffc020185c:	00001a17          	auipc	s4,0x1
ffffffffc0201860:	9d5a0a13          	addi	s4,s4,-1579 # ffffffffc0202231 <slub_pmm_manager+0x51>
ffffffffc0201864:	02800513          	li	a0,40
ffffffffc0201868:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc020186c:	05e00413          	li	s0,94
ffffffffc0201870:	b565                	j	ffffffffc0201718 <vprintfmt+0x208>

ffffffffc0201872 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201872:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc0201874:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201878:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc020187a:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc020187c:	ec06                	sd	ra,24(sp)
ffffffffc020187e:	f83a                	sd	a4,48(sp)
ffffffffc0201880:	fc3e                	sd	a5,56(sp)
ffffffffc0201882:	e0c2                	sd	a6,64(sp)
ffffffffc0201884:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc0201886:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201888:	c89ff0ef          	jal	ra,ffffffffc0201510 <vprintfmt>
}
ffffffffc020188c:	60e2                	ld	ra,24(sp)
ffffffffc020188e:	6161                	addi	sp,sp,80
ffffffffc0201890:	8082                	ret

ffffffffc0201892 <snprintf>:
 * @str:        the buffer to place the result into
 * @size:       the size of buffer, including the trailing null space
 * @fmt:        the format string to use
 * */
int
snprintf(char *str, size_t size, const char *fmt, ...) {
ffffffffc0201892:	711d                	addi	sp,sp,-96
 * Call this function if you are already dealing with a va_list.
 * Or you probably want snprintf() instead.
 * */
int
vsnprintf(char *str, size_t size, const char *fmt, va_list ap) {
    struct sprintbuf b = {str, str + size - 1, 0};
ffffffffc0201894:	15fd                	addi	a1,a1,-1
    va_start(ap, fmt);
ffffffffc0201896:	03810313          	addi	t1,sp,56
    struct sprintbuf b = {str, str + size - 1, 0};
ffffffffc020189a:	95aa                	add	a1,a1,a0
snprintf(char *str, size_t size, const char *fmt, ...) {
ffffffffc020189c:	f406                	sd	ra,40(sp)
ffffffffc020189e:	fc36                	sd	a3,56(sp)
ffffffffc02018a0:	e0ba                	sd	a4,64(sp)
ffffffffc02018a2:	e4be                	sd	a5,72(sp)
ffffffffc02018a4:	e8c2                	sd	a6,80(sp)
ffffffffc02018a6:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc02018a8:	e01a                	sd	t1,0(sp)
    struct sprintbuf b = {str, str + size - 1, 0};
ffffffffc02018aa:	e42a                	sd	a0,8(sp)
ffffffffc02018ac:	e82e                	sd	a1,16(sp)
ffffffffc02018ae:	cc02                	sw	zero,24(sp)
    if (str == NULL || b.buf > b.ebuf) {
ffffffffc02018b0:	c115                	beqz	a0,ffffffffc02018d4 <snprintf+0x42>
ffffffffc02018b2:	02a5e163          	bltu	a1,a0,ffffffffc02018d4 <snprintf+0x42>
        return -E_INVAL;
    }
    // print the string to the buffer
    vprintfmt((void*)sprintputch, &b, fmt, ap);
ffffffffc02018b6:	00000517          	auipc	a0,0x0
ffffffffc02018ba:	c4050513          	addi	a0,a0,-960 # ffffffffc02014f6 <sprintputch>
ffffffffc02018be:	869a                	mv	a3,t1
ffffffffc02018c0:	002c                	addi	a1,sp,8
ffffffffc02018c2:	c4fff0ef          	jal	ra,ffffffffc0201510 <vprintfmt>
    // null terminate the buffer
    *b.buf = '\0';
ffffffffc02018c6:	67a2                	ld	a5,8(sp)
ffffffffc02018c8:	00078023          	sb	zero,0(a5)
    return b.cnt;
ffffffffc02018cc:	4562                	lw	a0,24(sp)
}
ffffffffc02018ce:	70a2                	ld	ra,40(sp)
ffffffffc02018d0:	6125                	addi	sp,sp,96
ffffffffc02018d2:	8082                	ret
        return -E_INVAL;
ffffffffc02018d4:	5575                	li	a0,-3
ffffffffc02018d6:	bfe5                	j	ffffffffc02018ce <snprintf+0x3c>

ffffffffc02018d8 <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc02018d8:	4781                	li	a5,0
ffffffffc02018da:	00004717          	auipc	a4,0x4
ffffffffc02018de:	73673703          	ld	a4,1846(a4) # ffffffffc0206010 <SBI_CONSOLE_PUTCHAR>
ffffffffc02018e2:	88ba                	mv	a7,a4
ffffffffc02018e4:	852a                	mv	a0,a0
ffffffffc02018e6:	85be                	mv	a1,a5
ffffffffc02018e8:	863e                	mv	a2,a5
ffffffffc02018ea:	00000073          	ecall
ffffffffc02018ee:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc02018f0:	8082                	ret

ffffffffc02018f2 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc02018f2:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc02018f6:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc02018f8:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc02018fa:	cb81                	beqz	a5,ffffffffc020190a <strlen+0x18>
        cnt ++;
ffffffffc02018fc:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc02018fe:	00a707b3          	add	a5,a4,a0
ffffffffc0201902:	0007c783          	lbu	a5,0(a5)
ffffffffc0201906:	fbfd                	bnez	a5,ffffffffc02018fc <strlen+0xa>
ffffffffc0201908:	8082                	ret
    }
    return cnt;
}
ffffffffc020190a:	8082                	ret

ffffffffc020190c <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc020190c:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc020190e:	e589                	bnez	a1,ffffffffc0201918 <strnlen+0xc>
ffffffffc0201910:	a811                	j	ffffffffc0201924 <strnlen+0x18>
        cnt ++;
ffffffffc0201912:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201914:	00f58863          	beq	a1,a5,ffffffffc0201924 <strnlen+0x18>
ffffffffc0201918:	00f50733          	add	a4,a0,a5
ffffffffc020191c:	00074703          	lbu	a4,0(a4)
ffffffffc0201920:	fb6d                	bnez	a4,ffffffffc0201912 <strnlen+0x6>
ffffffffc0201922:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc0201924:	852e                	mv	a0,a1
ffffffffc0201926:	8082                	ret

ffffffffc0201928 <strncpy>:
 * The return value is @dst
 * */
char *
strncpy(char *dst, const char *src, size_t len) {
    char *p = dst;
    while (len > 0) {
ffffffffc0201928:	ce09                	beqz	a2,ffffffffc0201942 <strncpy+0x1a>
ffffffffc020192a:	962a                	add	a2,a2,a0
    char *p = dst;
ffffffffc020192c:	87aa                	mv	a5,a0
        if ((*p = *src) != '\0') {
ffffffffc020192e:	0005c703          	lbu	a4,0(a1) # 2000 <kern_entry-0xffffffffc01fe000>
            src ++;
        }
        p ++, len --;
ffffffffc0201932:	0785                	addi	a5,a5,1
            src ++;
ffffffffc0201934:	00e036b3          	snez	a3,a4
        if ((*p = *src) != '\0') {
ffffffffc0201938:	fee78fa3          	sb	a4,-1(a5)
            src ++;
ffffffffc020193c:	95b6                	add	a1,a1,a3
    while (len > 0) {
ffffffffc020193e:	fec798e3          	bne	a5,a2,ffffffffc020192e <strncpy+0x6>
    }
    return dst;
}
ffffffffc0201942:	8082                	ret

ffffffffc0201944 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201944:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201948:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc020194c:	cb89                	beqz	a5,ffffffffc020195e <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc020194e:	0505                	addi	a0,a0,1
ffffffffc0201950:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201952:	fee789e3          	beq	a5,a4,ffffffffc0201944 <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201956:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc020195a:	9d19                	subw	a0,a0,a4
ffffffffc020195c:	8082                	ret
ffffffffc020195e:	4501                	li	a0,0
ffffffffc0201960:	bfed                	j	ffffffffc020195a <strcmp+0x16>

ffffffffc0201962 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201962:	c20d                	beqz	a2,ffffffffc0201984 <strncmp+0x22>
ffffffffc0201964:	962e                	add	a2,a2,a1
ffffffffc0201966:	a031                	j	ffffffffc0201972 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc0201968:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020196a:	00e79a63          	bne	a5,a4,ffffffffc020197e <strncmp+0x1c>
ffffffffc020196e:	00b60b63          	beq	a2,a1,ffffffffc0201984 <strncmp+0x22>
ffffffffc0201972:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc0201976:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201978:	fff5c703          	lbu	a4,-1(a1)
ffffffffc020197c:	f7f5                	bnez	a5,ffffffffc0201968 <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020197e:	40e7853b          	subw	a0,a5,a4
}
ffffffffc0201982:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201984:	4501                	li	a0,0
ffffffffc0201986:	8082                	ret

ffffffffc0201988 <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc0201988:	ca01                	beqz	a2,ffffffffc0201998 <memset+0x10>
ffffffffc020198a:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc020198c:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc020198e:	0785                	addi	a5,a5,1
ffffffffc0201990:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc0201994:	fec79de3          	bne	a5,a2,ffffffffc020198e <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc0201998:	8082                	ret
