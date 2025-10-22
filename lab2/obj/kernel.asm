
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
ffffffffc0200050:	00001517          	auipc	a0,0x1
ffffffffc0200054:	4d050513          	addi	a0,a0,1232 # ffffffffc0201520 <etext+0x4>
void print_kerninfo(void) {
ffffffffc0200058:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc020005a:	0f6000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005e:	00000597          	auipc	a1,0x0
ffffffffc0200062:	07e58593          	addi	a1,a1,126 # ffffffffc02000dc <kern_init>
ffffffffc0200066:	00001517          	auipc	a0,0x1
ffffffffc020006a:	4da50513          	addi	a0,a0,1242 # ffffffffc0201540 <etext+0x24>
ffffffffc020006e:	0e2000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc0200072:	00001597          	auipc	a1,0x1
ffffffffc0200076:	4aa58593          	addi	a1,a1,1194 # ffffffffc020151c <etext>
ffffffffc020007a:	00001517          	auipc	a0,0x1
ffffffffc020007e:	4e650513          	addi	a0,a0,1254 # ffffffffc0201560 <etext+0x44>
ffffffffc0200082:	0ce000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200086:	00006597          	auipc	a1,0x6
ffffffffc020008a:	f9258593          	addi	a1,a1,-110 # ffffffffc0206018 <free_area>
ffffffffc020008e:	00001517          	auipc	a0,0x1
ffffffffc0200092:	4f250513          	addi	a0,a0,1266 # ffffffffc0201580 <etext+0x64>
ffffffffc0200096:	0ba000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc020009a:	00006597          	auipc	a1,0x6
ffffffffc020009e:	0ce58593          	addi	a1,a1,206 # ffffffffc0206168 <end>
ffffffffc02000a2:	00001517          	auipc	a0,0x1
ffffffffc02000a6:	4fe50513          	addi	a0,a0,1278 # ffffffffc02015a0 <etext+0x84>
ffffffffc02000aa:	0a6000ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000ae:	00006597          	auipc	a1,0x6
ffffffffc02000b2:	4b958593          	addi	a1,a1,1209 # ffffffffc0206567 <end+0x3ff>
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
ffffffffc02000d4:	4f050513          	addi	a0,a0,1264 # ffffffffc02015c0 <etext+0xa4>
}
ffffffffc02000d8:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000da:	a89d                	j	ffffffffc0200150 <cprintf>

ffffffffc02000dc <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000dc:	00006517          	auipc	a0,0x6
ffffffffc02000e0:	f3c50513          	addi	a0,a0,-196 # ffffffffc0206018 <free_area>
ffffffffc02000e4:	00006617          	auipc	a2,0x6
ffffffffc02000e8:	08460613          	addi	a2,a2,132 # ffffffffc0206168 <end>
int kern_init(void) {
ffffffffc02000ec:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ee:	8e09                	sub	a2,a2,a0
ffffffffc02000f0:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000f2:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f4:	416010ef          	jal	ra,ffffffffc020150a <memset>
    dtb_init();
ffffffffc02000f8:	12c000ef          	jal	ra,ffffffffc0200224 <dtb_init>
    cons_init();  // init the console
ffffffffc02000fc:	11e000ef          	jal	ra,ffffffffc020021a <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc0200100:	00001517          	auipc	a0,0x1
ffffffffc0200104:	4f050513          	addi	a0,a0,1264 # ffffffffc02015f0 <etext+0xd4>
ffffffffc0200108:	07e000ef          	jal	ra,ffffffffc0200186 <cputs>

    print_kerninfo();
ffffffffc020010c:	f43ff0ef          	jal	ra,ffffffffc020004e <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc0200110:	5a1000ef          	jal	ra,ffffffffc0200eb0 <pmm_init>

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
ffffffffc0200144:	7b1000ef          	jal	ra,ffffffffc02010f4 <vprintfmt>
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
ffffffffc020017a:	77b000ef          	jal	ra,ffffffffc02010f4 <vprintfmt>
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
ffffffffc02001ca:	f5a30313          	addi	t1,t1,-166 # ffffffffc0206120 <is_panic>
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
ffffffffc02001fa:	41a50513          	addi	a0,a0,1050 # ffffffffc0201610 <etext+0xf4>
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
ffffffffc0200210:	3dc50513          	addi	a0,a0,988 # ffffffffc02015e8 <etext+0xcc>
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
ffffffffc0200220:	2560106f          	j	ffffffffc0201476 <sbi_console_putchar>

ffffffffc0200224 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200224:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200226:	00001517          	auipc	a0,0x1
ffffffffc020022a:	40a50513          	addi	a0,a0,1034 # ffffffffc0201630 <etext+0x114>
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
ffffffffc0200254:	00001517          	auipc	a0,0x1
ffffffffc0200258:	3ec50513          	addi	a0,a0,1004 # ffffffffc0201640 <etext+0x124>
ffffffffc020025c:	ef5ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc0200260:	00006417          	auipc	s0,0x6
ffffffffc0200264:	da840413          	addi	s0,s0,-600 # ffffffffc0206008 <boot_dtb>
ffffffffc0200268:	600c                	ld	a1,0(s0)
ffffffffc020026a:	00001517          	auipc	a0,0x1
ffffffffc020026e:	3e650513          	addi	a0,a0,998 # ffffffffc0201650 <etext+0x134>
ffffffffc0200272:	edfff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200276:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc020027a:	00001517          	auipc	a0,0x1
ffffffffc020027e:	3ee50513          	addi	a0,a0,1006 # ffffffffc0201668 <etext+0x14c>
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
ffffffffc02002c2:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed9d85>
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
ffffffffc0200338:	38490913          	addi	s2,s2,900 # ffffffffc02016b8 <etext+0x19c>
ffffffffc020033c:	49bd                	li	s3,15
        switch (token) {
ffffffffc020033e:	4d91                	li	s11,4
ffffffffc0200340:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200342:	00001497          	auipc	s1,0x1
ffffffffc0200346:	36e48493          	addi	s1,s1,878 # ffffffffc02016b0 <etext+0x194>
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
ffffffffc020039a:	39a50513          	addi	a0,a0,922 # ffffffffc0201730 <etext+0x214>
ffffffffc020039e:	db3ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc02003a2:	00001517          	auipc	a0,0x1
ffffffffc02003a6:	3c650513          	addi	a0,a0,966 # ffffffffc0201768 <etext+0x24c>
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
ffffffffc02003e6:	2a650513          	addi	a0,a0,678 # ffffffffc0201688 <etext+0x16c>
}
ffffffffc02003ea:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003ec:	b395                	j	ffffffffc0200150 <cprintf>
                int name_len = strlen(name);
ffffffffc02003ee:	8556                	mv	a0,s5
ffffffffc02003f0:	0a0010ef          	jal	ra,ffffffffc0201490 <strlen>
ffffffffc02003f4:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f6:	4619                	li	a2,6
ffffffffc02003f8:	85a6                	mv	a1,s1
ffffffffc02003fa:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003fc:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003fe:	0e6010ef          	jal	ra,ffffffffc02014e4 <strncmp>
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
ffffffffc0200494:	032010ef          	jal	ra,ffffffffc02014c6 <strcmp>
ffffffffc0200498:	66a2                	ld	a3,8(sp)
ffffffffc020049a:	f94d                	bnez	a0,ffffffffc020044c <dtb_init+0x228>
ffffffffc020049c:	fb59f8e3          	bgeu	s3,s5,ffffffffc020044c <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc02004a0:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004a4:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc02004a8:	00001517          	auipc	a0,0x1
ffffffffc02004ac:	21850513          	addi	a0,a0,536 # ffffffffc02016c0 <etext+0x1a4>
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
ffffffffc020057a:	16a50513          	addi	a0,a0,362 # ffffffffc02016e0 <etext+0x1c4>
ffffffffc020057e:	bd3ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc0200582:	014b5613          	srli	a2,s6,0x14
ffffffffc0200586:	85da                	mv	a1,s6
ffffffffc0200588:	00001517          	auipc	a0,0x1
ffffffffc020058c:	17050513          	addi	a0,a0,368 # ffffffffc02016f8 <etext+0x1dc>
ffffffffc0200590:	bc1ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200594:	008b05b3          	add	a1,s6,s0
ffffffffc0200598:	15fd                	addi	a1,a1,-1
ffffffffc020059a:	00001517          	auipc	a0,0x1
ffffffffc020059e:	17e50513          	addi	a0,a0,382 # ffffffffc0201718 <etext+0x1fc>
ffffffffc02005a2:	bafff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("DTB init completed\n");
ffffffffc02005a6:	00001517          	auipc	a0,0x1
ffffffffc02005aa:	1c250513          	addi	a0,a0,450 # ffffffffc0201768 <etext+0x24c>
        memory_base = mem_base;
ffffffffc02005ae:	00006797          	auipc	a5,0x6
ffffffffc02005b2:	b687bd23          	sd	s0,-1158(a5) # ffffffffc0206128 <memory_base>
        memory_size = mem_size;
ffffffffc02005b6:	00006797          	auipc	a5,0x6
ffffffffc02005ba:	b767bd23          	sd	s6,-1158(a5) # ffffffffc0206130 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005be:	b3f5                	j	ffffffffc02003aa <dtb_init+0x186>

ffffffffc02005c0 <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005c0:	00006517          	auipc	a0,0x6
ffffffffc02005c4:	b6853503          	ld	a0,-1176(a0) # ffffffffc0206128 <memory_base>
ffffffffc02005c8:	8082                	ret

ffffffffc02005ca <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005ca:	00006517          	auipc	a0,0x6
ffffffffc02005ce:	b6653503          	ld	a0,-1178(a0) # ffffffffc0206130 <memory_size>
ffffffffc02005d2:	8082                	ret

ffffffffc02005d4 <buddy_init>:
}

// ==================== 新增：初始化函数 ====================
static void buddy_init(void) {
    // 初始化所有阶数的空闲链表
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02005d4:	00006797          	auipc	a5,0x6
ffffffffc02005d8:	a4478793          	addi	a5,a5,-1468 # ffffffffc0206018 <free_area>
ffffffffc02005dc:	00006717          	auipc	a4,0x6
ffffffffc02005e0:	b4470713          	addi	a4,a4,-1212 # ffffffffc0206120 <is_panic>
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02005e4:	e79c                	sd	a5,8(a5)
ffffffffc02005e6:	e39c                	sd	a5,0(a5)
        list_init(&free_list(i));
        nr_free(i) = 0;
ffffffffc02005e8:	0007a823          	sw	zero,16(a5)
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02005ec:	07e1                	addi	a5,a5,24
ffffffffc02005ee:	fee79be3          	bne	a5,a4,ffffffffc02005e4 <buddy_init+0x10>
    }
}
ffffffffc02005f2:	8082                	ret

ffffffffc02005f4 <buddy_nr_free_pages>:
}

// ==================== 新增：获取空闲页数 ====================
static size_t buddy_nr_free_pages(void) {
    size_t total = 0;
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02005f4:	00006697          	auipc	a3,0x6
ffffffffc02005f8:	a3468693          	addi	a3,a3,-1484 # ffffffffc0206028 <free_area+0x10>
ffffffffc02005fc:	4781                	li	a5,0
    size_t total = 0;
ffffffffc02005fe:	4501                	li	a0,0
    return 1 << order;
ffffffffc0200600:	4805                	li	a6,1
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc0200602:	45ad                	li	a1,11
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc0200604:	0006e703          	lwu	a4,0(a3)
    return 1 << order;
ffffffffc0200608:	00f8163b          	sllw	a2,a6,a5
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc020060c:	2785                	addiw	a5,a5,1
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc020060e:	02c70733          	mul	a4,a4,a2
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc0200612:	06e1                	addi	a3,a3,24
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc0200614:	953a                	add	a0,a0,a4
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc0200616:	feb797e3          	bne	a5,a1,ffffffffc0200604 <buddy_nr_free_pages+0x10>
    }
    return total;
}
ffffffffc020061a:	8082                	ret

ffffffffc020061c <buddy_check>:
    
    cprintf("buddy_system: basic_check passed\n");
}

// ==================== 新增：完整检查函数 ====================
static void buddy_check(void) {
ffffffffc020061c:	7175                	addi	sp,sp,-144
    cprintf("==================== Buddy System Check Start ====================\n");
ffffffffc020061e:	00001517          	auipc	a0,0x1
ffffffffc0200622:	16250513          	addi	a0,a0,354 # ffffffffc0201780 <etext+0x264>
static void buddy_check(void) {
ffffffffc0200626:	e506                	sd	ra,136(sp)
ffffffffc0200628:	e122                	sd	s0,128(sp)
ffffffffc020062a:	fca6                	sd	s1,120(sp)
ffffffffc020062c:	f8ca                	sd	s2,112(sp)
ffffffffc020062e:	f4ce                	sd	s3,104(sp)
ffffffffc0200630:	f0d2                	sd	s4,96(sp)
ffffffffc0200632:	ecd6                	sd	s5,88(sp)
ffffffffc0200634:	e8da                	sd	s6,80(sp)
    cprintf("==================== Buddy System Check Start ====================\n");
ffffffffc0200636:	b1bff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("buddy_system: basic_check begin\n");
ffffffffc020063a:	00001517          	auipc	a0,0x1
ffffffffc020063e:	18e50513          	addi	a0,a0,398 # ffffffffc02017c8 <etext+0x2ac>
ffffffffc0200642:	b0fff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200646:	4505                	li	a0,1
ffffffffc0200648:	051000ef          	jal	ra,ffffffffc0200e98 <alloc_pages>
ffffffffc020064c:	44050b63          	beqz	a0,ffffffffc0200aa2 <buddy_check+0x486>
ffffffffc0200650:	89aa                	mv	s3,a0
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200652:	4505                	li	a0,1
ffffffffc0200654:	045000ef          	jal	ra,ffffffffc0200e98 <alloc_pages>
ffffffffc0200658:	892a                	mv	s2,a0
ffffffffc020065a:	3a050463          	beqz	a0,ffffffffc0200a02 <buddy_check+0x3e6>
    assert((p2 = alloc_page()) != NULL);
ffffffffc020065e:	4505                	li	a0,1
ffffffffc0200660:	039000ef          	jal	ra,ffffffffc0200e98 <alloc_pages>
ffffffffc0200664:	84aa                	mv	s1,a0
ffffffffc0200666:	3e050e63          	beqz	a0,ffffffffc0200a62 <buddy_check+0x446>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc020066a:	2f298c63          	beq	s3,s2,ffffffffc0200962 <buddy_check+0x346>
ffffffffc020066e:	2ea98a63          	beq	s3,a0,ffffffffc0200962 <buddy_check+0x346>
ffffffffc0200672:	2ea90863          	beq	s2,a0,ffffffffc0200962 <buddy_check+0x346>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200676:	0009a783          	lw	a5,0(s3)
ffffffffc020067a:	2c079463          	bnez	a5,ffffffffc0200942 <buddy_check+0x326>
ffffffffc020067e:	00092783          	lw	a5,0(s2)
ffffffffc0200682:	2c079063          	bnez	a5,ffffffffc0200942 <buddy_check+0x326>
}



// 获取页的引用计数
static inline int page_ref(struct Page *page) { return page->ref; }
ffffffffc0200686:	4100                	lw	s0,0(a0)
ffffffffc0200688:	2a041d63          	bnez	s0,ffffffffc0200942 <buddy_check+0x326>
    free_page(p0);
ffffffffc020068c:	4585                	li	a1,1
ffffffffc020068e:	854e                	mv	a0,s3
ffffffffc0200690:	015000ef          	jal	ra,ffffffffc0200ea4 <free_pages>
    free_page(p1);
ffffffffc0200694:	854a                	mv	a0,s2
ffffffffc0200696:	4585                	li	a1,1
ffffffffc0200698:	00d000ef          	jal	ra,ffffffffc0200ea4 <free_pages>
    free_page(p2);
ffffffffc020069c:	4585                	li	a1,1
ffffffffc020069e:	8526                	mv	a0,s1
ffffffffc02006a0:	005000ef          	jal	ra,ffffffffc0200ea4 <free_pages>
    struct Page *p3 = alloc_pages(4);
ffffffffc02006a4:	4511                	li	a0,4
ffffffffc02006a6:	7f2000ef          	jal	ra,ffffffffc0200e98 <alloc_pages>
ffffffffc02006aa:	892a                	mv	s2,a0
    assert(p3 != NULL);
ffffffffc02006ac:	44050b63          	beqz	a0,ffffffffc0200b02 <buddy_check+0x4e6>
    struct Page *p4 = alloc_pages(8);
ffffffffc02006b0:	4521                	li	a0,8
ffffffffc02006b2:	7e6000ef          	jal	ra,ffffffffc0200e98 <alloc_pages>
ffffffffc02006b6:	84aa                	mv	s1,a0
    assert(p4 != NULL);
ffffffffc02006b8:	42050563          	beqz	a0,ffffffffc0200ae2 <buddy_check+0x4c6>
    free_pages(p3, 4);
ffffffffc02006bc:	854a                	mv	a0,s2
ffffffffc02006be:	4591                	li	a1,4
ffffffffc02006c0:	7e4000ef          	jal	ra,ffffffffc0200ea4 <free_pages>
    free_pages(p4, 8);
ffffffffc02006c4:	45a1                	li	a1,8
ffffffffc02006c6:	8526                	mv	a0,s1
ffffffffc02006c8:	7dc000ef          	jal	ra,ffffffffc0200ea4 <free_pages>
    cprintf("buddy_system: basic_check passed\n");
ffffffffc02006cc:	00001517          	auipc	a0,0x1
ffffffffc02006d0:	23c50513          	addi	a0,a0,572 # ffffffffc0201908 <etext+0x3ec>
ffffffffc02006d4:	a7dff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02006d8:	00006497          	auipc	s1,0x6
ffffffffc02006dc:	95048493          	addi	s1,s1,-1712 # ffffffffc0206028 <free_area+0x10>
    size_t total = 0;
ffffffffc02006e0:	4901                	li	s2,0
    cprintf("buddy_system: basic_check passed\n");
ffffffffc02006e2:	86a6                	mv	a3,s1
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02006e4:	4781                	li	a5,0
    return 1 << order;
ffffffffc02006e6:	4505                	li	a0,1
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02006e8:	45ad                	li	a1,11
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc02006ea:	0006e703          	lwu	a4,0(a3)
    return 1 << order;
ffffffffc02006ee:	00f5163b          	sllw	a2,a0,a5
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02006f2:	2785                	addiw	a5,a5,1
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc02006f4:	02c70733          	mul	a4,a4,a2
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02006f8:	06e1                	addi	a3,a3,24
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc02006fa:	993a                	add	s2,s2,a4
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02006fc:	feb797e3          	bne	a5,a1,ffffffffc02006ea <buddy_check+0xce>
    
    buddy_basic_check();
    
    // 保存当前状态
    size_t total_free_pages = buddy_nr_free_pages();
    cprintf("Total free pages: %d\n", total_free_pages);
ffffffffc0200700:	85ca                	mv	a1,s2
ffffffffc0200702:	00001517          	auipc	a0,0x1
ffffffffc0200706:	22e50513          	addi	a0,a0,558 # ffffffffc0201930 <etext+0x414>
ffffffffc020070a:	a47ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    // ============ 测试1：块分裂 ============
    cprintf("\n[Test 1] Block splitting test\n");
ffffffffc020070e:	00001517          	auipc	a0,0x1
ffffffffc0200712:	23a50513          	addi	a0,a0,570 # ffffffffc0201948 <etext+0x42c>
ffffffffc0200716:	a3bff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    struct Page *p0 = alloc_pages(1);
ffffffffc020071a:	4505                	li	a0,1
ffffffffc020071c:	77c000ef          	jal	ra,ffffffffc0200e98 <alloc_pages>
ffffffffc0200720:	8b2a                	mv	s6,a0
    assert(p0 != NULL);
ffffffffc0200722:	32050063          	beqz	a0,ffffffffc0200a42 <buddy_check+0x426>
    cprintf("  Allocated 1 page: PASS\n");
ffffffffc0200726:	00001517          	auipc	a0,0x1
ffffffffc020072a:	25250513          	addi	a0,a0,594 # ffffffffc0201978 <etext+0x45c>
ffffffffc020072e:	a23ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    struct Page *p1 = alloc_pages(2);
ffffffffc0200732:	4509                	li	a0,2
ffffffffc0200734:	764000ef          	jal	ra,ffffffffc0200e98 <alloc_pages>
ffffffffc0200738:	8aaa                	mv	s5,a0
    assert(p1 != NULL);
ffffffffc020073a:	2e050463          	beqz	a0,ffffffffc0200a22 <buddy_check+0x406>
    cprintf("  Allocated 2 pages: PASS\n");
ffffffffc020073e:	00001517          	auipc	a0,0x1
ffffffffc0200742:	26a50513          	addi	a0,a0,618 # ffffffffc02019a8 <etext+0x48c>
ffffffffc0200746:	a0bff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    struct Page *p2 = alloc_pages(4);
ffffffffc020074a:	4511                	li	a0,4
ffffffffc020074c:	74c000ef          	jal	ra,ffffffffc0200e98 <alloc_pages>
ffffffffc0200750:	8a2a                	mv	s4,a0
    assert(p2 != NULL);
ffffffffc0200752:	22050863          	beqz	a0,ffffffffc0200982 <buddy_check+0x366>
    cprintf("  Allocated 4 pages: PASS\n");
ffffffffc0200756:	00001517          	auipc	a0,0x1
ffffffffc020075a:	28250513          	addi	a0,a0,642 # ffffffffc02019d8 <etext+0x4bc>
ffffffffc020075e:	9f3ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    // ============ 测试2：块合并 ============
    cprintf("\n[Test 2] Block merging test\n");
ffffffffc0200762:	00001517          	auipc	a0,0x1
ffffffffc0200766:	29650513          	addi	a0,a0,662 # ffffffffc02019f8 <etext+0x4dc>
ffffffffc020076a:	9e7ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    size_t total = 0;
ffffffffc020076e:	4981                	li	s3,0
    cprintf("\n[Test 2] Block merging test\n");
ffffffffc0200770:	00006697          	auipc	a3,0x6
ffffffffc0200774:	8b868693          	addi	a3,a3,-1864 # ffffffffc0206028 <free_area+0x10>
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc0200778:	4781                	li	a5,0
    return 1 << order;
ffffffffc020077a:	4505                	li	a0,1
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc020077c:	45ad                	li	a1,11
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc020077e:	0006e703          	lwu	a4,0(a3)
    return 1 << order;
ffffffffc0200782:	00f5163b          	sllw	a2,a0,a5
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc0200786:	2785                	addiw	a5,a5,1
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc0200788:	02c70733          	mul	a4,a4,a2
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc020078c:	06e1                	addi	a3,a3,24
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc020078e:	99ba                	add	s3,s3,a4
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc0200790:	feb797e3          	bne	a5,a1,ffffffffc020077e <buddy_check+0x162>
    size_t free_before = buddy_nr_free_pages();
    
    free_pages(p0, 1);
ffffffffc0200794:	4585                	li	a1,1
ffffffffc0200796:	855a                	mv	a0,s6
ffffffffc0200798:	70c000ef          	jal	ra,ffffffffc0200ea4 <free_pages>
    free_pages(p1, 2);
ffffffffc020079c:	4589                	li	a1,2
ffffffffc020079e:	8556                	mv	a0,s5
ffffffffc02007a0:	704000ef          	jal	ra,ffffffffc0200ea4 <free_pages>
    free_pages(p2, 4);
ffffffffc02007a4:	8552                	mv	a0,s4
ffffffffc02007a6:	4591                	li	a1,4
ffffffffc02007a8:	6fc000ef          	jal	ra,ffffffffc0200ea4 <free_pages>
ffffffffc02007ac:	00006697          	auipc	a3,0x6
ffffffffc02007b0:	87c68693          	addi	a3,a3,-1924 # ffffffffc0206028 <free_area+0x10>
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02007b4:	4781                	li	a5,0
    size_t total = 0;
ffffffffc02007b6:	4601                	li	a2,0
    return 1 << order;
ffffffffc02007b8:	4805                	li	a6,1
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02007ba:	452d                	li	a0,11
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc02007bc:	0006e703          	lwu	a4,0(a3)
    return 1 << order;
ffffffffc02007c0:	00f815bb          	sllw	a1,a6,a5
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02007c4:	2785                	addiw	a5,a5,1
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc02007c6:	02b70733          	mul	a4,a4,a1
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02007ca:	06e1                	addi	a3,a3,24
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc02007cc:	963a                	add	a2,a2,a4
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02007ce:	fea797e3          	bne	a5,a0,ffffffffc02007bc <buddy_check+0x1a0>
    
    size_t free_after = buddy_nr_free_pages();
    assert(free_after == free_before + 1 + 2 + 4);
ffffffffc02007d2:	099d                	addi	s3,s3,7
ffffffffc02007d4:	20c99763          	bne	s3,a2,ffffffffc02009e2 <buddy_check+0x3c6>
    cprintf("  Free pages increased by %d: PASS\n", 1 + 2 + 4);
ffffffffc02007d8:	459d                	li	a1,7
ffffffffc02007da:	00001517          	auipc	a0,0x1
ffffffffc02007de:	26650513          	addi	a0,a0,614 # ffffffffc0201a40 <etext+0x524>
ffffffffc02007e2:	96fff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    // ============ 测试3：分配不是2的幂次的大小 ============
    cprintf("\n[Test 3] Non-power-of-2 allocation\n");
ffffffffc02007e6:	00001517          	auipc	a0,0x1
ffffffffc02007ea:	28250513          	addi	a0,a0,642 # ffffffffc0201a68 <etext+0x54c>
ffffffffc02007ee:	963ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    struct Page *p3 = alloc_pages(3);  // 应该分配 4 页
ffffffffc02007f2:	450d                	li	a0,3
ffffffffc02007f4:	6a4000ef          	jal	ra,ffffffffc0200e98 <alloc_pages>
ffffffffc02007f8:	8a2a                	mv	s4,a0
    assert(p3 != NULL);
ffffffffc02007fa:	2c050463          	beqz	a0,ffffffffc0200ac2 <buddy_check+0x4a6>
    cprintf("  Allocated 3 pages (rounded to 4): PASS\n");
ffffffffc02007fe:	00001517          	auipc	a0,0x1
ffffffffc0200802:	29250513          	addi	a0,a0,658 # ffffffffc0201a90 <etext+0x574>
ffffffffc0200806:	94bff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    struct Page *p4 = alloc_pages(5);  // 应该分配 8 页
ffffffffc020080a:	4515                	li	a0,5
ffffffffc020080c:	68c000ef          	jal	ra,ffffffffc0200e98 <alloc_pages>
ffffffffc0200810:	89aa                	mv	s3,a0
    assert(p4 != NULL);
ffffffffc0200812:	18050863          	beqz	a0,ffffffffc02009a2 <buddy_check+0x386>
    cprintf("  Allocated 5 pages (rounded to 8): PASS\n");
ffffffffc0200816:	00001517          	auipc	a0,0x1
ffffffffc020081a:	2aa50513          	addi	a0,a0,682 # ffffffffc0201ac0 <etext+0x5a4>
ffffffffc020081e:	933ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    free_pages(p3, 3);
ffffffffc0200822:	458d                	li	a1,3
ffffffffc0200824:	8552                	mv	a0,s4
ffffffffc0200826:	67e000ef          	jal	ra,ffffffffc0200ea4 <free_pages>
    free_pages(p4, 5);
ffffffffc020082a:	4595                	li	a1,5
ffffffffc020082c:	854e                	mv	a0,s3
ffffffffc020082e:	676000ef          	jal	ra,ffffffffc0200ea4 <free_pages>
    
    // ============ 测试4：大块分配 ============
    cprintf("\n[Test 4] Large block allocation\n");
ffffffffc0200832:	00001517          	auipc	a0,0x1
ffffffffc0200836:	2be50513          	addi	a0,a0,702 # ffffffffc0201af0 <etext+0x5d4>
ffffffffc020083a:	917ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    struct Page *p5 = alloc_pages(64);
ffffffffc020083e:	04000513          	li	a0,64
ffffffffc0200842:	656000ef          	jal	ra,ffffffffc0200e98 <alloc_pages>
ffffffffc0200846:	89aa                	mv	s3,a0
    assert(p5 != NULL);
ffffffffc0200848:	16050d63          	beqz	a0,ffffffffc02009c2 <buddy_check+0x3a6>
    cprintf("  Allocated 64 pages: PASS\n");
ffffffffc020084c:	00001517          	auipc	a0,0x1
ffffffffc0200850:	2dc50513          	addi	a0,a0,732 # ffffffffc0201b28 <etext+0x60c>
ffffffffc0200854:	8fdff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    free_pages(p5, 64);
ffffffffc0200858:	854e                	mv	a0,s3
ffffffffc020085a:	04000593          	li	a1,64
ffffffffc020085e:	646000ef          	jal	ra,ffffffffc0200ea4 <free_pages>
    
    // ============ 测试5：连续分配释放 ============
    cprintf("\n[Test 5] Sequential alloc/free\n");
ffffffffc0200862:	00001517          	auipc	a0,0x1
ffffffffc0200866:	2e650513          	addi	a0,a0,742 # ffffffffc0201b48 <etext+0x62c>
ffffffffc020086a:	898a                	mv	s3,sp
ffffffffc020086c:	8e5ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    struct Page *pages[10];
    for (int i = 0; i < 10; i++) {
ffffffffc0200870:	05010a93          	addi	s5,sp,80
    cprintf("\n[Test 5] Sequential alloc/free\n");
ffffffffc0200874:	8a4e                	mv	s4,s3
        pages[i] = alloc_pages(1);
ffffffffc0200876:	4505                	li	a0,1
ffffffffc0200878:	620000ef          	jal	ra,ffffffffc0200e98 <alloc_pages>
ffffffffc020087c:	00aa3023          	sd	a0,0(s4)
        assert(pages[i] != NULL);
ffffffffc0200880:	c14d                	beqz	a0,ffffffffc0200922 <buddy_check+0x306>
    for (int i = 0; i < 10; i++) {
ffffffffc0200882:	0a21                	addi	s4,s4,8
ffffffffc0200884:	ff4a99e3          	bne	s5,s4,ffffffffc0200876 <buddy_check+0x25a>
    }
    cprintf("  Allocated 10 single pages: PASS\n");
ffffffffc0200888:	00001517          	auipc	a0,0x1
ffffffffc020088c:	30050513          	addi	a0,a0,768 # ffffffffc0201b88 <etext+0x66c>
ffffffffc0200890:	8c1ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    for (int i = 0; i < 10; i++) {
        free_pages(pages[i], 1);
ffffffffc0200894:	0009b503          	ld	a0,0(s3)
ffffffffc0200898:	4585                	li	a1,1
    for (int i = 0; i < 10; i++) {
ffffffffc020089a:	09a1                	addi	s3,s3,8
        free_pages(pages[i], 1);
ffffffffc020089c:	608000ef          	jal	ra,ffffffffc0200ea4 <free_pages>
    for (int i = 0; i < 10; i++) {
ffffffffc02008a0:	ff3a9ae3          	bne	s5,s3,ffffffffc0200894 <buddy_check+0x278>
    }
    cprintf("  Freed 10 single pages: PASS\n");
ffffffffc02008a4:	00001517          	auipc	a0,0x1
ffffffffc02008a8:	30c50513          	addi	a0,a0,780 # ffffffffc0201bb0 <etext+0x694>
ffffffffc02008ac:	8a5ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    // ============ 测试6：验证最终空闲页数 ============
    cprintf("\n[Test 6] Final free pages check\n");
ffffffffc02008b0:	00001517          	auipc	a0,0x1
ffffffffc02008b4:	32050513          	addi	a0,a0,800 # ffffffffc0201bd0 <etext+0x6b4>
ffffffffc02008b8:	899ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    size_t total = 0;
ffffffffc02008bc:	4981                	li	s3,0
    return 1 << order;
ffffffffc02008be:	4605                	li	a2,1
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02008c0:	46ad                	li	a3,11
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc02008c2:	0004e783          	lwu	a5,0(s1)
    return 1 << order;
ffffffffc02008c6:	0086173b          	sllw	a4,a2,s0
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02008ca:	2405                	addiw	s0,s0,1
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc02008cc:	02e787b3          	mul	a5,a5,a4
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02008d0:	04e1                	addi	s1,s1,24
        total += nr_free(i) * pow2(i);  // 每个块大小为 2^i 页
ffffffffc02008d2:	99be                	add	s3,s3,a5
    for (int i = 0; i < MAX_ORDER; i++) {
ffffffffc02008d4:	fed417e3          	bne	s0,a3,ffffffffc02008c2 <buddy_check+0x2a6>
    size_t final_free = buddy_nr_free_pages();
    cprintf("  Initial free pages: %d\n", total_free_pages);
ffffffffc02008d8:	85ca                	mv	a1,s2
ffffffffc02008da:	00001517          	auipc	a0,0x1
ffffffffc02008de:	31e50513          	addi	a0,a0,798 # ffffffffc0201bf8 <etext+0x6dc>
ffffffffc02008e2:	86fff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    cprintf("  Final free pages:   %d\n", final_free);
ffffffffc02008e6:	85ce                	mv	a1,s3
ffffffffc02008e8:	00001517          	auipc	a0,0x1
ffffffffc02008ec:	33050513          	addi	a0,a0,816 # ffffffffc0201c18 <etext+0x6fc>
ffffffffc02008f0:	861ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    assert(final_free == total_free_pages);
ffffffffc02008f4:	19391763          	bne	s2,s3,ffffffffc0200a82 <buddy_check+0x466>
    cprintf("  Free pages match: PASS\n");
ffffffffc02008f8:	00001517          	auipc	a0,0x1
ffffffffc02008fc:	36050513          	addi	a0,a0,864 # ffffffffc0201c58 <etext+0x73c>
ffffffffc0200900:	851ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    
    cprintf("\n==================== Buddy System Check PASSED ====================\n");
}
ffffffffc0200904:	640a                	ld	s0,128(sp)
ffffffffc0200906:	60aa                	ld	ra,136(sp)
ffffffffc0200908:	74e6                	ld	s1,120(sp)
ffffffffc020090a:	7946                	ld	s2,112(sp)
ffffffffc020090c:	79a6                	ld	s3,104(sp)
ffffffffc020090e:	7a06                	ld	s4,96(sp)
ffffffffc0200910:	6ae6                	ld	s5,88(sp)
ffffffffc0200912:	6b46                	ld	s6,80(sp)
    cprintf("\n==================== Buddy System Check PASSED ====================\n");
ffffffffc0200914:	00001517          	auipc	a0,0x1
ffffffffc0200918:	36450513          	addi	a0,a0,868 # ffffffffc0201c78 <etext+0x75c>
}
ffffffffc020091c:	6149                	addi	sp,sp,144
    cprintf("\n==================== Buddy System Check PASSED ====================\n");
ffffffffc020091e:	833ff06f          	j	ffffffffc0200150 <cprintf>
        assert(pages[i] != NULL);
ffffffffc0200922:	00001697          	auipc	a3,0x1
ffffffffc0200926:	24e68693          	addi	a3,a3,590 # ffffffffc0201b70 <etext+0x654>
ffffffffc020092a:	00001617          	auipc	a2,0x1
ffffffffc020092e:	ee660613          	addi	a2,a2,-282 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200932:	14800593          	li	a1,328
ffffffffc0200936:	00001517          	auipc	a0,0x1
ffffffffc020093a:	ef250513          	addi	a0,a0,-270 # ffffffffc0201828 <etext+0x30c>
ffffffffc020093e:	889ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200942:	00001697          	auipc	a3,0x1
ffffffffc0200946:	f6668693          	addi	a3,a3,-154 # ffffffffc02018a8 <etext+0x38c>
ffffffffc020094a:	00001617          	auipc	a2,0x1
ffffffffc020094e:	ec660613          	addi	a2,a2,-314 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200952:	0f600593          	li	a1,246
ffffffffc0200956:	00001517          	auipc	a0,0x1
ffffffffc020095a:	ed250513          	addi	a0,a0,-302 # ffffffffc0201828 <etext+0x30c>
ffffffffc020095e:	869ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200962:	00001697          	auipc	a3,0x1
ffffffffc0200966:	f1e68693          	addi	a3,a3,-226 # ffffffffc0201880 <etext+0x364>
ffffffffc020096a:	00001617          	auipc	a2,0x1
ffffffffc020096e:	ea660613          	addi	a2,a2,-346 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200972:	0f500593          	li	a1,245
ffffffffc0200976:	00001517          	auipc	a0,0x1
ffffffffc020097a:	eb250513          	addi	a0,a0,-334 # ffffffffc0201828 <etext+0x30c>
ffffffffc020097e:	849ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(p2 != NULL);
ffffffffc0200982:	00001697          	auipc	a3,0x1
ffffffffc0200986:	04668693          	addi	a3,a3,70 # ffffffffc02019c8 <etext+0x4ac>
ffffffffc020098a:	00001617          	auipc	a2,0x1
ffffffffc020098e:	e8660613          	addi	a2,a2,-378 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200992:	11f00593          	li	a1,287
ffffffffc0200996:	00001517          	auipc	a0,0x1
ffffffffc020099a:	e9250513          	addi	a0,a0,-366 # ffffffffc0201828 <etext+0x30c>
ffffffffc020099e:	829ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(p4 != NULL);
ffffffffc02009a2:	00001697          	auipc	a3,0x1
ffffffffc02009a6:	f5668693          	addi	a3,a3,-170 # ffffffffc02018f8 <etext+0x3dc>
ffffffffc02009aa:	00001617          	auipc	a2,0x1
ffffffffc02009ae:	e6660613          	addi	a2,a2,-410 # ffffffffc0201810 <etext+0x2f4>
ffffffffc02009b2:	13500593          	li	a1,309
ffffffffc02009b6:	00001517          	auipc	a0,0x1
ffffffffc02009ba:	e7250513          	addi	a0,a0,-398 # ffffffffc0201828 <etext+0x30c>
ffffffffc02009be:	809ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(p5 != NULL);
ffffffffc02009c2:	00001697          	auipc	a3,0x1
ffffffffc02009c6:	15668693          	addi	a3,a3,342 # ffffffffc0201b18 <etext+0x5fc>
ffffffffc02009ca:	00001617          	auipc	a2,0x1
ffffffffc02009ce:	e4660613          	addi	a2,a2,-442 # ffffffffc0201810 <etext+0x2f4>
ffffffffc02009d2:	13e00593          	li	a1,318
ffffffffc02009d6:	00001517          	auipc	a0,0x1
ffffffffc02009da:	e5250513          	addi	a0,a0,-430 # ffffffffc0201828 <etext+0x30c>
ffffffffc02009de:	fe8ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(free_after == free_before + 1 + 2 + 4);
ffffffffc02009e2:	00001697          	auipc	a3,0x1
ffffffffc02009e6:	03668693          	addi	a3,a3,54 # ffffffffc0201a18 <etext+0x4fc>
ffffffffc02009ea:	00001617          	auipc	a2,0x1
ffffffffc02009ee:	e2660613          	addi	a2,a2,-474 # ffffffffc0201810 <etext+0x2f4>
ffffffffc02009f2:	12b00593          	li	a1,299
ffffffffc02009f6:	00001517          	auipc	a0,0x1
ffffffffc02009fa:	e3250513          	addi	a0,a0,-462 # ffffffffc0201828 <etext+0x30c>
ffffffffc02009fe:	fc8ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200a02:	00001697          	auipc	a3,0x1
ffffffffc0200a06:	e3e68693          	addi	a3,a3,-450 # ffffffffc0201840 <etext+0x324>
ffffffffc0200a0a:	00001617          	auipc	a2,0x1
ffffffffc0200a0e:	e0660613          	addi	a2,a2,-506 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200a12:	0f200593          	li	a1,242
ffffffffc0200a16:	00001517          	auipc	a0,0x1
ffffffffc0200a1a:	e1250513          	addi	a0,a0,-494 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200a1e:	fa8ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(p1 != NULL);
ffffffffc0200a22:	00001697          	auipc	a3,0x1
ffffffffc0200a26:	f7668693          	addi	a3,a3,-138 # ffffffffc0201998 <etext+0x47c>
ffffffffc0200a2a:	00001617          	auipc	a2,0x1
ffffffffc0200a2e:	de660613          	addi	a2,a2,-538 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200a32:	11b00593          	li	a1,283
ffffffffc0200a36:	00001517          	auipc	a0,0x1
ffffffffc0200a3a:	df250513          	addi	a0,a0,-526 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200a3e:	f88ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(p0 != NULL);
ffffffffc0200a42:	00001697          	auipc	a3,0x1
ffffffffc0200a46:	f2668693          	addi	a3,a3,-218 # ffffffffc0201968 <etext+0x44c>
ffffffffc0200a4a:	00001617          	auipc	a2,0x1
ffffffffc0200a4e:	dc660613          	addi	a2,a2,-570 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200a52:	11700593          	li	a1,279
ffffffffc0200a56:	00001517          	auipc	a0,0x1
ffffffffc0200a5a:	dd250513          	addi	a0,a0,-558 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200a5e:	f68ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200a62:	00001697          	auipc	a3,0x1
ffffffffc0200a66:	dfe68693          	addi	a3,a3,-514 # ffffffffc0201860 <etext+0x344>
ffffffffc0200a6a:	00001617          	auipc	a2,0x1
ffffffffc0200a6e:	da660613          	addi	a2,a2,-602 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200a72:	0f300593          	li	a1,243
ffffffffc0200a76:	00001517          	auipc	a0,0x1
ffffffffc0200a7a:	db250513          	addi	a0,a0,-590 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200a7e:	f48ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(final_free == total_free_pages);
ffffffffc0200a82:	00001697          	auipc	a3,0x1
ffffffffc0200a86:	1b668693          	addi	a3,a3,438 # ffffffffc0201c38 <etext+0x71c>
ffffffffc0200a8a:	00001617          	auipc	a2,0x1
ffffffffc0200a8e:	d8660613          	addi	a2,a2,-634 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200a92:	15600593          	li	a1,342
ffffffffc0200a96:	00001517          	auipc	a0,0x1
ffffffffc0200a9a:	d9250513          	addi	a0,a0,-622 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200a9e:	f28ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200aa2:	00001697          	auipc	a3,0x1
ffffffffc0200aa6:	d4e68693          	addi	a3,a3,-690 # ffffffffc02017f0 <etext+0x2d4>
ffffffffc0200aaa:	00001617          	auipc	a2,0x1
ffffffffc0200aae:	d6660613          	addi	a2,a2,-666 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200ab2:	0f100593          	li	a1,241
ffffffffc0200ab6:	00001517          	auipc	a0,0x1
ffffffffc0200aba:	d7250513          	addi	a0,a0,-654 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200abe:	f08ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(p3 != NULL);
ffffffffc0200ac2:	00001697          	auipc	a3,0x1
ffffffffc0200ac6:	e2668693          	addi	a3,a3,-474 # ffffffffc02018e8 <etext+0x3cc>
ffffffffc0200aca:	00001617          	auipc	a2,0x1
ffffffffc0200ace:	d4660613          	addi	a2,a2,-698 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200ad2:	13100593          	li	a1,305
ffffffffc0200ad6:	00001517          	auipc	a0,0x1
ffffffffc0200ada:	d5250513          	addi	a0,a0,-686 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200ade:	ee8ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(p4 != NULL);
ffffffffc0200ae2:	00001697          	auipc	a3,0x1
ffffffffc0200ae6:	e1668693          	addi	a3,a3,-490 # ffffffffc02018f8 <etext+0x3dc>
ffffffffc0200aea:	00001617          	auipc	a2,0x1
ffffffffc0200aee:	d2660613          	addi	a2,a2,-730 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200af2:	10200593          	li	a1,258
ffffffffc0200af6:	00001517          	auipc	a0,0x1
ffffffffc0200afa:	d3250513          	addi	a0,a0,-718 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200afe:	ec8ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(p3 != NULL);
ffffffffc0200b02:	00001697          	auipc	a3,0x1
ffffffffc0200b06:	de668693          	addi	a3,a3,-538 # ffffffffc02018e8 <etext+0x3cc>
ffffffffc0200b0a:	00001617          	auipc	a2,0x1
ffffffffc0200b0e:	d0660613          	addi	a2,a2,-762 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200b12:	0ff00593          	li	a1,255
ffffffffc0200b16:	00001517          	auipc	a0,0x1
ffffffffc0200b1a:	d1250513          	addi	a0,a0,-750 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200b1e:	ea8ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc0200b22 <buddy_free_pages>:
static void buddy_free_pages(struct Page *base, size_t n) {
ffffffffc0200b22:	1141                	addi	sp,sp,-16
ffffffffc0200b24:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200b26:	14058063          	beqz	a1,ffffffffc0200c66 <buddy_free_pages+0x144>
    while (size < n) {
ffffffffc0200b2a:	4705                	li	a4,1
    size_t size = 1;
ffffffffc0200b2c:	4785                	li	a5,1
    unsigned int order = 0;
ffffffffc0200b2e:	4681                	li	a3,0
    while (size < n) {
ffffffffc0200b30:	10e58863          	beq	a1,a4,ffffffffc0200c40 <buddy_free_pages+0x11e>
        size <<= 1;
ffffffffc0200b34:	0786                	slli	a5,a5,0x1
        order++;
ffffffffc0200b36:	2685                	addiw	a3,a3,1
    while (size < n) {
ffffffffc0200b38:	feb7eee3          	bltu	a5,a1,ffffffffc0200b34 <buddy_free_pages+0x12>
    if (order >= MAX_ORDER) {
ffffffffc0200b3c:	47a9                	li	a5,10
ffffffffc0200b3e:	0ed7ee63          	bltu	a5,a3,ffffffffc0200c3a <buddy_free_pages+0x118>
    return 1 << order;
ffffffffc0200b42:	4605                	li	a2,1
ffffffffc0200b44:	00d617bb          	sllw	a5,a2,a3
    for (; p != base + pow2(order); p++) {
ffffffffc0200b48:	00279613          	slli	a2,a5,0x2
ffffffffc0200b4c:	963e                	add	a2,a2,a5
ffffffffc0200b4e:	060e                	slli	a2,a2,0x3
ffffffffc0200b50:	962a                	add	a2,a2,a0
    unsigned int order = 0;
ffffffffc0200b52:	87aa                	mv	a5,a0
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200b54:	6798                	ld	a4,8(a5)
ffffffffc0200b56:	8b0d                	andi	a4,a4,3
ffffffffc0200b58:	e77d                	bnez	a4,ffffffffc0200c46 <buddy_free_pages+0x124>
        p->flags = 0;
ffffffffc0200b5a:	0007b423          	sd	zero,8(a5)

// 设置页的引用计数
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200b5e:	0007a023          	sw	zero,0(a5)
    for (; p != base + pow2(order); p++) {
ffffffffc0200b62:	02878793          	addi	a5,a5,40
ffffffffc0200b66:	fec797e3          	bne	a5,a2,ffffffffc0200b54 <buddy_free_pages+0x32>
    SetPageProperty(base);
ffffffffc0200b6a:	651c                	ld	a5,8(a0)
    base->property = order;
ffffffffc0200b6c:	c914                	sw	a3,16(a0)
    while (order < MAX_ORDER - 1) {
ffffffffc0200b6e:	4729                	li	a4,10
    SetPageProperty(base);
ffffffffc0200b70:	0027e793          	ori	a5,a5,2
ffffffffc0200b74:	e51c                	sd	a5,8(a0)
    while (order < MAX_ORDER - 1) {
ffffffffc0200b76:	00005e97          	auipc	t4,0x5
ffffffffc0200b7a:	4a2e8e93          	addi	t4,t4,1186 # ffffffffc0206018 <free_area>
ffffffffc0200b7e:	08e68863          	beq	a3,a4,ffffffffc0200c0e <buddy_free_pages+0xec>
ffffffffc0200b82:	02069793          	slli	a5,a3,0x20
ffffffffc0200b86:	9381                	srli	a5,a5,0x20
ffffffffc0200b88:	00179613          	slli	a2,a5,0x1
ffffffffc0200b8c:	963e                	add	a2,a2,a5
ffffffffc0200b8e:	00005e97          	auipc	t4,0x5
ffffffffc0200b92:	48ae8e93          	addi	t4,t4,1162 # ffffffffc0206018 <free_area>
ffffffffc0200b96:	060e                	slli	a2,a2,0x3
        size_t page_idx = base - pages;
ffffffffc0200b98:	00005317          	auipc	t1,0x5
ffffffffc0200b9c:	5a833303          	ld	t1,1448(t1) # ffffffffc0206140 <pages>
        if (buddy_page_idx >= npage) {
ffffffffc0200ba0:	00005f97          	auipc	t6,0x5
ffffffffc0200ba4:	598fbf83          	ld	t6,1432(t6) # ffffffffc0206138 <npage>
ffffffffc0200ba8:	9676                	add	a2,a2,t4
ffffffffc0200baa:	00001f17          	auipc	t5,0x1
ffffffffc0200bae:	536f3f03          	ld	t5,1334(t5) # ffffffffc02020e0 <error_string+0x38>
    return page_idx ^ (1 << order);
ffffffffc0200bb2:	4e05                	li	t3,1
    while (order < MAX_ORDER - 1) {
ffffffffc0200bb4:	42a9                	li	t0,10
ffffffffc0200bb6:	a091                	j	ffffffffc0200bfa <buddy_free_pages+0xd8>
        struct Page *buddy_page = &pages[buddy_page_idx];
ffffffffc0200bb8:	00271793          	slli	a5,a4,0x2
ffffffffc0200bbc:	97ba                	add	a5,a5,a4
ffffffffc0200bbe:	078e                	slli	a5,a5,0x3
ffffffffc0200bc0:	979a                	add	a5,a5,t1
        if (!PageProperty(buddy_page) || buddy_page->property != order) {
ffffffffc0200bc2:	6798                	ld	a4,8(a5)
ffffffffc0200bc4:	00277593          	andi	a1,a4,2
ffffffffc0200bc8:	c1b9                	beqz	a1,ffffffffc0200c0e <buddy_free_pages+0xec>
ffffffffc0200bca:	4b8c                	lw	a1,16(a5)
ffffffffc0200bcc:	04d59163          	bne	a1,a3,ffffffffc0200c0e <buddy_free_pages+0xec>
 * Note: list_empty() on @listelm does not return true after this, the entry is
 * in an undefined state.
 * */
static inline void
list_del(list_entry_t *listelm) {
    __list_del(listelm->prev, listelm->next);
ffffffffc0200bd0:	0187b883          	ld	a7,24(a5)
ffffffffc0200bd4:	0207b803          	ld	a6,32(a5)
        nr_free(order)--;
ffffffffc0200bd8:	4a0c                	lw	a1,16(a2)
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc0200bda:	0108b423          	sd	a6,8(a7)
    next->prev = prev;
ffffffffc0200bde:	01183023          	sd	a7,0(a6)
ffffffffc0200be2:	35fd                	addiw	a1,a1,-1
ffffffffc0200be4:	ca0c                	sw	a1,16(a2)
        if (buddy_page < base) {
ffffffffc0200be6:	00a7f363          	bgeu	a5,a0,ffffffffc0200bec <buddy_free_pages+0xca>
ffffffffc0200bea:	853e                	mv	a0,a5
        ClearPageProperty(buddy_page < base ? base : buddy_page);
ffffffffc0200bec:	9b75                	andi	a4,a4,-3
        order++;
ffffffffc0200bee:	2685                	addiw	a3,a3,1
        ClearPageProperty(buddy_page < base ? base : buddy_page);
ffffffffc0200bf0:	e798                	sd	a4,8(a5)
        base->property = order;
ffffffffc0200bf2:	c914                	sw	a3,16(a0)
    while (order < MAX_ORDER - 1) {
ffffffffc0200bf4:	0661                	addi	a2,a2,24
ffffffffc0200bf6:	00568c63          	beq	a3,t0,ffffffffc0200c0e <buddy_free_pages+0xec>
        size_t page_idx = base - pages;
ffffffffc0200bfa:	406507b3          	sub	a5,a0,t1
ffffffffc0200bfe:	878d                	srai	a5,a5,0x3
ffffffffc0200c00:	03e787b3          	mul	a5,a5,t5
    return page_idx ^ (1 << order);
ffffffffc0200c04:	00de173b          	sllw	a4,t3,a3
ffffffffc0200c08:	8f3d                	xor	a4,a4,a5
        if (buddy_page_idx >= npage) {
ffffffffc0200c0a:	fbf767e3          	bltu	a4,t6,ffffffffc0200bb8 <buddy_free_pages+0x96>
    __list_add(elm, listelm, listelm->next);
ffffffffc0200c0e:	1682                	slli	a3,a3,0x20
ffffffffc0200c10:	9281                	srli	a3,a3,0x20
ffffffffc0200c12:	00169793          	slli	a5,a3,0x1
ffffffffc0200c16:	96be                	add	a3,a3,a5
ffffffffc0200c18:	068e                	slli	a3,a3,0x3
ffffffffc0200c1a:	9eb6                	add	t4,t4,a3
ffffffffc0200c1c:	008eb703          	ld	a4,8(t4)
    nr_free(order)++;
ffffffffc0200c20:	010ea783          	lw	a5,16(t4)
    list_add(&free_list(order), &(base->page_link));
ffffffffc0200c24:	01850693          	addi	a3,a0,24
    prev->next = next->prev = elm;
ffffffffc0200c28:	e314                	sd	a3,0(a4)
ffffffffc0200c2a:	00deb423          	sd	a3,8(t4)
    elm->next = next;
ffffffffc0200c2e:	f118                	sd	a4,32(a0)
    elm->prev = prev;
ffffffffc0200c30:	01d53c23          	sd	t4,24(a0)
    nr_free(order)++;
ffffffffc0200c34:	2785                	addiw	a5,a5,1
ffffffffc0200c36:	00fea823          	sw	a5,16(t4)
}
ffffffffc0200c3a:	60a2                	ld	ra,8(sp)
ffffffffc0200c3c:	0141                	addi	sp,sp,16
ffffffffc0200c3e:	8082                	ret
    for (; p != base + pow2(order); p++) {
ffffffffc0200c40:	02850613          	addi	a2,a0,40
ffffffffc0200c44:	b739                	j	ffffffffc0200b52 <buddy_free_pages+0x30>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200c46:	00001697          	auipc	a3,0x1
ffffffffc0200c4a:	08268693          	addi	a3,a3,130 # ffffffffc0201cc8 <etext+0x7ac>
ffffffffc0200c4e:	00001617          	auipc	a2,0x1
ffffffffc0200c52:	bc260613          	addi	a2,a2,-1086 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200c56:	0b000593          	li	a1,176
ffffffffc0200c5a:	00001517          	auipc	a0,0x1
ffffffffc0200c5e:	bce50513          	addi	a0,a0,-1074 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200c62:	d64ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(n > 0);
ffffffffc0200c66:	00001697          	auipc	a3,0x1
ffffffffc0200c6a:	05a68693          	addi	a3,a3,90 # ffffffffc0201cc0 <etext+0x7a4>
ffffffffc0200c6e:	00001617          	auipc	a2,0x1
ffffffffc0200c72:	ba260613          	addi	a2,a2,-1118 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200c76:	0a500593          	li	a1,165
ffffffffc0200c7a:	00001517          	auipc	a0,0x1
ffffffffc0200c7e:	bae50513          	addi	a0,a0,-1106 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200c82:	d44ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc0200c86 <buddy_alloc_pages>:
    assert(n > 0);
ffffffffc0200c86:	c565                	beqz	a0,ffffffffc0200d6e <buddy_alloc_pages+0xe8>
    while (size < n) {
ffffffffc0200c88:	4705                	li	a4,1
    size_t size = 1;
ffffffffc0200c8a:	4785                	li	a5,1
    unsigned int order = 0;
ffffffffc0200c8c:	4581                	li	a1,0
    while (size < n) {
ffffffffc0200c8e:	00e50963          	beq	a0,a4,ffffffffc0200ca0 <buddy_alloc_pages+0x1a>
        size <<= 1;
ffffffffc0200c92:	0786                	slli	a5,a5,0x1
        order++;
ffffffffc0200c94:	2585                	addiw	a1,a1,1
    while (size < n) {
ffffffffc0200c96:	fea7eee3          	bltu	a5,a0,ffffffffc0200c92 <buddy_alloc_pages+0xc>
    if (order >= MAX_ORDER) {
ffffffffc0200c9a:	47a9                	li	a5,10
ffffffffc0200c9c:	04b7e063          	bltu	a5,a1,ffffffffc0200cdc <buddy_alloc_pages+0x56>
ffffffffc0200ca0:	02059793          	slli	a5,a1,0x20
ffffffffc0200ca4:	9381                	srli	a5,a5,0x20
ffffffffc0200ca6:	00179613          	slli	a2,a5,0x1
ffffffffc0200caa:	963e                	add	a2,a2,a5
ffffffffc0200cac:	00005697          	auipc	a3,0x5
ffffffffc0200cb0:	36c68693          	addi	a3,a3,876 # ffffffffc0206018 <free_area>
ffffffffc0200cb4:	060e                	slli	a2,a2,0x3
ffffffffc0200cb6:	9636                	add	a2,a2,a3
    unsigned int order = 0;
ffffffffc0200cb8:	87ae                	mv	a5,a1
    while (current_order < MAX_ORDER) {
ffffffffc0200cba:	482d                	li	a6,11
    return list->next == list;
ffffffffc0200cbc:	02079513          	slli	a0,a5,0x20
ffffffffc0200cc0:	9101                	srli	a0,a0,0x20
ffffffffc0200cc2:	00151713          	slli	a4,a0,0x1
ffffffffc0200cc6:	972a                	add	a4,a4,a0
ffffffffc0200cc8:	070e                	slli	a4,a4,0x3
ffffffffc0200cca:	9736                	add	a4,a4,a3
ffffffffc0200ccc:	00873883          	ld	a7,8(a4)
        if (!list_empty(&free_list(current_order))) {
ffffffffc0200cd0:	00c89863          	bne	a7,a2,ffffffffc0200ce0 <buddy_alloc_pages+0x5a>
        current_order++;
ffffffffc0200cd4:	2785                	addiw	a5,a5,1
    while (current_order < MAX_ORDER) {
ffffffffc0200cd6:	0661                	addi	a2,a2,24
ffffffffc0200cd8:	ff0792e3          	bne	a5,a6,ffffffffc0200cbc <buddy_alloc_pages+0x36>
        return NULL;  // 请求的块太大
ffffffffc0200cdc:	4501                	li	a0,0
}
ffffffffc0200cde:	8082                	ret
    __list_del(listelm->prev, listelm->next);
ffffffffc0200ce0:	0008b303          	ld	t1,0(a7)
ffffffffc0200ce4:	0088b803          	ld	a6,8(a7)
    nr_free(current_order)--;
ffffffffc0200ce8:	4b10                	lw	a2,16(a4)
    struct Page *page = le2page(le, page_link);
ffffffffc0200cea:	fe888513          	addi	a0,a7,-24
    prev->next = next;
ffffffffc0200cee:	01033423          	sd	a6,8(t1)
    next->prev = prev;
ffffffffc0200cf2:	00683023          	sd	t1,0(a6)
    nr_free(current_order)--;
ffffffffc0200cf6:	367d                	addiw	a2,a2,-1
ffffffffc0200cf8:	cb10                	sw	a2,16(a4)
    while (current_order > order) {
ffffffffc0200cfa:	06f5f263          	bgeu	a1,a5,ffffffffc0200d5e <buddy_alloc_pages+0xd8>
ffffffffc0200cfe:	fff7871b          	addiw	a4,a5,-1
ffffffffc0200d02:	02071613          	slli	a2,a4,0x20
ffffffffc0200d06:	9201                	srli	a2,a2,0x20
ffffffffc0200d08:	00161793          	slli	a5,a2,0x1
ffffffffc0200d0c:	97b2                	add	a5,a5,a2
ffffffffc0200d0e:	078e                	slli	a5,a5,0x3
ffffffffc0200d10:	96be                	add	a3,a3,a5
    return 1 << order;
ffffffffc0200d12:	4e05                	li	t3,1
ffffffffc0200d14:	a019                	j	ffffffffc0200d1a <buddy_alloc_pages+0x94>
ffffffffc0200d16:	fff7871b          	addiw	a4,a5,-1
ffffffffc0200d1a:	00ee163b          	sllw	a2,t3,a4
        struct Page *buddy = page + half_size;
ffffffffc0200d1e:	00261793          	slli	a5,a2,0x2
ffffffffc0200d22:	97b2                	add	a5,a5,a2
ffffffffc0200d24:	078e                	slli	a5,a5,0x3
ffffffffc0200d26:	97aa                	add	a5,a5,a0
        SetPageProperty(buddy);
ffffffffc0200d28:	0087b803          	ld	a6,8(a5)
    __list_add(elm, listelm, listelm->next);
ffffffffc0200d2c:	0086b303          	ld	t1,8(a3)
        buddy->property = current_order;
ffffffffc0200d30:	cb98                	sw	a4,16(a5)
        SetPageProperty(buddy);
ffffffffc0200d32:	00286813          	ori	a6,a6,2
        nr_free(current_order)++;
ffffffffc0200d36:	4a90                	lw	a2,16(a3)
        SetPageProperty(buddy);
ffffffffc0200d38:	0107b423          	sd	a6,8(a5)
        list_add(&free_list(current_order), &(buddy->page_link));
ffffffffc0200d3c:	01878813          	addi	a6,a5,24
    prev->next = next->prev = elm;
ffffffffc0200d40:	01033023          	sd	a6,0(t1)
ffffffffc0200d44:	0106b423          	sd	a6,8(a3)
    elm->prev = prev;
ffffffffc0200d48:	ef94                	sd	a3,24(a5)
    elm->next = next;
ffffffffc0200d4a:	0267b023          	sd	t1,32(a5)
        nr_free(current_order)++;
ffffffffc0200d4e:	0016079b          	addiw	a5,a2,1
ffffffffc0200d52:	ca9c                	sw	a5,16(a3)
        current_order--;
ffffffffc0200d54:	0007079b          	sext.w	a5,a4
    while (current_order > order) {
ffffffffc0200d58:	16a1                	addi	a3,a3,-24
ffffffffc0200d5a:	faf59ee3          	bne	a1,a5,ffffffffc0200d16 <buddy_alloc_pages+0x90>
    ClearPageProperty(page);
ffffffffc0200d5e:	ff08b783          	ld	a5,-16(a7)
    page->property = order;  // 记录分配的阶数，用于释放时恢复
ffffffffc0200d62:	feb8ac23          	sw	a1,-8(a7)
    ClearPageProperty(page);
ffffffffc0200d66:	9bf5                	andi	a5,a5,-3
ffffffffc0200d68:	fef8b823          	sd	a5,-16(a7)
    return page;
ffffffffc0200d6c:	8082                	ret
static struct Page *buddy_alloc_pages(size_t n) {
ffffffffc0200d6e:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc0200d70:	00001697          	auipc	a3,0x1
ffffffffc0200d74:	f5068693          	addi	a3,a3,-176 # ffffffffc0201cc0 <etext+0x7a4>
ffffffffc0200d78:	00001617          	auipc	a2,0x1
ffffffffc0200d7c:	a9860613          	addi	a2,a2,-1384 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200d80:	07000593          	li	a1,112
ffffffffc0200d84:	00001517          	auipc	a0,0x1
ffffffffc0200d88:	aa450513          	addi	a0,a0,-1372 # ffffffffc0201828 <etext+0x30c>
static struct Page *buddy_alloc_pages(size_t n) {
ffffffffc0200d8c:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200d8e:	c38ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc0200d92 <buddy_init_memmap>:
static void buddy_init_memmap(struct Page *base, size_t n) {
ffffffffc0200d92:	1141                	addi	sp,sp,-16
ffffffffc0200d94:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200d96:	c1ed                	beqz	a1,ffffffffc0200e78 <buddy_init_memmap+0xe6>
    for (; p != base + n; p++) {
ffffffffc0200d98:	00259693          	slli	a3,a1,0x2
ffffffffc0200d9c:	96ae                	add	a3,a3,a1
ffffffffc0200d9e:	068e                	slli	a3,a3,0x3
ffffffffc0200da0:	96aa                	add	a3,a3,a0
ffffffffc0200da2:	87aa                	mv	a5,a0
ffffffffc0200da4:	00d50f63          	beq	a0,a3,ffffffffc0200dc2 <buddy_init_memmap+0x30>
        assert(PageReserved(p));
ffffffffc0200da8:	6798                	ld	a4,8(a5)
ffffffffc0200daa:	8b05                	andi	a4,a4,1
ffffffffc0200dac:	c755                	beqz	a4,ffffffffc0200e58 <buddy_init_memmap+0xc6>
        p->flags = 0;
ffffffffc0200dae:	0007b423          	sd	zero,8(a5)
        p->property = 0;
ffffffffc0200db2:	0007a823          	sw	zero,16(a5)
ffffffffc0200db6:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p++) {
ffffffffc0200dba:	02878793          	addi	a5,a5,40
ffffffffc0200dbe:	fed795e3          	bne	a5,a3,ffffffffc0200da8 <buddy_init_memmap+0x16>
    size_t offset = 0;
ffffffffc0200dc2:	4301                	li	t1,0
ffffffffc0200dc4:	00005f97          	auipc	t6,0x5
ffffffffc0200dc8:	254f8f93          	addi	t6,t6,596 # ffffffffc0206018 <free_area>
    return 1 << order;
ffffffffc0200dcc:	4605                	li	a2,1
        while (pow2(order + 1) <= remaining && order + 1 < MAX_ORDER) {
ffffffffc0200dce:	482d                	li	a6,11
        unsigned int order = 0;
ffffffffc0200dd0:	4781                	li	a5,0
        while (pow2(order + 1) <= remaining && order + 1 < MAX_ORDER) {
ffffffffc0200dd2:	0007869b          	sext.w	a3,a5
ffffffffc0200dd6:	2785                	addiw	a5,a5,1
    return 1 << order;
ffffffffc0200dd8:	00f6173b          	sllw	a4,a2,a5
        while (pow2(order + 1) <= remaining && order + 1 < MAX_ORDER) {
ffffffffc0200ddc:	06e5e363          	bltu	a1,a4,ffffffffc0200e42 <buddy_init_memmap+0xb0>
ffffffffc0200de0:	ff0799e3          	bne	a5,a6,ffffffffc0200dd2 <buddy_init_memmap+0x40>
ffffffffc0200de4:	40000f13          	li	t5,1024
ffffffffc0200de8:	0f000893          	li	a7,240
ffffffffc0200dec:	46a9                	li	a3,10
ffffffffc0200dee:	4ea9                	li	t4,10
        struct Page *block = base + offset;
ffffffffc0200df0:	00231793          	slli	a5,t1,0x2
ffffffffc0200df4:	979a                	add	a5,a5,t1
ffffffffc0200df6:	078e                	slli	a5,a5,0x3
ffffffffc0200df8:	97aa                	add	a5,a5,a0
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200dfa:	001e9713          	slli	a4,t4,0x1
        SetPageProperty(block);   // 标记为空闲块头部
ffffffffc0200dfe:	0087be03          	ld	t3,8(a5)
ffffffffc0200e02:	9776                	add	a4,a4,t4
ffffffffc0200e04:	070e                	slli	a4,a4,0x3
ffffffffc0200e06:	977e                	add	a4,a4,t6
ffffffffc0200e08:	00073e83          	ld	t4,0(a4)
ffffffffc0200e0c:	002e6e13          	ori	t3,t3,2
        block->property = order;  // 存储块的阶数
ffffffffc0200e10:	cb94                	sw	a3,16(a5)
        SetPageProperty(block);   // 标记为空闲块头部
ffffffffc0200e12:	01c7b423          	sd	t3,8(a5)
        list_add_before(&free_list(order), &(block->page_link));
ffffffffc0200e16:	01878693          	addi	a3,a5,24
        nr_free(order)++;
ffffffffc0200e1a:	01072e03          	lw	t3,16(a4)
    prev->next = next->prev = elm;
ffffffffc0200e1e:	e314                	sd	a3,0(a4)
ffffffffc0200e20:	00deb423          	sd	a3,8(t4)
        list_add_before(&free_list(order), &(block->page_link));
ffffffffc0200e24:	011f86b3          	add	a3,t6,a7
    elm->next = next;
ffffffffc0200e28:	f394                	sd	a3,32(a5)
    elm->prev = prev;
ffffffffc0200e2a:	01d7bc23          	sd	t4,24(a5)
        nr_free(order)++;
ffffffffc0200e2e:	001e079b          	addiw	a5,t3,1
ffffffffc0200e32:	cb1c                	sw	a5,16(a4)
        remaining -= block_size;
ffffffffc0200e34:	41e585b3          	sub	a1,a1,t5
        offset += block_size;
ffffffffc0200e38:	937a                	add	t1,t1,t5
    while (remaining > 0) {
ffffffffc0200e3a:	f9d9                	bnez	a1,ffffffffc0200dd0 <buddy_init_memmap+0x3e>
}
ffffffffc0200e3c:	60a2                	ld	ra,8(sp)
ffffffffc0200e3e:	0141                	addi	sp,sp,16
ffffffffc0200e40:	8082                	ret
ffffffffc0200e42:	02069e93          	slli	t4,a3,0x20
ffffffffc0200e46:	020ede93          	srli	t4,t4,0x20
ffffffffc0200e4a:	001e9893          	slli	a7,t4,0x1
ffffffffc0200e4e:	98f6                	add	a7,a7,t4
ffffffffc0200e50:	088e                	slli	a7,a7,0x3
    return 1 << order;
ffffffffc0200e52:	00d61f3b          	sllw	t5,a2,a3
ffffffffc0200e56:	bf69                	j	ffffffffc0200df0 <buddy_init_memmap+0x5e>
        assert(PageReserved(p));
ffffffffc0200e58:	00001697          	auipc	a3,0x1
ffffffffc0200e5c:	e9868693          	addi	a3,a3,-360 # ffffffffc0201cf0 <etext+0x7d4>
ffffffffc0200e60:	00001617          	auipc	a2,0x1
ffffffffc0200e64:	9b060613          	addi	a2,a2,-1616 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200e68:	04d00593          	li	a1,77
ffffffffc0200e6c:	00001517          	auipc	a0,0x1
ffffffffc0200e70:	9bc50513          	addi	a0,a0,-1604 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200e74:	b52ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    assert(n > 0);
ffffffffc0200e78:	00001697          	auipc	a3,0x1
ffffffffc0200e7c:	e4868693          	addi	a3,a3,-440 # ffffffffc0201cc0 <etext+0x7a4>
ffffffffc0200e80:	00001617          	auipc	a2,0x1
ffffffffc0200e84:	99060613          	addi	a2,a2,-1648 # ffffffffc0201810 <etext+0x2f4>
ffffffffc0200e88:	04800593          	li	a1,72
ffffffffc0200e8c:	00001517          	auipc	a0,0x1
ffffffffc0200e90:	99c50513          	addi	a0,a0,-1636 # ffffffffc0201828 <etext+0x30c>
ffffffffc0200e94:	b32ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc0200e98 <alloc_pages>:
}

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n) {
    return pmm_manager->alloc_pages(n);
ffffffffc0200e98:	00005797          	auipc	a5,0x5
ffffffffc0200e9c:	2b07b783          	ld	a5,688(a5) # ffffffffc0206148 <pmm_manager>
ffffffffc0200ea0:	6f9c                	ld	a5,24(a5)
ffffffffc0200ea2:	8782                	jr	a5

ffffffffc0200ea4 <free_pages>:
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
ffffffffc0200ea4:	00005797          	auipc	a5,0x5
ffffffffc0200ea8:	2a47b783          	ld	a5,676(a5) # ffffffffc0206148 <pmm_manager>
ffffffffc0200eac:	739c                	ld	a5,32(a5)
ffffffffc0200eae:	8782                	jr	a5

ffffffffc0200eb0 <pmm_init>:
    pmm_manager = &buddy_pmm_manager;      // 新增：Buddy System 伙伴系统算法
ffffffffc0200eb0:	00001797          	auipc	a5,0x1
ffffffffc0200eb4:	e6878793          	addi	a5,a5,-408 # ffffffffc0201d18 <buddy_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200eb8:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
    }
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc0200eba:	7179                	addi	sp,sp,-48
ffffffffc0200ebc:	f022                	sd	s0,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200ebe:	00001517          	auipc	a0,0x1
ffffffffc0200ec2:	e9250513          	addi	a0,a0,-366 # ffffffffc0201d50 <buddy_pmm_manager+0x38>
    pmm_manager = &buddy_pmm_manager;      // 新增：Buddy System 伙伴系统算法
ffffffffc0200ec6:	00005417          	auipc	s0,0x5
ffffffffc0200eca:	28240413          	addi	s0,s0,642 # ffffffffc0206148 <pmm_manager>
void pmm_init(void) {
ffffffffc0200ece:	f406                	sd	ra,40(sp)
ffffffffc0200ed0:	ec26                	sd	s1,24(sp)
ffffffffc0200ed2:	e44e                	sd	s3,8(sp)
ffffffffc0200ed4:	e84a                	sd	s2,16(sp)
ffffffffc0200ed6:	e052                	sd	s4,0(sp)
    pmm_manager = &buddy_pmm_manager;      // 新增：Buddy System 伙伴系统算法
ffffffffc0200ed8:	e01c                	sd	a5,0(s0)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200eda:	a76ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    pmm_manager->init();
ffffffffc0200ede:	601c                	ld	a5,0(s0)
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200ee0:	00005497          	auipc	s1,0x5
ffffffffc0200ee4:	28048493          	addi	s1,s1,640 # ffffffffc0206160 <va_pa_offset>
    pmm_manager->init();
ffffffffc0200ee8:	679c                	ld	a5,8(a5)
ffffffffc0200eea:	9782                	jalr	a5
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200eec:	57f5                	li	a5,-3
ffffffffc0200eee:	07fa                	slli	a5,a5,0x1e
ffffffffc0200ef0:	e09c                	sd	a5,0(s1)
    uint64_t mem_begin = get_memory_base();
ffffffffc0200ef2:	eceff0ef          	jal	ra,ffffffffc02005c0 <get_memory_base>
ffffffffc0200ef6:	89aa                	mv	s3,a0
    uint64_t mem_size  = get_memory_size();
ffffffffc0200ef8:	ed2ff0ef          	jal	ra,ffffffffc02005ca <get_memory_size>
    if (mem_size == 0) {
ffffffffc0200efc:	14050d63          	beqz	a0,ffffffffc0201056 <pmm_init+0x1a6>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0200f00:	892a                	mv	s2,a0
    cprintf("physcial memory map:\n");
ffffffffc0200f02:	00001517          	auipc	a0,0x1
ffffffffc0200f06:	e9650513          	addi	a0,a0,-362 # ffffffffc0201d98 <buddy_pmm_manager+0x80>
ffffffffc0200f0a:	a46ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0200f0e:	01298a33          	add	s4,s3,s2
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n", mem_size, mem_begin,
ffffffffc0200f12:	864e                	mv	a2,s3
ffffffffc0200f14:	fffa0693          	addi	a3,s4,-1
ffffffffc0200f18:	85ca                	mv	a1,s2
ffffffffc0200f1a:	00001517          	auipc	a0,0x1
ffffffffc0200f1e:	e9650513          	addi	a0,a0,-362 # ffffffffc0201db0 <buddy_pmm_manager+0x98>
ffffffffc0200f22:	a2eff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0200f26:	c80007b7          	lui	a5,0xc8000
ffffffffc0200f2a:	8652                	mv	a2,s4
ffffffffc0200f2c:	0d47e463          	bltu	a5,s4,ffffffffc0200ff4 <pmm_init+0x144>
ffffffffc0200f30:	00006797          	auipc	a5,0x6
ffffffffc0200f34:	23778793          	addi	a5,a5,567 # ffffffffc0207167 <end+0xfff>
ffffffffc0200f38:	757d                	lui	a0,0xfffff
ffffffffc0200f3a:	8d7d                	and	a0,a0,a5
ffffffffc0200f3c:	8231                	srli	a2,a2,0xc
ffffffffc0200f3e:	00005797          	auipc	a5,0x5
ffffffffc0200f42:	1ec7bd23          	sd	a2,506(a5) # ffffffffc0206138 <npage>
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc0200f46:	00005797          	auipc	a5,0x5
ffffffffc0200f4a:	1ea7bd23          	sd	a0,506(a5) # ffffffffc0206140 <pages>
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0200f4e:	000807b7          	lui	a5,0x80
ffffffffc0200f52:	002005b7          	lui	a1,0x200
ffffffffc0200f56:	02f60563          	beq	a2,a5,ffffffffc0200f80 <pmm_init+0xd0>
ffffffffc0200f5a:	00261593          	slli	a1,a2,0x2
ffffffffc0200f5e:	00c586b3          	add	a3,a1,a2
ffffffffc0200f62:	fec007b7          	lui	a5,0xfec00
ffffffffc0200f66:	97aa                	add	a5,a5,a0
ffffffffc0200f68:	068e                	slli	a3,a3,0x3
ffffffffc0200f6a:	96be                	add	a3,a3,a5
ffffffffc0200f6c:	87aa                	mv	a5,a0
        SetPageReserved(pages + i);
ffffffffc0200f6e:	6798                	ld	a4,8(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0200f70:	02878793          	addi	a5,a5,40 # fffffffffec00028 <end+0x3e9f9ec0>
        SetPageReserved(pages + i);
ffffffffc0200f74:	00176713          	ori	a4,a4,1
ffffffffc0200f78:	fee7b023          	sd	a4,-32(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0200f7c:	fef699e3          	bne	a3,a5,ffffffffc0200f6e <pmm_init+0xbe>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc0200f80:	95b2                	add	a1,a1,a2
ffffffffc0200f82:	fec006b7          	lui	a3,0xfec00
ffffffffc0200f86:	96aa                	add	a3,a3,a0
ffffffffc0200f88:	058e                	slli	a1,a1,0x3
ffffffffc0200f8a:	96ae                	add	a3,a3,a1
ffffffffc0200f8c:	c02007b7          	lui	a5,0xc0200
ffffffffc0200f90:	0af6e763          	bltu	a3,a5,ffffffffc020103e <pmm_init+0x18e>
ffffffffc0200f94:	6098                	ld	a4,0(s1)
    mem_end = ROUNDDOWN(mem_end, PGSIZE);
ffffffffc0200f96:	77fd                	lui	a5,0xfffff
ffffffffc0200f98:	00fa75b3          	and	a1,s4,a5
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc0200f9c:	8e99                	sub	a3,a3,a4
    if (freemem < mem_end) {
ffffffffc0200f9e:	04b6ee63          	bltu	a3,a1,ffffffffc0200ffa <pmm_init+0x14a>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc0200fa2:	601c                	ld	a5,0(s0)
ffffffffc0200fa4:	7b9c                	ld	a5,48(a5)
ffffffffc0200fa6:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc0200fa8:	00001517          	auipc	a0,0x1
ffffffffc0200fac:	e9050513          	addi	a0,a0,-368 # ffffffffc0201e38 <buddy_pmm_manager+0x120>
ffffffffc0200fb0:	9a0ff0ef          	jal	ra,ffffffffc0200150 <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc0200fb4:	00004597          	auipc	a1,0x4
ffffffffc0200fb8:	04c58593          	addi	a1,a1,76 # ffffffffc0205000 <boot_page_table_sv39>
ffffffffc0200fbc:	00005797          	auipc	a5,0x5
ffffffffc0200fc0:	18b7be23          	sd	a1,412(a5) # ffffffffc0206158 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc0200fc4:	c02007b7          	lui	a5,0xc0200
ffffffffc0200fc8:	0af5e363          	bltu	a1,a5,ffffffffc020106e <pmm_init+0x1be>
ffffffffc0200fcc:	6090                	ld	a2,0(s1)
}
ffffffffc0200fce:	7402                	ld	s0,32(sp)
ffffffffc0200fd0:	70a2                	ld	ra,40(sp)
ffffffffc0200fd2:	64e2                	ld	s1,24(sp)
ffffffffc0200fd4:	6942                	ld	s2,16(sp)
ffffffffc0200fd6:	69a2                	ld	s3,8(sp)
ffffffffc0200fd8:	6a02                	ld	s4,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc0200fda:	40c58633          	sub	a2,a1,a2
ffffffffc0200fde:	00005797          	auipc	a5,0x5
ffffffffc0200fe2:	16c7b923          	sd	a2,370(a5) # ffffffffc0206150 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200fe6:	00001517          	auipc	a0,0x1
ffffffffc0200fea:	e7250513          	addi	a0,a0,-398 # ffffffffc0201e58 <buddy_pmm_manager+0x140>
}
ffffffffc0200fee:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200ff0:	960ff06f          	j	ffffffffc0200150 <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0200ff4:	c8000637          	lui	a2,0xc8000
ffffffffc0200ff8:	bf25                	j	ffffffffc0200f30 <pmm_init+0x80>
    mem_begin = ROUNDUP(freemem, PGSIZE);
ffffffffc0200ffa:	6705                	lui	a4,0x1
ffffffffc0200ffc:	177d                	addi	a4,a4,-1
ffffffffc0200ffe:	96ba                	add	a3,a3,a4
ffffffffc0201000:	8efd                	and	a3,a3,a5
    return page->ref;
}

// 将物理地址转换为页结构指针
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc0201002:	00c6d793          	srli	a5,a3,0xc
ffffffffc0201006:	02c7f063          	bgeu	a5,a2,ffffffffc0201026 <pmm_init+0x176>
    pmm_manager->init_memmap(base, n);
ffffffffc020100a:	6010                	ld	a2,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc020100c:	fff80737          	lui	a4,0xfff80
ffffffffc0201010:	973e                	add	a4,a4,a5
ffffffffc0201012:	00271793          	slli	a5,a4,0x2
ffffffffc0201016:	97ba                	add	a5,a5,a4
ffffffffc0201018:	6a18                	ld	a4,16(a2)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
ffffffffc020101a:	8d95                	sub	a1,a1,a3
ffffffffc020101c:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc020101e:	81b1                	srli	a1,a1,0xc
ffffffffc0201020:	953e                	add	a0,a0,a5
ffffffffc0201022:	9702                	jalr	a4
}
ffffffffc0201024:	bfbd                	j	ffffffffc0200fa2 <pmm_init+0xf2>
        panic("pa2page called with invalid pa");
ffffffffc0201026:	00001617          	auipc	a2,0x1
ffffffffc020102a:	de260613          	addi	a2,a2,-542 # ffffffffc0201e08 <buddy_pmm_manager+0xf0>
ffffffffc020102e:	06a00593          	li	a1,106
ffffffffc0201032:	00001517          	auipc	a0,0x1
ffffffffc0201036:	df650513          	addi	a0,a0,-522 # ffffffffc0201e28 <buddy_pmm_manager+0x110>
ffffffffc020103a:	98cff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc020103e:	00001617          	auipc	a2,0x1
ffffffffc0201042:	da260613          	addi	a2,a2,-606 # ffffffffc0201de0 <buddy_pmm_manager+0xc8>
ffffffffc0201046:	06200593          	li	a1,98
ffffffffc020104a:	00001517          	auipc	a0,0x1
ffffffffc020104e:	d3e50513          	addi	a0,a0,-706 # ffffffffc0201d88 <buddy_pmm_manager+0x70>
ffffffffc0201052:	974ff0ef          	jal	ra,ffffffffc02001c6 <__panic>
        panic("DTB memory info not available");
ffffffffc0201056:	00001617          	auipc	a2,0x1
ffffffffc020105a:	d1260613          	addi	a2,a2,-750 # ffffffffc0201d68 <buddy_pmm_manager+0x50>
ffffffffc020105e:	04a00593          	li	a1,74
ffffffffc0201062:	00001517          	auipc	a0,0x1
ffffffffc0201066:	d2650513          	addi	a0,a0,-730 # ffffffffc0201d88 <buddy_pmm_manager+0x70>
ffffffffc020106a:	95cff0ef          	jal	ra,ffffffffc02001c6 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc020106e:	86ae                	mv	a3,a1
ffffffffc0201070:	00001617          	auipc	a2,0x1
ffffffffc0201074:	d7060613          	addi	a2,a2,-656 # ffffffffc0201de0 <buddy_pmm_manager+0xc8>
ffffffffc0201078:	07e00593          	li	a1,126
ffffffffc020107c:	00001517          	auipc	a0,0x1
ffffffffc0201080:	d0c50513          	addi	a0,a0,-756 # ffffffffc0201d88 <buddy_pmm_manager+0x70>
ffffffffc0201084:	942ff0ef          	jal	ra,ffffffffc02001c6 <__panic>

ffffffffc0201088 <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc0201088:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc020108c:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc020108e:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201092:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc0201094:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201098:	f022                	sd	s0,32(sp)
ffffffffc020109a:	ec26                	sd	s1,24(sp)
ffffffffc020109c:	e84a                	sd	s2,16(sp)
ffffffffc020109e:	f406                	sd	ra,40(sp)
ffffffffc02010a0:	e44e                	sd	s3,8(sp)
ffffffffc02010a2:	84aa                	mv	s1,a0
ffffffffc02010a4:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc02010a6:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc02010aa:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc02010ac:	03067e63          	bgeu	a2,a6,ffffffffc02010e8 <printnum+0x60>
ffffffffc02010b0:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc02010b2:	00805763          	blez	s0,ffffffffc02010c0 <printnum+0x38>
ffffffffc02010b6:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc02010b8:	85ca                	mv	a1,s2
ffffffffc02010ba:	854e                	mv	a0,s3
ffffffffc02010bc:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc02010be:	fc65                	bnez	s0,ffffffffc02010b6 <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02010c0:	1a02                	slli	s4,s4,0x20
ffffffffc02010c2:	00001797          	auipc	a5,0x1
ffffffffc02010c6:	dd678793          	addi	a5,a5,-554 # ffffffffc0201e98 <buddy_pmm_manager+0x180>
ffffffffc02010ca:	020a5a13          	srli	s4,s4,0x20
ffffffffc02010ce:	9a3e                	add	s4,s4,a5
}
ffffffffc02010d0:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02010d2:	000a4503          	lbu	a0,0(s4)
}
ffffffffc02010d6:	70a2                	ld	ra,40(sp)
ffffffffc02010d8:	69a2                	ld	s3,8(sp)
ffffffffc02010da:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02010dc:	85ca                	mv	a1,s2
ffffffffc02010de:	87a6                	mv	a5,s1
}
ffffffffc02010e0:	6942                	ld	s2,16(sp)
ffffffffc02010e2:	64e2                	ld	s1,24(sp)
ffffffffc02010e4:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02010e6:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc02010e8:	03065633          	divu	a2,a2,a6
ffffffffc02010ec:	8722                	mv	a4,s0
ffffffffc02010ee:	f9bff0ef          	jal	ra,ffffffffc0201088 <printnum>
ffffffffc02010f2:	b7f9                	j	ffffffffc02010c0 <printnum+0x38>

ffffffffc02010f4 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc02010f4:	7119                	addi	sp,sp,-128
ffffffffc02010f6:	f4a6                	sd	s1,104(sp)
ffffffffc02010f8:	f0ca                	sd	s2,96(sp)
ffffffffc02010fa:	ecce                	sd	s3,88(sp)
ffffffffc02010fc:	e8d2                	sd	s4,80(sp)
ffffffffc02010fe:	e4d6                	sd	s5,72(sp)
ffffffffc0201100:	e0da                	sd	s6,64(sp)
ffffffffc0201102:	fc5e                	sd	s7,56(sp)
ffffffffc0201104:	f06a                	sd	s10,32(sp)
ffffffffc0201106:	fc86                	sd	ra,120(sp)
ffffffffc0201108:	f8a2                	sd	s0,112(sp)
ffffffffc020110a:	f862                	sd	s8,48(sp)
ffffffffc020110c:	f466                	sd	s9,40(sp)
ffffffffc020110e:	ec6e                	sd	s11,24(sp)
ffffffffc0201110:	892a                	mv	s2,a0
ffffffffc0201112:	84ae                	mv	s1,a1
ffffffffc0201114:	8d32                	mv	s10,a2
ffffffffc0201116:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201118:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc020111c:	5b7d                	li	s6,-1
ffffffffc020111e:	00001a97          	auipc	s5,0x1
ffffffffc0201122:	daea8a93          	addi	s5,s5,-594 # ffffffffc0201ecc <buddy_pmm_manager+0x1b4>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201126:	00001b97          	auipc	s7,0x1
ffffffffc020112a:	f82b8b93          	addi	s7,s7,-126 # ffffffffc02020a8 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020112e:	000d4503          	lbu	a0,0(s10)
ffffffffc0201132:	001d0413          	addi	s0,s10,1
ffffffffc0201136:	01350a63          	beq	a0,s3,ffffffffc020114a <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc020113a:	c121                	beqz	a0,ffffffffc020117a <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc020113c:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020113e:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc0201140:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201142:	fff44503          	lbu	a0,-1(s0)
ffffffffc0201146:	ff351ae3          	bne	a0,s3,ffffffffc020113a <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020114a:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc020114e:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc0201152:	4c81                	li	s9,0
ffffffffc0201154:	4881                	li	a7,0
        width = precision = -1;
ffffffffc0201156:	5c7d                	li	s8,-1
ffffffffc0201158:	5dfd                	li	s11,-1
ffffffffc020115a:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc020115e:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201160:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201164:	0ff5f593          	zext.b	a1,a1
ffffffffc0201168:	00140d13          	addi	s10,s0,1
ffffffffc020116c:	04b56263          	bltu	a0,a1,ffffffffc02011b0 <vprintfmt+0xbc>
ffffffffc0201170:	058a                	slli	a1,a1,0x2
ffffffffc0201172:	95d6                	add	a1,a1,s5
ffffffffc0201174:	4194                	lw	a3,0(a1)
ffffffffc0201176:	96d6                	add	a3,a3,s5
ffffffffc0201178:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc020117a:	70e6                	ld	ra,120(sp)
ffffffffc020117c:	7446                	ld	s0,112(sp)
ffffffffc020117e:	74a6                	ld	s1,104(sp)
ffffffffc0201180:	7906                	ld	s2,96(sp)
ffffffffc0201182:	69e6                	ld	s3,88(sp)
ffffffffc0201184:	6a46                	ld	s4,80(sp)
ffffffffc0201186:	6aa6                	ld	s5,72(sp)
ffffffffc0201188:	6b06                	ld	s6,64(sp)
ffffffffc020118a:	7be2                	ld	s7,56(sp)
ffffffffc020118c:	7c42                	ld	s8,48(sp)
ffffffffc020118e:	7ca2                	ld	s9,40(sp)
ffffffffc0201190:	7d02                	ld	s10,32(sp)
ffffffffc0201192:	6de2                	ld	s11,24(sp)
ffffffffc0201194:	6109                	addi	sp,sp,128
ffffffffc0201196:	8082                	ret
            padc = '0';
ffffffffc0201198:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc020119a:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020119e:	846a                	mv	s0,s10
ffffffffc02011a0:	00140d13          	addi	s10,s0,1
ffffffffc02011a4:	fdd6059b          	addiw	a1,a2,-35
ffffffffc02011a8:	0ff5f593          	zext.b	a1,a1
ffffffffc02011ac:	fcb572e3          	bgeu	a0,a1,ffffffffc0201170 <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc02011b0:	85a6                	mv	a1,s1
ffffffffc02011b2:	02500513          	li	a0,37
ffffffffc02011b6:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc02011b8:	fff44783          	lbu	a5,-1(s0)
ffffffffc02011bc:	8d22                	mv	s10,s0
ffffffffc02011be:	f73788e3          	beq	a5,s3,ffffffffc020112e <vprintfmt+0x3a>
ffffffffc02011c2:	ffed4783          	lbu	a5,-2(s10)
ffffffffc02011c6:	1d7d                	addi	s10,s10,-1
ffffffffc02011c8:	ff379de3          	bne	a5,s3,ffffffffc02011c2 <vprintfmt+0xce>
ffffffffc02011cc:	b78d                	j	ffffffffc020112e <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc02011ce:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc02011d2:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02011d6:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc02011d8:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc02011dc:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc02011e0:	02d86463          	bltu	a6,a3,ffffffffc0201208 <vprintfmt+0x114>
                ch = *fmt;
ffffffffc02011e4:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc02011e8:	002c169b          	slliw	a3,s8,0x2
ffffffffc02011ec:	0186873b          	addw	a4,a3,s8
ffffffffc02011f0:	0017171b          	slliw	a4,a4,0x1
ffffffffc02011f4:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc02011f6:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc02011fa:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc02011fc:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc0201200:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201204:	fed870e3          	bgeu	a6,a3,ffffffffc02011e4 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc0201208:	f40ddce3          	bgez	s11,ffffffffc0201160 <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc020120c:	8de2                	mv	s11,s8
ffffffffc020120e:	5c7d                	li	s8,-1
ffffffffc0201210:	bf81                	j	ffffffffc0201160 <vprintfmt+0x6c>
            if (width < 0)
ffffffffc0201212:	fffdc693          	not	a3,s11
ffffffffc0201216:	96fd                	srai	a3,a3,0x3f
ffffffffc0201218:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020121c:	00144603          	lbu	a2,1(s0)
ffffffffc0201220:	2d81                	sext.w	s11,s11
ffffffffc0201222:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201224:	bf35                	j	ffffffffc0201160 <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc0201226:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020122a:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc020122e:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201230:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc0201232:	bfd9                	j	ffffffffc0201208 <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0201234:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201236:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc020123a:	01174463          	blt	a4,a7,ffffffffc0201242 <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc020123e:	1a088e63          	beqz	a7,ffffffffc02013fa <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc0201242:	000a3603          	ld	a2,0(s4)
ffffffffc0201246:	46c1                	li	a3,16
ffffffffc0201248:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc020124a:	2781                	sext.w	a5,a5
ffffffffc020124c:	876e                	mv	a4,s11
ffffffffc020124e:	85a6                	mv	a1,s1
ffffffffc0201250:	854a                	mv	a0,s2
ffffffffc0201252:	e37ff0ef          	jal	ra,ffffffffc0201088 <printnum>
            break;
ffffffffc0201256:	bde1                	j	ffffffffc020112e <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc0201258:	000a2503          	lw	a0,0(s4)
ffffffffc020125c:	85a6                	mv	a1,s1
ffffffffc020125e:	0a21                	addi	s4,s4,8
ffffffffc0201260:	9902                	jalr	s2
            break;
ffffffffc0201262:	b5f1                	j	ffffffffc020112e <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201264:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201266:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc020126a:	01174463          	blt	a4,a7,ffffffffc0201272 <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc020126e:	18088163          	beqz	a7,ffffffffc02013f0 <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc0201272:	000a3603          	ld	a2,0(s4)
ffffffffc0201276:	46a9                	li	a3,10
ffffffffc0201278:	8a2e                	mv	s4,a1
ffffffffc020127a:	bfc1                	j	ffffffffc020124a <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020127c:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc0201280:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201282:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201284:	bdf1                	j	ffffffffc0201160 <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc0201286:	85a6                	mv	a1,s1
ffffffffc0201288:	02500513          	li	a0,37
ffffffffc020128c:	9902                	jalr	s2
            break;
ffffffffc020128e:	b545                	j	ffffffffc020112e <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201290:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc0201294:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201296:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201298:	b5e1                	j	ffffffffc0201160 <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc020129a:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc020129c:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02012a0:	01174463          	blt	a4,a7,ffffffffc02012a8 <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc02012a4:	14088163          	beqz	a7,ffffffffc02013e6 <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc02012a8:	000a3603          	ld	a2,0(s4)
ffffffffc02012ac:	46a1                	li	a3,8
ffffffffc02012ae:	8a2e                	mv	s4,a1
ffffffffc02012b0:	bf69                	j	ffffffffc020124a <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc02012b2:	03000513          	li	a0,48
ffffffffc02012b6:	85a6                	mv	a1,s1
ffffffffc02012b8:	e03e                	sd	a5,0(sp)
ffffffffc02012ba:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc02012bc:	85a6                	mv	a1,s1
ffffffffc02012be:	07800513          	li	a0,120
ffffffffc02012c2:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02012c4:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc02012c6:	6782                	ld	a5,0(sp)
ffffffffc02012c8:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02012ca:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc02012ce:	bfb5                	j	ffffffffc020124a <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc02012d0:	000a3403          	ld	s0,0(s4)
ffffffffc02012d4:	008a0713          	addi	a4,s4,8
ffffffffc02012d8:	e03a                	sd	a4,0(sp)
ffffffffc02012da:	14040263          	beqz	s0,ffffffffc020141e <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc02012de:	0fb05763          	blez	s11,ffffffffc02013cc <vprintfmt+0x2d8>
ffffffffc02012e2:	02d00693          	li	a3,45
ffffffffc02012e6:	0cd79163          	bne	a5,a3,ffffffffc02013a8 <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02012ea:	00044783          	lbu	a5,0(s0)
ffffffffc02012ee:	0007851b          	sext.w	a0,a5
ffffffffc02012f2:	cf85                	beqz	a5,ffffffffc020132a <vprintfmt+0x236>
ffffffffc02012f4:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02012f8:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02012fc:	000c4563          	bltz	s8,ffffffffc0201306 <vprintfmt+0x212>
ffffffffc0201300:	3c7d                	addiw	s8,s8,-1
ffffffffc0201302:	036c0263          	beq	s8,s6,ffffffffc0201326 <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc0201306:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201308:	0e0c8e63          	beqz	s9,ffffffffc0201404 <vprintfmt+0x310>
ffffffffc020130c:	3781                	addiw	a5,a5,-32
ffffffffc020130e:	0ef47b63          	bgeu	s0,a5,ffffffffc0201404 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc0201312:	03f00513          	li	a0,63
ffffffffc0201316:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201318:	000a4783          	lbu	a5,0(s4)
ffffffffc020131c:	3dfd                	addiw	s11,s11,-1
ffffffffc020131e:	0a05                	addi	s4,s4,1
ffffffffc0201320:	0007851b          	sext.w	a0,a5
ffffffffc0201324:	ffe1                	bnez	a5,ffffffffc02012fc <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc0201326:	01b05963          	blez	s11,ffffffffc0201338 <vprintfmt+0x244>
ffffffffc020132a:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc020132c:	85a6                	mv	a1,s1
ffffffffc020132e:	02000513          	li	a0,32
ffffffffc0201332:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0201334:	fe0d9be3          	bnez	s11,ffffffffc020132a <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201338:	6a02                	ld	s4,0(sp)
ffffffffc020133a:	bbd5                	j	ffffffffc020112e <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc020133c:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc020133e:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc0201342:	01174463          	blt	a4,a7,ffffffffc020134a <vprintfmt+0x256>
    else if (lflag) {
ffffffffc0201346:	08088d63          	beqz	a7,ffffffffc02013e0 <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc020134a:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc020134e:	0a044d63          	bltz	s0,ffffffffc0201408 <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc0201352:	8622                	mv	a2,s0
ffffffffc0201354:	8a66                	mv	s4,s9
ffffffffc0201356:	46a9                	li	a3,10
ffffffffc0201358:	bdcd                	j	ffffffffc020124a <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc020135a:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc020135e:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc0201360:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc0201362:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc0201366:	8fb5                	xor	a5,a5,a3
ffffffffc0201368:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc020136c:	02d74163          	blt	a4,a3,ffffffffc020138e <vprintfmt+0x29a>
ffffffffc0201370:	00369793          	slli	a5,a3,0x3
ffffffffc0201374:	97de                	add	a5,a5,s7
ffffffffc0201376:	639c                	ld	a5,0(a5)
ffffffffc0201378:	cb99                	beqz	a5,ffffffffc020138e <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc020137a:	86be                	mv	a3,a5
ffffffffc020137c:	00001617          	auipc	a2,0x1
ffffffffc0201380:	b4c60613          	addi	a2,a2,-1204 # ffffffffc0201ec8 <buddy_pmm_manager+0x1b0>
ffffffffc0201384:	85a6                	mv	a1,s1
ffffffffc0201386:	854a                	mv	a0,s2
ffffffffc0201388:	0ce000ef          	jal	ra,ffffffffc0201456 <printfmt>
ffffffffc020138c:	b34d                	j	ffffffffc020112e <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc020138e:	00001617          	auipc	a2,0x1
ffffffffc0201392:	b2a60613          	addi	a2,a2,-1238 # ffffffffc0201eb8 <buddy_pmm_manager+0x1a0>
ffffffffc0201396:	85a6                	mv	a1,s1
ffffffffc0201398:	854a                	mv	a0,s2
ffffffffc020139a:	0bc000ef          	jal	ra,ffffffffc0201456 <printfmt>
ffffffffc020139e:	bb41                	j	ffffffffc020112e <vprintfmt+0x3a>
                p = "(null)";
ffffffffc02013a0:	00001417          	auipc	s0,0x1
ffffffffc02013a4:	b1040413          	addi	s0,s0,-1264 # ffffffffc0201eb0 <buddy_pmm_manager+0x198>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02013a8:	85e2                	mv	a1,s8
ffffffffc02013aa:	8522                	mv	a0,s0
ffffffffc02013ac:	e43e                	sd	a5,8(sp)
ffffffffc02013ae:	0fc000ef          	jal	ra,ffffffffc02014aa <strnlen>
ffffffffc02013b2:	40ad8dbb          	subw	s11,s11,a0
ffffffffc02013b6:	01b05b63          	blez	s11,ffffffffc02013cc <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc02013ba:	67a2                	ld	a5,8(sp)
ffffffffc02013bc:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02013c0:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc02013c2:	85a6                	mv	a1,s1
ffffffffc02013c4:	8552                	mv	a0,s4
ffffffffc02013c6:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02013c8:	fe0d9ce3          	bnez	s11,ffffffffc02013c0 <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02013cc:	00044783          	lbu	a5,0(s0)
ffffffffc02013d0:	00140a13          	addi	s4,s0,1
ffffffffc02013d4:	0007851b          	sext.w	a0,a5
ffffffffc02013d8:	d3a5                	beqz	a5,ffffffffc0201338 <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02013da:	05e00413          	li	s0,94
ffffffffc02013de:	bf39                	j	ffffffffc02012fc <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc02013e0:	000a2403          	lw	s0,0(s4)
ffffffffc02013e4:	b7ad                	j	ffffffffc020134e <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc02013e6:	000a6603          	lwu	a2,0(s4)
ffffffffc02013ea:	46a1                	li	a3,8
ffffffffc02013ec:	8a2e                	mv	s4,a1
ffffffffc02013ee:	bdb1                	j	ffffffffc020124a <vprintfmt+0x156>
ffffffffc02013f0:	000a6603          	lwu	a2,0(s4)
ffffffffc02013f4:	46a9                	li	a3,10
ffffffffc02013f6:	8a2e                	mv	s4,a1
ffffffffc02013f8:	bd89                	j	ffffffffc020124a <vprintfmt+0x156>
ffffffffc02013fa:	000a6603          	lwu	a2,0(s4)
ffffffffc02013fe:	46c1                	li	a3,16
ffffffffc0201400:	8a2e                	mv	s4,a1
ffffffffc0201402:	b5a1                	j	ffffffffc020124a <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc0201404:	9902                	jalr	s2
ffffffffc0201406:	bf09                	j	ffffffffc0201318 <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc0201408:	85a6                	mv	a1,s1
ffffffffc020140a:	02d00513          	li	a0,45
ffffffffc020140e:	e03e                	sd	a5,0(sp)
ffffffffc0201410:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc0201412:	6782                	ld	a5,0(sp)
ffffffffc0201414:	8a66                	mv	s4,s9
ffffffffc0201416:	40800633          	neg	a2,s0
ffffffffc020141a:	46a9                	li	a3,10
ffffffffc020141c:	b53d                	j	ffffffffc020124a <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc020141e:	03b05163          	blez	s11,ffffffffc0201440 <vprintfmt+0x34c>
ffffffffc0201422:	02d00693          	li	a3,45
ffffffffc0201426:	f6d79de3          	bne	a5,a3,ffffffffc02013a0 <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc020142a:	00001417          	auipc	s0,0x1
ffffffffc020142e:	a8640413          	addi	s0,s0,-1402 # ffffffffc0201eb0 <buddy_pmm_manager+0x198>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201432:	02800793          	li	a5,40
ffffffffc0201436:	02800513          	li	a0,40
ffffffffc020143a:	00140a13          	addi	s4,s0,1
ffffffffc020143e:	bd6d                	j	ffffffffc02012f8 <vprintfmt+0x204>
ffffffffc0201440:	00001a17          	auipc	s4,0x1
ffffffffc0201444:	a71a0a13          	addi	s4,s4,-1423 # ffffffffc0201eb1 <buddy_pmm_manager+0x199>
ffffffffc0201448:	02800513          	li	a0,40
ffffffffc020144c:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201450:	05e00413          	li	s0,94
ffffffffc0201454:	b565                	j	ffffffffc02012fc <vprintfmt+0x208>

ffffffffc0201456 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201456:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc0201458:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc020145c:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc020145e:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201460:	ec06                	sd	ra,24(sp)
ffffffffc0201462:	f83a                	sd	a4,48(sp)
ffffffffc0201464:	fc3e                	sd	a5,56(sp)
ffffffffc0201466:	e0c2                	sd	a6,64(sp)
ffffffffc0201468:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc020146a:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc020146c:	c89ff0ef          	jal	ra,ffffffffc02010f4 <vprintfmt>
}
ffffffffc0201470:	60e2                	ld	ra,24(sp)
ffffffffc0201472:	6161                	addi	sp,sp,80
ffffffffc0201474:	8082                	ret

ffffffffc0201476 <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc0201476:	4781                	li	a5,0
ffffffffc0201478:	00005717          	auipc	a4,0x5
ffffffffc020147c:	b9873703          	ld	a4,-1128(a4) # ffffffffc0206010 <SBI_CONSOLE_PUTCHAR>
ffffffffc0201480:	88ba                	mv	a7,a4
ffffffffc0201482:	852a                	mv	a0,a0
ffffffffc0201484:	85be                	mv	a1,a5
ffffffffc0201486:	863e                	mv	a2,a5
ffffffffc0201488:	00000073          	ecall
ffffffffc020148c:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc020148e:	8082                	ret

ffffffffc0201490 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc0201490:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc0201494:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc0201496:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc0201498:	cb81                	beqz	a5,ffffffffc02014a8 <strlen+0x18>
        cnt ++;
ffffffffc020149a:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc020149c:	00a707b3          	add	a5,a4,a0
ffffffffc02014a0:	0007c783          	lbu	a5,0(a5)
ffffffffc02014a4:	fbfd                	bnez	a5,ffffffffc020149a <strlen+0xa>
ffffffffc02014a6:	8082                	ret
    }
    return cnt;
}
ffffffffc02014a8:	8082                	ret

ffffffffc02014aa <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc02014aa:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc02014ac:	e589                	bnez	a1,ffffffffc02014b6 <strnlen+0xc>
ffffffffc02014ae:	a811                	j	ffffffffc02014c2 <strnlen+0x18>
        cnt ++;
ffffffffc02014b0:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc02014b2:	00f58863          	beq	a1,a5,ffffffffc02014c2 <strnlen+0x18>
ffffffffc02014b6:	00f50733          	add	a4,a0,a5
ffffffffc02014ba:	00074703          	lbu	a4,0(a4)
ffffffffc02014be:	fb6d                	bnez	a4,ffffffffc02014b0 <strnlen+0x6>
ffffffffc02014c0:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc02014c2:	852e                	mv	a0,a1
ffffffffc02014c4:	8082                	ret

ffffffffc02014c6 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02014c6:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02014ca:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02014ce:	cb89                	beqz	a5,ffffffffc02014e0 <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc02014d0:	0505                	addi	a0,a0,1
ffffffffc02014d2:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02014d4:	fee789e3          	beq	a5,a4,ffffffffc02014c6 <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02014d8:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc02014dc:	9d19                	subw	a0,a0,a4
ffffffffc02014de:	8082                	ret
ffffffffc02014e0:	4501                	li	a0,0
ffffffffc02014e2:	bfed                	j	ffffffffc02014dc <strcmp+0x16>

ffffffffc02014e4 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc02014e4:	c20d                	beqz	a2,ffffffffc0201506 <strncmp+0x22>
ffffffffc02014e6:	962e                	add	a2,a2,a1
ffffffffc02014e8:	a031                	j	ffffffffc02014f4 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc02014ea:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc02014ec:	00e79a63          	bne	a5,a4,ffffffffc0201500 <strncmp+0x1c>
ffffffffc02014f0:	00b60b63          	beq	a2,a1,ffffffffc0201506 <strncmp+0x22>
ffffffffc02014f4:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc02014f8:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc02014fa:	fff5c703          	lbu	a4,-1(a1)
ffffffffc02014fe:	f7f5                	bnez	a5,ffffffffc02014ea <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201500:	40e7853b          	subw	a0,a5,a4
}
ffffffffc0201504:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201506:	4501                	li	a0,0
ffffffffc0201508:	8082                	ret

ffffffffc020150a <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc020150a:	ca01                	beqz	a2,ffffffffc020151a <memset+0x10>
ffffffffc020150c:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc020150e:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc0201510:	0785                	addi	a5,a5,1
ffffffffc0201512:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc0201516:	fec79de3          	bne	a5,a2,ffffffffc0201510 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc020151a:	8082                	ret
