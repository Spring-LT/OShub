
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid
ffffffffc0200000:	00007297          	auipc	t0,0x7
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0207000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00007297          	auipc	t0,0x7
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0207008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02062b7          	lui	t0,0xc0206
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0206137          	lui	sp,0xc0206

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 1. 使用临时寄存器 t1 计算栈顶的精确地址
    lui t1, %hi(bootstacktop)
ffffffffc0200040:	c0206337          	lui	t1,0xc0206
    addi t1, t1, %lo(bootstacktop)
ffffffffc0200044:	00030313          	mv	t1,t1
    # 2. 将精确地址一次性地、安全地传给 sp
    mv sp, t1
ffffffffc0200048:	811a                	mv	sp,t1
    # 现在栈指针已经完美设置，可以安全地调用任何C函数了
    # 然后跳转到 kern_init (不再返回)
    lui t0, %hi(kern_init)
ffffffffc020004a:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc020004e:	05428293          	addi	t0,t0,84 # ffffffffc0200054 <kern_init>
    jr t0
ffffffffc0200052:	8282                	jr	t0

ffffffffc0200054 <kern_init>:
void grade_backtrace(void);

int kern_init(void) {
    extern char edata[], end[];
    // 先清零 BSS，再读取并保存 DTB 的内存信息，避免被清零覆盖（为了解释变化 正式上传时我觉得应该删去这句话）
    memset(edata, 0, end - edata);
ffffffffc0200054:	00007517          	auipc	a0,0x7
ffffffffc0200058:	fd450513          	addi	a0,a0,-44 # ffffffffc0207028 <free_area>
ffffffffc020005c:	00007617          	auipc	a2,0x7
ffffffffc0200060:	44460613          	addi	a2,a2,1092 # ffffffffc02074a0 <end>
int kern_init(void) {
ffffffffc0200064:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc0200066:	8e09                	sub	a2,a2,a0
ffffffffc0200068:	4581                	li	a1,0
int kern_init(void) {
ffffffffc020006a:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc020006c:	747010ef          	jal	ra,ffffffffc0201fb2 <memset>
    dtb_init();
ffffffffc0200070:	42c000ef          	jal	ra,ffffffffc020049c <dtb_init>
    cons_init();  // init the console
ffffffffc0200074:	41a000ef          	jal	ra,ffffffffc020048e <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc0200078:	00002517          	auipc	a0,0x2
ffffffffc020007c:	fb050513          	addi	a0,a0,-80 # ffffffffc0202028 <etext+0x64>
ffffffffc0200080:	0ae000ef          	jal	ra,ffffffffc020012e <cputs>

    print_kerninfo();
ffffffffc0200084:	0fa000ef          	jal	ra,ffffffffc020017e <print_kerninfo>

    // grade_backtrace();
    idt_init();  // init interrupt descriptor table 第一次中断初始化
ffffffffc0200088:	7d0000ef          	jal	ra,ffffffffc0200858 <idt_init>

    pmm_init();  // init physical memory management 内存管理初始化
ffffffffc020008c:	7aa010ef          	jal	ra,ffffffffc0201836 <pmm_init>

    idt_init();  // init interrupt descriptor table 第二次中断初始化
ffffffffc0200090:	7c8000ef          	jal	ra,ffffffffc0200858 <idt_init>

    clock_init();   // init clock interrupt 设置时钟中断和定时器
ffffffffc0200094:	3b8000ef          	jal	ra,ffffffffc020044c <clock_init>
    intr_enable();  // enable irq interrupt 全局启用系统中断
ffffffffc0200098:	7b4000ef          	jal	ra,ffffffffc020084c <intr_enable>

    /* 触发异常进行测试 - 可以注释掉以禁用异常测试 */
    // 触发断点异常 (ebreak指令)
    cprintf("\n--- 开始测试断点异常 ---\n");
ffffffffc020009c:	00002517          	auipc	a0,0x2
ffffffffc02000a0:	f2c50513          	addi	a0,a0,-212 # ffffffffc0201fc8 <etext+0x4>
ffffffffc02000a4:	052000ef          	jal	ra,ffffffffc02000f6 <cprintf>
    asm volatile ("ebreak");
ffffffffc02000a8:	9002                	ebreak
    cprintf("--- 断点异常测试完成，程序继续执行 --\n\n");
ffffffffc02000aa:	00002517          	auipc	a0,0x2
ffffffffc02000ae:	f4650513          	addi	a0,a0,-186 # ffffffffc0201ff0 <etext+0x2c>
ffffffffc02000b2:	044000ef          	jal	ra,ffffffffc02000f6 <cprintf>
ffffffffc02000b6:	deadbeef          	jal	t4,ffffffffc01db6a0 <kern_entry-0x24960>
    //cprintf("\n--- 开始测试非法指令异常 ---\n");
    asm volatile (".word 0xdeadbeef");  // 这是一个非法指令
    //cprintf("--- 非法指令异常测试完成，程序继续执行 --\n\n");
    
    /* do nothing */
    while (1)
ffffffffc02000ba:	a001                	j	ffffffffc02000ba <kern_init+0x66>

ffffffffc02000bc <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc02000bc:	1141                	addi	sp,sp,-16
ffffffffc02000be:	e022                	sd	s0,0(sp)
ffffffffc02000c0:	e406                	sd	ra,8(sp)
ffffffffc02000c2:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc02000c4:	3cc000ef          	jal	ra,ffffffffc0200490 <cons_putc>
    (*cnt) ++;
ffffffffc02000c8:	401c                	lw	a5,0(s0)
}
ffffffffc02000ca:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc02000cc:	2785                	addiw	a5,a5,1
ffffffffc02000ce:	c01c                	sw	a5,0(s0)
}
ffffffffc02000d0:	6402                	ld	s0,0(sp)
ffffffffc02000d2:	0141                	addi	sp,sp,16
ffffffffc02000d4:	8082                	ret

ffffffffc02000d6 <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc02000d6:	1101                	addi	sp,sp,-32
ffffffffc02000d8:	862a                	mv	a2,a0
ffffffffc02000da:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc02000dc:	00000517          	auipc	a0,0x0
ffffffffc02000e0:	fe050513          	addi	a0,a0,-32 # ffffffffc02000bc <cputch>
ffffffffc02000e4:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc02000e6:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc02000e8:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc02000ea:	199010ef          	jal	ra,ffffffffc0201a82 <vprintfmt>
    return cnt;
}
ffffffffc02000ee:	60e2                	ld	ra,24(sp)
ffffffffc02000f0:	4532                	lw	a0,12(sp)
ffffffffc02000f2:	6105                	addi	sp,sp,32
ffffffffc02000f4:	8082                	ret

ffffffffc02000f6 <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc02000f6:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc02000f8:	02810313          	addi	t1,sp,40 # ffffffffc0206028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc02000fc:	8e2a                	mv	t3,a0
ffffffffc02000fe:	f42e                	sd	a1,40(sp)
ffffffffc0200100:	f832                	sd	a2,48(sp)
ffffffffc0200102:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200104:	00000517          	auipc	a0,0x0
ffffffffc0200108:	fb850513          	addi	a0,a0,-72 # ffffffffc02000bc <cputch>
ffffffffc020010c:	004c                	addi	a1,sp,4
ffffffffc020010e:	869a                	mv	a3,t1
ffffffffc0200110:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc0200112:	ec06                	sd	ra,24(sp)
ffffffffc0200114:	e0ba                	sd	a4,64(sp)
ffffffffc0200116:	e4be                	sd	a5,72(sp)
ffffffffc0200118:	e8c2                	sd	a6,80(sp)
ffffffffc020011a:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc020011c:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc020011e:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200120:	163010ef          	jal	ra,ffffffffc0201a82 <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc0200124:	60e2                	ld	ra,24(sp)
ffffffffc0200126:	4512                	lw	a0,4(sp)
ffffffffc0200128:	6125                	addi	sp,sp,96
ffffffffc020012a:	8082                	ret

ffffffffc020012c <cputchar>:

/* cputchar - writes a single character to stdout */
void
cputchar(int c) {
    cons_putc(c);
ffffffffc020012c:	a695                	j	ffffffffc0200490 <cons_putc>

ffffffffc020012e <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc020012e:	1101                	addi	sp,sp,-32
ffffffffc0200130:	e822                	sd	s0,16(sp)
ffffffffc0200132:	ec06                	sd	ra,24(sp)
ffffffffc0200134:	e426                	sd	s1,8(sp)
ffffffffc0200136:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc0200138:	00054503          	lbu	a0,0(a0)
ffffffffc020013c:	c51d                	beqz	a0,ffffffffc020016a <cputs+0x3c>
ffffffffc020013e:	0405                	addi	s0,s0,1
ffffffffc0200140:	4485                	li	s1,1
ffffffffc0200142:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc0200144:	34c000ef          	jal	ra,ffffffffc0200490 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc0200148:	00044503          	lbu	a0,0(s0)
ffffffffc020014c:	008487bb          	addw	a5,s1,s0
ffffffffc0200150:	0405                	addi	s0,s0,1
ffffffffc0200152:	f96d                	bnez	a0,ffffffffc0200144 <cputs+0x16>
    (*cnt) ++;
ffffffffc0200154:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc0200158:	4529                	li	a0,10
ffffffffc020015a:	336000ef          	jal	ra,ffffffffc0200490 <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc020015e:	60e2                	ld	ra,24(sp)
ffffffffc0200160:	8522                	mv	a0,s0
ffffffffc0200162:	6442                	ld	s0,16(sp)
ffffffffc0200164:	64a2                	ld	s1,8(sp)
ffffffffc0200166:	6105                	addi	sp,sp,32
ffffffffc0200168:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc020016a:	4405                	li	s0,1
ffffffffc020016c:	b7f5                	j	ffffffffc0200158 <cputs+0x2a>

ffffffffc020016e <getchar>:

/* getchar - reads a single non-zero character from stdin */
int
getchar(void) {
ffffffffc020016e:	1141                	addi	sp,sp,-16
ffffffffc0200170:	e406                	sd	ra,8(sp)
    int c;
    while ((c = cons_getc()) == 0)
ffffffffc0200172:	326000ef          	jal	ra,ffffffffc0200498 <cons_getc>
ffffffffc0200176:	dd75                	beqz	a0,ffffffffc0200172 <getchar+0x4>
        /* do nothing */;
    return c;
}
ffffffffc0200178:	60a2                	ld	ra,8(sp)
ffffffffc020017a:	0141                	addi	sp,sp,16
ffffffffc020017c:	8082                	ret

ffffffffc020017e <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc020017e:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[], kern_init[];
    cprintf("Special kernel symbols:\n");
ffffffffc0200180:	00002517          	auipc	a0,0x2
ffffffffc0200184:	ec850513          	addi	a0,a0,-312 # ffffffffc0202048 <etext+0x84>
void print_kerninfo(void) {
ffffffffc0200188:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc020018a:	f6dff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", kern_init);
ffffffffc020018e:	00000597          	auipc	a1,0x0
ffffffffc0200192:	ec658593          	addi	a1,a1,-314 # ffffffffc0200054 <kern_init>
ffffffffc0200196:	00002517          	auipc	a0,0x2
ffffffffc020019a:	ed250513          	addi	a0,a0,-302 # ffffffffc0202068 <etext+0xa4>
ffffffffc020019e:	f59ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc02001a2:	00002597          	auipc	a1,0x2
ffffffffc02001a6:	e2258593          	addi	a1,a1,-478 # ffffffffc0201fc4 <etext>
ffffffffc02001aa:	00002517          	auipc	a0,0x2
ffffffffc02001ae:	ede50513          	addi	a0,a0,-290 # ffffffffc0202088 <etext+0xc4>
ffffffffc02001b2:	f45ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc02001b6:	00007597          	auipc	a1,0x7
ffffffffc02001ba:	e7258593          	addi	a1,a1,-398 # ffffffffc0207028 <free_area>
ffffffffc02001be:	00002517          	auipc	a0,0x2
ffffffffc02001c2:	eea50513          	addi	a0,a0,-278 # ffffffffc02020a8 <etext+0xe4>
ffffffffc02001c6:	f31ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc02001ca:	00007597          	auipc	a1,0x7
ffffffffc02001ce:	2d658593          	addi	a1,a1,726 # ffffffffc02074a0 <end>
ffffffffc02001d2:	00002517          	auipc	a0,0x2
ffffffffc02001d6:	ef650513          	addi	a0,a0,-266 # ffffffffc02020c8 <etext+0x104>
ffffffffc02001da:	f1dff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - kern_init + 1023) / 1024);
ffffffffc02001de:	00007597          	auipc	a1,0x7
ffffffffc02001e2:	6c158593          	addi	a1,a1,1729 # ffffffffc020789f <end+0x3ff>
ffffffffc02001e6:	00000797          	auipc	a5,0x0
ffffffffc02001ea:	e6e78793          	addi	a5,a5,-402 # ffffffffc0200054 <kern_init>
ffffffffc02001ee:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02001f2:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02001f6:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02001f8:	3ff5f593          	andi	a1,a1,1023
ffffffffc02001fc:	95be                	add	a1,a1,a5
ffffffffc02001fe:	85a9                	srai	a1,a1,0xa
ffffffffc0200200:	00002517          	auipc	a0,0x2
ffffffffc0200204:	ee850513          	addi	a0,a0,-280 # ffffffffc02020e8 <etext+0x124>
}
ffffffffc0200208:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc020020a:	b5f5                	j	ffffffffc02000f6 <cprintf>

ffffffffc020020c <print_stackframe>:
 * Note that, the length of ebp-chain is limited. In boot/bootasm.S, before
 * jumping
 * to the kernel entry, the value of ebp has been set to zero, that's the
 * boundary.
 * */
void print_stackframe(void) {
ffffffffc020020c:	1141                	addi	sp,sp,-16
    panic("Not Implemented!");
ffffffffc020020e:	00002617          	auipc	a2,0x2
ffffffffc0200212:	f0a60613          	addi	a2,a2,-246 # ffffffffc0202118 <etext+0x154>
ffffffffc0200216:	04d00593          	li	a1,77
ffffffffc020021a:	00002517          	auipc	a0,0x2
ffffffffc020021e:	f1650513          	addi	a0,a0,-234 # ffffffffc0202130 <etext+0x16c>
void print_stackframe(void) {
ffffffffc0200222:	e406                	sd	ra,8(sp)
    panic("Not Implemented!");
ffffffffc0200224:	1cc000ef          	jal	ra,ffffffffc02003f0 <__panic>

ffffffffc0200228 <mon_help>:
    }
}

/* mon_help - print the information about mon_* functions */
int
mon_help(int argc, char **argv, struct trapframe *tf) {
ffffffffc0200228:	1141                	addi	sp,sp,-16
    int i;
    for (i = 0; i < NCOMMANDS; i ++) {
        cprintf("%s - %s\n", commands[i].name, commands[i].desc);
ffffffffc020022a:	00002617          	auipc	a2,0x2
ffffffffc020022e:	f1e60613          	addi	a2,a2,-226 # ffffffffc0202148 <etext+0x184>
ffffffffc0200232:	00002597          	auipc	a1,0x2
ffffffffc0200236:	f3658593          	addi	a1,a1,-202 # ffffffffc0202168 <etext+0x1a4>
ffffffffc020023a:	00002517          	auipc	a0,0x2
ffffffffc020023e:	f3650513          	addi	a0,a0,-202 # ffffffffc0202170 <etext+0x1ac>
mon_help(int argc, char **argv, struct trapframe *tf) {
ffffffffc0200242:	e406                	sd	ra,8(sp)
        cprintf("%s - %s\n", commands[i].name, commands[i].desc);
ffffffffc0200244:	eb3ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
ffffffffc0200248:	00002617          	auipc	a2,0x2
ffffffffc020024c:	f3860613          	addi	a2,a2,-200 # ffffffffc0202180 <etext+0x1bc>
ffffffffc0200250:	00002597          	auipc	a1,0x2
ffffffffc0200254:	f5858593          	addi	a1,a1,-168 # ffffffffc02021a8 <etext+0x1e4>
ffffffffc0200258:	00002517          	auipc	a0,0x2
ffffffffc020025c:	f1850513          	addi	a0,a0,-232 # ffffffffc0202170 <etext+0x1ac>
ffffffffc0200260:	e97ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
ffffffffc0200264:	00002617          	auipc	a2,0x2
ffffffffc0200268:	f5460613          	addi	a2,a2,-172 # ffffffffc02021b8 <etext+0x1f4>
ffffffffc020026c:	00002597          	auipc	a1,0x2
ffffffffc0200270:	f6c58593          	addi	a1,a1,-148 # ffffffffc02021d8 <etext+0x214>
ffffffffc0200274:	00002517          	auipc	a0,0x2
ffffffffc0200278:	efc50513          	addi	a0,a0,-260 # ffffffffc0202170 <etext+0x1ac>
ffffffffc020027c:	e7bff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    }
    return 0;
}
ffffffffc0200280:	60a2                	ld	ra,8(sp)
ffffffffc0200282:	4501                	li	a0,0
ffffffffc0200284:	0141                	addi	sp,sp,16
ffffffffc0200286:	8082                	ret

ffffffffc0200288 <mon_kerninfo>:
/* *
 * mon_kerninfo - call print_kerninfo in kern/debug/kdebug.c to
 * print the memory occupancy in kernel.
 * */
int
mon_kerninfo(int argc, char **argv, struct trapframe *tf) {
ffffffffc0200288:	1141                	addi	sp,sp,-16
ffffffffc020028a:	e406                	sd	ra,8(sp)
    print_kerninfo();
ffffffffc020028c:	ef3ff0ef          	jal	ra,ffffffffc020017e <print_kerninfo>
    return 0;
}
ffffffffc0200290:	60a2                	ld	ra,8(sp)
ffffffffc0200292:	4501                	li	a0,0
ffffffffc0200294:	0141                	addi	sp,sp,16
ffffffffc0200296:	8082                	ret

ffffffffc0200298 <mon_backtrace>:
/* *
 * mon_backtrace - call print_stackframe in kern/debug/kdebug.c to
 * print a backtrace of the stack.
 * */
int
mon_backtrace(int argc, char **argv, struct trapframe *tf) {
ffffffffc0200298:	1141                	addi	sp,sp,-16
ffffffffc020029a:	e406                	sd	ra,8(sp)
    print_stackframe();
ffffffffc020029c:	f71ff0ef          	jal	ra,ffffffffc020020c <print_stackframe>
    return 0;
}
ffffffffc02002a0:	60a2                	ld	ra,8(sp)
ffffffffc02002a2:	4501                	li	a0,0
ffffffffc02002a4:	0141                	addi	sp,sp,16
ffffffffc02002a6:	8082                	ret

ffffffffc02002a8 <kmonitor>:
kmonitor(struct trapframe *tf) {
ffffffffc02002a8:	7115                	addi	sp,sp,-224
ffffffffc02002aa:	ed5e                	sd	s7,152(sp)
ffffffffc02002ac:	8baa                	mv	s7,a0
    cprintf("Welcome to the kernel debug monitor!!\n");
ffffffffc02002ae:	00002517          	auipc	a0,0x2
ffffffffc02002b2:	f3a50513          	addi	a0,a0,-198 # ffffffffc02021e8 <etext+0x224>
kmonitor(struct trapframe *tf) {
ffffffffc02002b6:	ed86                	sd	ra,216(sp)
ffffffffc02002b8:	e9a2                	sd	s0,208(sp)
ffffffffc02002ba:	e5a6                	sd	s1,200(sp)
ffffffffc02002bc:	e1ca                	sd	s2,192(sp)
ffffffffc02002be:	fd4e                	sd	s3,184(sp)
ffffffffc02002c0:	f952                	sd	s4,176(sp)
ffffffffc02002c2:	f556                	sd	s5,168(sp)
ffffffffc02002c4:	f15a                	sd	s6,160(sp)
ffffffffc02002c6:	e962                	sd	s8,144(sp)
ffffffffc02002c8:	e566                	sd	s9,136(sp)
ffffffffc02002ca:	e16a                	sd	s10,128(sp)
    cprintf("Welcome to the kernel debug monitor!!\n");
ffffffffc02002cc:	e2bff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("Type 'help' for a list of commands.\n");
ffffffffc02002d0:	00002517          	auipc	a0,0x2
ffffffffc02002d4:	f4050513          	addi	a0,a0,-192 # ffffffffc0202210 <etext+0x24c>
ffffffffc02002d8:	e1fff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    if (tf != NULL) {
ffffffffc02002dc:	000b8563          	beqz	s7,ffffffffc02002e6 <kmonitor+0x3e>
        print_trapframe(tf);
ffffffffc02002e0:	855e                	mv	a0,s7
ffffffffc02002e2:	756000ef          	jal	ra,ffffffffc0200a38 <print_trapframe>
ffffffffc02002e6:	00002c17          	auipc	s8,0x2
ffffffffc02002ea:	f9ac0c13          	addi	s8,s8,-102 # ffffffffc0202280 <commands>
        if ((buf = readline("K> ")) != NULL) {
ffffffffc02002ee:	00002917          	auipc	s2,0x2
ffffffffc02002f2:	f4a90913          	addi	s2,s2,-182 # ffffffffc0202238 <etext+0x274>
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc02002f6:	00002497          	auipc	s1,0x2
ffffffffc02002fa:	f4a48493          	addi	s1,s1,-182 # ffffffffc0202240 <etext+0x27c>
        if (argc == MAXARGS - 1) {
ffffffffc02002fe:	49bd                	li	s3,15
            cprintf("Too many arguments (max %d).\n", MAXARGS);
ffffffffc0200300:	00002b17          	auipc	s6,0x2
ffffffffc0200304:	f48b0b13          	addi	s6,s6,-184 # ffffffffc0202248 <etext+0x284>
        argv[argc ++] = buf;
ffffffffc0200308:	00002a17          	auipc	s4,0x2
ffffffffc020030c:	e60a0a13          	addi	s4,s4,-416 # ffffffffc0202168 <etext+0x1a4>
    for (i = 0; i < NCOMMANDS; i ++) {
ffffffffc0200310:	4a8d                	li	s5,3
        if ((buf = readline("K> ")) != NULL) {
ffffffffc0200312:	854a                	mv	a0,s2
ffffffffc0200314:	2f1010ef          	jal	ra,ffffffffc0201e04 <readline>
ffffffffc0200318:	842a                	mv	s0,a0
ffffffffc020031a:	dd65                	beqz	a0,ffffffffc0200312 <kmonitor+0x6a>
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc020031c:	00054583          	lbu	a1,0(a0)
    int argc = 0;
ffffffffc0200320:	4c81                	li	s9,0
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc0200322:	e1bd                	bnez	a1,ffffffffc0200388 <kmonitor+0xe0>
    if (argc == 0) {
ffffffffc0200324:	fe0c87e3          	beqz	s9,ffffffffc0200312 <kmonitor+0x6a>
        if (strcmp(commands[i].name, argv[0]) == 0) {
ffffffffc0200328:	6582                	ld	a1,0(sp)
ffffffffc020032a:	00002d17          	auipc	s10,0x2
ffffffffc020032e:	f56d0d13          	addi	s10,s10,-170 # ffffffffc0202280 <commands>
        argv[argc ++] = buf;
ffffffffc0200332:	8552                	mv	a0,s4
    for (i = 0; i < NCOMMANDS; i ++) {
ffffffffc0200334:	4401                	li	s0,0
ffffffffc0200336:	0d61                	addi	s10,s10,24
        if (strcmp(commands[i].name, argv[0]) == 0) {
ffffffffc0200338:	421010ef          	jal	ra,ffffffffc0201f58 <strcmp>
ffffffffc020033c:	c919                	beqz	a0,ffffffffc0200352 <kmonitor+0xaa>
    for (i = 0; i < NCOMMANDS; i ++) {
ffffffffc020033e:	2405                	addiw	s0,s0,1
ffffffffc0200340:	0b540063          	beq	s0,s5,ffffffffc02003e0 <kmonitor+0x138>
        if (strcmp(commands[i].name, argv[0]) == 0) {
ffffffffc0200344:	000d3503          	ld	a0,0(s10)
ffffffffc0200348:	6582                	ld	a1,0(sp)
    for (i = 0; i < NCOMMANDS; i ++) {
ffffffffc020034a:	0d61                	addi	s10,s10,24
        if (strcmp(commands[i].name, argv[0]) == 0) {
ffffffffc020034c:	40d010ef          	jal	ra,ffffffffc0201f58 <strcmp>
ffffffffc0200350:	f57d                	bnez	a0,ffffffffc020033e <kmonitor+0x96>
            return commands[i].func(argc - 1, argv + 1, tf);
ffffffffc0200352:	00141793          	slli	a5,s0,0x1
ffffffffc0200356:	97a2                	add	a5,a5,s0
ffffffffc0200358:	078e                	slli	a5,a5,0x3
ffffffffc020035a:	97e2                	add	a5,a5,s8
ffffffffc020035c:	6b9c                	ld	a5,16(a5)
ffffffffc020035e:	865e                	mv	a2,s7
ffffffffc0200360:	002c                	addi	a1,sp,8
ffffffffc0200362:	fffc851b          	addiw	a0,s9,-1
ffffffffc0200366:	9782                	jalr	a5
            if (runcmd(buf, tf) < 0) {
ffffffffc0200368:	fa0555e3          	bgez	a0,ffffffffc0200312 <kmonitor+0x6a>
}
ffffffffc020036c:	60ee                	ld	ra,216(sp)
ffffffffc020036e:	644e                	ld	s0,208(sp)
ffffffffc0200370:	64ae                	ld	s1,200(sp)
ffffffffc0200372:	690e                	ld	s2,192(sp)
ffffffffc0200374:	79ea                	ld	s3,184(sp)
ffffffffc0200376:	7a4a                	ld	s4,176(sp)
ffffffffc0200378:	7aaa                	ld	s5,168(sp)
ffffffffc020037a:	7b0a                	ld	s6,160(sp)
ffffffffc020037c:	6bea                	ld	s7,152(sp)
ffffffffc020037e:	6c4a                	ld	s8,144(sp)
ffffffffc0200380:	6caa                	ld	s9,136(sp)
ffffffffc0200382:	6d0a                	ld	s10,128(sp)
ffffffffc0200384:	612d                	addi	sp,sp,224
ffffffffc0200386:	8082                	ret
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc0200388:	8526                	mv	a0,s1
ffffffffc020038a:	413010ef          	jal	ra,ffffffffc0201f9c <strchr>
ffffffffc020038e:	c901                	beqz	a0,ffffffffc020039e <kmonitor+0xf6>
ffffffffc0200390:	00144583          	lbu	a1,1(s0)
            *buf ++ = '\0';
ffffffffc0200394:	00040023          	sb	zero,0(s0)
ffffffffc0200398:	0405                	addi	s0,s0,1
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc020039a:	d5c9                	beqz	a1,ffffffffc0200324 <kmonitor+0x7c>
ffffffffc020039c:	b7f5                	j	ffffffffc0200388 <kmonitor+0xe0>
        if (*buf == '\0') {
ffffffffc020039e:	00044783          	lbu	a5,0(s0)
ffffffffc02003a2:	d3c9                	beqz	a5,ffffffffc0200324 <kmonitor+0x7c>
        if (argc == MAXARGS - 1) {
ffffffffc02003a4:	033c8963          	beq	s9,s3,ffffffffc02003d6 <kmonitor+0x12e>
        argv[argc ++] = buf;
ffffffffc02003a8:	003c9793          	slli	a5,s9,0x3
ffffffffc02003ac:	0118                	addi	a4,sp,128
ffffffffc02003ae:	97ba                	add	a5,a5,a4
ffffffffc02003b0:	f887b023          	sd	s0,-128(a5)
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
ffffffffc02003b4:	00044583          	lbu	a1,0(s0)
        argv[argc ++] = buf;
ffffffffc02003b8:	2c85                	addiw	s9,s9,1
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
ffffffffc02003ba:	e591                	bnez	a1,ffffffffc02003c6 <kmonitor+0x11e>
ffffffffc02003bc:	b7b5                	j	ffffffffc0200328 <kmonitor+0x80>
ffffffffc02003be:	00144583          	lbu	a1,1(s0)
            buf ++;
ffffffffc02003c2:	0405                	addi	s0,s0,1
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
ffffffffc02003c4:	d1a5                	beqz	a1,ffffffffc0200324 <kmonitor+0x7c>
ffffffffc02003c6:	8526                	mv	a0,s1
ffffffffc02003c8:	3d5010ef          	jal	ra,ffffffffc0201f9c <strchr>
ffffffffc02003cc:	d96d                	beqz	a0,ffffffffc02003be <kmonitor+0x116>
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc02003ce:	00044583          	lbu	a1,0(s0)
ffffffffc02003d2:	d9a9                	beqz	a1,ffffffffc0200324 <kmonitor+0x7c>
ffffffffc02003d4:	bf55                	j	ffffffffc0200388 <kmonitor+0xe0>
            cprintf("Too many arguments (max %d).\n", MAXARGS);
ffffffffc02003d6:	45c1                	li	a1,16
ffffffffc02003d8:	855a                	mv	a0,s6
ffffffffc02003da:	d1dff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
ffffffffc02003de:	b7e9                	j	ffffffffc02003a8 <kmonitor+0x100>
    cprintf("Unknown command '%s'\n", argv[0]);
ffffffffc02003e0:	6582                	ld	a1,0(sp)
ffffffffc02003e2:	00002517          	auipc	a0,0x2
ffffffffc02003e6:	e8650513          	addi	a0,a0,-378 # ffffffffc0202268 <etext+0x2a4>
ffffffffc02003ea:	d0dff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    return 0;
ffffffffc02003ee:	b715                	j	ffffffffc0200312 <kmonitor+0x6a>

ffffffffc02003f0 <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02003f0:	00007317          	auipc	t1,0x7
ffffffffc02003f4:	05030313          	addi	t1,t1,80 # ffffffffc0207440 <is_panic>
ffffffffc02003f8:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02003fc:	715d                	addi	sp,sp,-80
ffffffffc02003fe:	ec06                	sd	ra,24(sp)
ffffffffc0200400:	e822                	sd	s0,16(sp)
ffffffffc0200402:	f436                	sd	a3,40(sp)
ffffffffc0200404:	f83a                	sd	a4,48(sp)
ffffffffc0200406:	fc3e                	sd	a5,56(sp)
ffffffffc0200408:	e0c2                	sd	a6,64(sp)
ffffffffc020040a:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc020040c:	020e1a63          	bnez	t3,ffffffffc0200440 <__panic+0x50>
        goto panic_dead;
    }
    is_panic = 1;
ffffffffc0200410:	4785                	li	a5,1
ffffffffc0200412:	00f32023          	sw	a5,0(t1)

    // print the 'message'
    va_list ap;
    va_start(ap, fmt);
ffffffffc0200416:	8432                	mv	s0,a2
ffffffffc0200418:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc020041a:	862e                	mv	a2,a1
ffffffffc020041c:	85aa                	mv	a1,a0
ffffffffc020041e:	00002517          	auipc	a0,0x2
ffffffffc0200422:	eaa50513          	addi	a0,a0,-342 # ffffffffc02022c8 <commands+0x48>
    va_start(ap, fmt);
ffffffffc0200426:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc0200428:	ccfff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    vcprintf(fmt, ap);
ffffffffc020042c:	65a2                	ld	a1,8(sp)
ffffffffc020042e:	8522                	mv	a0,s0
ffffffffc0200430:	ca7ff0ef          	jal	ra,ffffffffc02000d6 <vcprintf>
    cprintf("\n");
ffffffffc0200434:	00002517          	auipc	a0,0x2
ffffffffc0200438:	cdc50513          	addi	a0,a0,-804 # ffffffffc0202110 <etext+0x14c>
ffffffffc020043c:	cbbff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    va_end(ap);

panic_dead:
    intr_disable();
ffffffffc0200440:	412000ef          	jal	ra,ffffffffc0200852 <intr_disable>
    while (1) {
        kmonitor(NULL);
ffffffffc0200444:	4501                	li	a0,0
ffffffffc0200446:	e63ff0ef          	jal	ra,ffffffffc02002a8 <kmonitor>
    while (1) {
ffffffffc020044a:	bfed                	j	ffffffffc0200444 <__panic+0x54>

ffffffffc020044c <clock_init>:

/* *
 * clock_init - initialize 8253 clock to interrupt 100 times per second,
 * and then enable IRQ_TIMER.
 * */
void clock_init(void) {
ffffffffc020044c:	1141                	addi	sp,sp,-16
ffffffffc020044e:	e406                	sd	ra,8(sp)
    // enable timer interrupt in sie
    set_csr(sie, MIP_STIP);
ffffffffc0200450:	02000793          	li	a5,32
ffffffffc0200454:	1047a7f3          	csrrs	a5,sie,a5
    __asm__ __volatile__("rdtime %0" : "=r"(n));
ffffffffc0200458:	c0102573          	rdtime	a0
    ticks = 0;

    cprintf("++ setup timer interrupts\n");
}

void clock_set_next_event(void) { sbi_set_timer(get_cycles() + timebase); }
ffffffffc020045c:	67e1                	lui	a5,0x18
ffffffffc020045e:	6a078793          	addi	a5,a5,1696 # 186a0 <kern_entry-0xffffffffc01e7960>
ffffffffc0200462:	953e                	add	a0,a0,a5
ffffffffc0200464:	26f010ef          	jal	ra,ffffffffc0201ed2 <sbi_set_timer>
}
ffffffffc0200468:	60a2                	ld	ra,8(sp)
    ticks = 0;
ffffffffc020046a:	00007797          	auipc	a5,0x7
ffffffffc020046e:	fc07bf23          	sd	zero,-34(a5) # ffffffffc0207448 <ticks>
    cprintf("++ setup timer interrupts\n");
ffffffffc0200472:	00002517          	auipc	a0,0x2
ffffffffc0200476:	e7650513          	addi	a0,a0,-394 # ffffffffc02022e8 <commands+0x68>
}
ffffffffc020047a:	0141                	addi	sp,sp,16
    cprintf("++ setup timer interrupts\n");
ffffffffc020047c:	b9ad                	j	ffffffffc02000f6 <cprintf>

ffffffffc020047e <clock_set_next_event>:
    __asm__ __volatile__("rdtime %0" : "=r"(n));
ffffffffc020047e:	c0102573          	rdtime	a0
void clock_set_next_event(void) { sbi_set_timer(get_cycles() + timebase); }
ffffffffc0200482:	67e1                	lui	a5,0x18
ffffffffc0200484:	6a078793          	addi	a5,a5,1696 # 186a0 <kern_entry-0xffffffffc01e7960>
ffffffffc0200488:	953e                	add	a0,a0,a5
ffffffffc020048a:	2490106f          	j	ffffffffc0201ed2 <sbi_set_timer>

ffffffffc020048e <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc020048e:	8082                	ret

ffffffffc0200490 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc0200490:	0ff57513          	zext.b	a0,a0
ffffffffc0200494:	2250106f          	j	ffffffffc0201eb8 <sbi_console_putchar>

ffffffffc0200498 <cons_getc>:
 * cons_getc - return the next input character from console,
 * or 0 if none waiting.
 * */
int cons_getc(void) {
    int c = 0;
    c = sbi_console_getchar();
ffffffffc0200498:	2550106f          	j	ffffffffc0201eec <sbi_console_getchar>

ffffffffc020049c <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc020049c:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc020049e:	00002517          	auipc	a0,0x2
ffffffffc02004a2:	e6a50513          	addi	a0,a0,-406 # ffffffffc0202308 <commands+0x88>
void dtb_init(void) {
ffffffffc02004a6:	fc86                	sd	ra,120(sp)
ffffffffc02004a8:	f8a2                	sd	s0,112(sp)
ffffffffc02004aa:	e8d2                	sd	s4,80(sp)
ffffffffc02004ac:	f4a6                	sd	s1,104(sp)
ffffffffc02004ae:	f0ca                	sd	s2,96(sp)
ffffffffc02004b0:	ecce                	sd	s3,88(sp)
ffffffffc02004b2:	e4d6                	sd	s5,72(sp)
ffffffffc02004b4:	e0da                	sd	s6,64(sp)
ffffffffc02004b6:	fc5e                	sd	s7,56(sp)
ffffffffc02004b8:	f862                	sd	s8,48(sp)
ffffffffc02004ba:	f466                	sd	s9,40(sp)
ffffffffc02004bc:	f06a                	sd	s10,32(sp)
ffffffffc02004be:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc02004c0:	c37ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc02004c4:	00007597          	auipc	a1,0x7
ffffffffc02004c8:	b3c5b583          	ld	a1,-1220(a1) # ffffffffc0207000 <boot_hartid>
ffffffffc02004cc:	00002517          	auipc	a0,0x2
ffffffffc02004d0:	e4c50513          	addi	a0,a0,-436 # ffffffffc0202318 <commands+0x98>
ffffffffc02004d4:	c23ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc02004d8:	00007417          	auipc	s0,0x7
ffffffffc02004dc:	b3040413          	addi	s0,s0,-1232 # ffffffffc0207008 <boot_dtb>
ffffffffc02004e0:	600c                	ld	a1,0(s0)
ffffffffc02004e2:	00002517          	auipc	a0,0x2
ffffffffc02004e6:	e4650513          	addi	a0,a0,-442 # ffffffffc0202328 <commands+0xa8>
ffffffffc02004ea:	c0dff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc02004ee:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc02004f2:	00002517          	auipc	a0,0x2
ffffffffc02004f6:	e4e50513          	addi	a0,a0,-434 # ffffffffc0202340 <commands+0xc0>
    if (boot_dtb == 0) {
ffffffffc02004fa:	120a0463          	beqz	s4,ffffffffc0200622 <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc02004fe:	57f5                	li	a5,-3
ffffffffc0200500:	07fa                	slli	a5,a5,0x1e
ffffffffc0200502:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc0200506:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200508:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020050c:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020050e:	0087d59b          	srliw	a1,a5,0x8
ffffffffc0200512:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200516:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020051a:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020051e:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200522:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200524:	8ec9                	or	a3,a3,a0
ffffffffc0200526:	0087979b          	slliw	a5,a5,0x8
ffffffffc020052a:	1b7d                	addi	s6,s6,-1
ffffffffc020052c:	0167f7b3          	and	a5,a5,s6
ffffffffc0200530:	8dd5                	or	a1,a1,a3
ffffffffc0200532:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc0200534:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200538:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc020053a:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed8a4d>
ffffffffc020053e:	10f59163          	bne	a1,a5,ffffffffc0200640 <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc0200542:	471c                	lw	a5,8(a4)
ffffffffc0200544:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc0200546:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200548:	0087d59b          	srliw	a1,a5,0x8
ffffffffc020054c:	0086d51b          	srliw	a0,a3,0x8
ffffffffc0200550:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200554:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200558:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020055c:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200560:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200564:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200568:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020056c:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200570:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200572:	01146433          	or	s0,s0,a7
ffffffffc0200576:	0086969b          	slliw	a3,a3,0x8
ffffffffc020057a:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020057e:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200580:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200584:	8c49                	or	s0,s0,a0
ffffffffc0200586:	0166f6b3          	and	a3,a3,s6
ffffffffc020058a:	00ca6a33          	or	s4,s4,a2
ffffffffc020058e:	0167f7b3          	and	a5,a5,s6
ffffffffc0200592:	8c55                	or	s0,s0,a3
ffffffffc0200594:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200598:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020059a:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020059c:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020059e:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc02005a2:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc02005a4:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02005a6:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc02005aa:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc02005ac:	00002917          	auipc	s2,0x2
ffffffffc02005b0:	de490913          	addi	s2,s2,-540 # ffffffffc0202390 <commands+0x110>
ffffffffc02005b4:	49bd                	li	s3,15
        switch (token) {
ffffffffc02005b6:	4d91                	li	s11,4
ffffffffc02005b8:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02005ba:	00002497          	auipc	s1,0x2
ffffffffc02005be:	dce48493          	addi	s1,s1,-562 # ffffffffc0202388 <commands+0x108>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc02005c2:	000a2703          	lw	a4,0(s4)
ffffffffc02005c6:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02005ca:	0087569b          	srliw	a3,a4,0x8
ffffffffc02005ce:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02005d2:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02005d6:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02005da:	0107571b          	srliw	a4,a4,0x10
ffffffffc02005de:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02005e0:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02005e4:	0087171b          	slliw	a4,a4,0x8
ffffffffc02005e8:	8fd5                	or	a5,a5,a3
ffffffffc02005ea:	00eb7733          	and	a4,s6,a4
ffffffffc02005ee:	8fd9                	or	a5,a5,a4
ffffffffc02005f0:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc02005f2:	09778c63          	beq	a5,s7,ffffffffc020068a <dtb_init+0x1ee>
ffffffffc02005f6:	00fbea63          	bltu	s7,a5,ffffffffc020060a <dtb_init+0x16e>
ffffffffc02005fa:	07a78663          	beq	a5,s10,ffffffffc0200666 <dtb_init+0x1ca>
ffffffffc02005fe:	4709                	li	a4,2
ffffffffc0200600:	00e79763          	bne	a5,a4,ffffffffc020060e <dtb_init+0x172>
ffffffffc0200604:	4c81                	li	s9,0
ffffffffc0200606:	8a56                	mv	s4,s5
ffffffffc0200608:	bf6d                	j	ffffffffc02005c2 <dtb_init+0x126>
ffffffffc020060a:	ffb78ee3          	beq	a5,s11,ffffffffc0200606 <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc020060e:	00002517          	auipc	a0,0x2
ffffffffc0200612:	dfa50513          	addi	a0,a0,-518 # ffffffffc0202408 <commands+0x188>
ffffffffc0200616:	ae1ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc020061a:	00002517          	auipc	a0,0x2
ffffffffc020061e:	e2650513          	addi	a0,a0,-474 # ffffffffc0202440 <commands+0x1c0>
}
ffffffffc0200622:	7446                	ld	s0,112(sp)
ffffffffc0200624:	70e6                	ld	ra,120(sp)
ffffffffc0200626:	74a6                	ld	s1,104(sp)
ffffffffc0200628:	7906                	ld	s2,96(sp)
ffffffffc020062a:	69e6                	ld	s3,88(sp)
ffffffffc020062c:	6a46                	ld	s4,80(sp)
ffffffffc020062e:	6aa6                	ld	s5,72(sp)
ffffffffc0200630:	6b06                	ld	s6,64(sp)
ffffffffc0200632:	7be2                	ld	s7,56(sp)
ffffffffc0200634:	7c42                	ld	s8,48(sp)
ffffffffc0200636:	7ca2                	ld	s9,40(sp)
ffffffffc0200638:	7d02                	ld	s10,32(sp)
ffffffffc020063a:	6de2                	ld	s11,24(sp)
ffffffffc020063c:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc020063e:	bc65                	j	ffffffffc02000f6 <cprintf>
}
ffffffffc0200640:	7446                	ld	s0,112(sp)
ffffffffc0200642:	70e6                	ld	ra,120(sp)
ffffffffc0200644:	74a6                	ld	s1,104(sp)
ffffffffc0200646:	7906                	ld	s2,96(sp)
ffffffffc0200648:	69e6                	ld	s3,88(sp)
ffffffffc020064a:	6a46                	ld	s4,80(sp)
ffffffffc020064c:	6aa6                	ld	s5,72(sp)
ffffffffc020064e:	6b06                	ld	s6,64(sp)
ffffffffc0200650:	7be2                	ld	s7,56(sp)
ffffffffc0200652:	7c42                	ld	s8,48(sp)
ffffffffc0200654:	7ca2                	ld	s9,40(sp)
ffffffffc0200656:	7d02                	ld	s10,32(sp)
ffffffffc0200658:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc020065a:	00002517          	auipc	a0,0x2
ffffffffc020065e:	d0650513          	addi	a0,a0,-762 # ffffffffc0202360 <commands+0xe0>
}
ffffffffc0200662:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc0200664:	bc49                	j	ffffffffc02000f6 <cprintf>
                int name_len = strlen(name);
ffffffffc0200666:	8556                	mv	a0,s5
ffffffffc0200668:	0bb010ef          	jal	ra,ffffffffc0201f22 <strlen>
ffffffffc020066c:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc020066e:	4619                	li	a2,6
ffffffffc0200670:	85a6                	mv	a1,s1
ffffffffc0200672:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc0200674:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200676:	101010ef          	jal	ra,ffffffffc0201f76 <strncmp>
ffffffffc020067a:	e111                	bnez	a0,ffffffffc020067e <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc020067c:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc020067e:	0a91                	addi	s5,s5,4
ffffffffc0200680:	9ad2                	add	s5,s5,s4
ffffffffc0200682:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200686:	8a56                	mv	s4,s5
ffffffffc0200688:	bf2d                	j	ffffffffc02005c2 <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc020068a:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc020068e:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200692:	0087d71b          	srliw	a4,a5,0x8
ffffffffc0200696:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020069a:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020069e:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02006a2:	0107d79b          	srliw	a5,a5,0x10
ffffffffc02006a6:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02006aa:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02006ae:	0087979b          	slliw	a5,a5,0x8
ffffffffc02006b2:	00eaeab3          	or	s5,s5,a4
ffffffffc02006b6:	00fb77b3          	and	a5,s6,a5
ffffffffc02006ba:	00faeab3          	or	s5,s5,a5
ffffffffc02006be:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc02006c0:	000c9c63          	bnez	s9,ffffffffc02006d8 <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc02006c4:	1a82                	slli	s5,s5,0x20
ffffffffc02006c6:	00368793          	addi	a5,a3,3
ffffffffc02006ca:	020ada93          	srli	s5,s5,0x20
ffffffffc02006ce:	9abe                	add	s5,s5,a5
ffffffffc02006d0:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc02006d4:	8a56                	mv	s4,s5
ffffffffc02006d6:	b5f5                	j	ffffffffc02005c2 <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc02006d8:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc02006dc:	85ca                	mv	a1,s2
ffffffffc02006de:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02006e0:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02006e4:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02006e8:	0187971b          	slliw	a4,a5,0x18
ffffffffc02006ec:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02006f0:	0107d79b          	srliw	a5,a5,0x10
ffffffffc02006f4:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02006f6:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02006fa:	0087979b          	slliw	a5,a5,0x8
ffffffffc02006fe:	8d59                	or	a0,a0,a4
ffffffffc0200700:	00fb77b3          	and	a5,s6,a5
ffffffffc0200704:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc0200706:	1502                	slli	a0,a0,0x20
ffffffffc0200708:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020070a:	9522                	add	a0,a0,s0
ffffffffc020070c:	04d010ef          	jal	ra,ffffffffc0201f58 <strcmp>
ffffffffc0200710:	66a2                	ld	a3,8(sp)
ffffffffc0200712:	f94d                	bnez	a0,ffffffffc02006c4 <dtb_init+0x228>
ffffffffc0200714:	fb59f8e3          	bgeu	s3,s5,ffffffffc02006c4 <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc0200718:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc020071c:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc0200720:	00002517          	auipc	a0,0x2
ffffffffc0200724:	c7850513          	addi	a0,a0,-904 # ffffffffc0202398 <commands+0x118>
           fdt32_to_cpu(x >> 32);
ffffffffc0200728:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020072c:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc0200730:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200734:	0187de1b          	srliw	t3,a5,0x18
ffffffffc0200738:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020073c:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200740:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200744:	0187d693          	srli	a3,a5,0x18
ffffffffc0200748:	01861f1b          	slliw	t5,a2,0x18
ffffffffc020074c:	0087579b          	srliw	a5,a4,0x8
ffffffffc0200750:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200754:	0106561b          	srliw	a2,a2,0x10
ffffffffc0200758:	010f6f33          	or	t5,t5,a6
ffffffffc020075c:	0187529b          	srliw	t0,a4,0x18
ffffffffc0200760:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200764:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200768:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020076c:	0186f6b3          	and	a3,a3,s8
ffffffffc0200770:	01859e1b          	slliw	t3,a1,0x18
ffffffffc0200774:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200778:	0107581b          	srliw	a6,a4,0x10
ffffffffc020077c:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200780:	8361                	srli	a4,a4,0x18
ffffffffc0200782:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200786:	0105d59b          	srliw	a1,a1,0x10
ffffffffc020078a:	01e6e6b3          	or	a3,a3,t5
ffffffffc020078e:	00cb7633          	and	a2,s6,a2
ffffffffc0200792:	0088181b          	slliw	a6,a6,0x8
ffffffffc0200796:	0085959b          	slliw	a1,a1,0x8
ffffffffc020079a:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020079e:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02007a2:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02007a6:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02007aa:	0088989b          	slliw	a7,a7,0x8
ffffffffc02007ae:	011b78b3          	and	a7,s6,a7
ffffffffc02007b2:	005eeeb3          	or	t4,t4,t0
ffffffffc02007b6:	00c6e733          	or	a4,a3,a2
ffffffffc02007ba:	006c6c33          	or	s8,s8,t1
ffffffffc02007be:	010b76b3          	and	a3,s6,a6
ffffffffc02007c2:	00bb7b33          	and	s6,s6,a1
ffffffffc02007c6:	01d7e7b3          	or	a5,a5,t4
ffffffffc02007ca:	016c6b33          	or	s6,s8,s6
ffffffffc02007ce:	01146433          	or	s0,s0,a7
ffffffffc02007d2:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc02007d4:	1702                	slli	a4,a4,0x20
ffffffffc02007d6:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc02007d8:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc02007da:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc02007dc:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc02007de:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc02007e2:	0167eb33          	or	s6,a5,s6
ffffffffc02007e6:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc02007e8:	90fff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc02007ec:	85a2                	mv	a1,s0
ffffffffc02007ee:	00002517          	auipc	a0,0x2
ffffffffc02007f2:	bca50513          	addi	a0,a0,-1078 # ffffffffc02023b8 <commands+0x138>
ffffffffc02007f6:	901ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc02007fa:	014b5613          	srli	a2,s6,0x14
ffffffffc02007fe:	85da                	mv	a1,s6
ffffffffc0200800:	00002517          	auipc	a0,0x2
ffffffffc0200804:	bd050513          	addi	a0,a0,-1072 # ffffffffc02023d0 <commands+0x150>
ffffffffc0200808:	8efff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc020080c:	008b05b3          	add	a1,s6,s0
ffffffffc0200810:	15fd                	addi	a1,a1,-1
ffffffffc0200812:	00002517          	auipc	a0,0x2
ffffffffc0200816:	bde50513          	addi	a0,a0,-1058 # ffffffffc02023f0 <commands+0x170>
ffffffffc020081a:	8ddff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("DTB init completed\n");
ffffffffc020081e:	00002517          	auipc	a0,0x2
ffffffffc0200822:	c2250513          	addi	a0,a0,-990 # ffffffffc0202440 <commands+0x1c0>
        memory_base = mem_base;
ffffffffc0200826:	00007797          	auipc	a5,0x7
ffffffffc020082a:	c287b523          	sd	s0,-982(a5) # ffffffffc0207450 <memory_base>
        memory_size = mem_size;
ffffffffc020082e:	00007797          	auipc	a5,0x7
ffffffffc0200832:	c367b523          	sd	s6,-982(a5) # ffffffffc0207458 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc0200836:	b3f5                	j	ffffffffc0200622 <dtb_init+0x186>

ffffffffc0200838 <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc0200838:	00007517          	auipc	a0,0x7
ffffffffc020083c:	c1853503          	ld	a0,-1000(a0) # ffffffffc0207450 <memory_base>
ffffffffc0200840:	8082                	ret

ffffffffc0200842 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
}
ffffffffc0200842:	00007517          	auipc	a0,0x7
ffffffffc0200846:	c1653503          	ld	a0,-1002(a0) # ffffffffc0207458 <memory_size>
ffffffffc020084a:	8082                	ret

ffffffffc020084c <intr_enable>:
#include <intr.h>
#include <riscv.h>

/* intr_enable - enable irq interrupt */
void intr_enable(void) { set_csr(sstatus, SSTATUS_SIE); }
ffffffffc020084c:	100167f3          	csrrsi	a5,sstatus,2
ffffffffc0200850:	8082                	ret

ffffffffc0200852 <intr_disable>:

/* intr_disable - disable irq interrupt */
void intr_disable(void) { clear_csr(sstatus, SSTATUS_SIE); }
ffffffffc0200852:	100177f3          	csrrci	a5,sstatus,2
ffffffffc0200856:	8082                	ret

ffffffffc0200858 <idt_init>:
     */

    extern void __alltraps(void); // 所有中断处理函数的入口地址
    /* Set sup0 scratch register to 0, indicating to exception vector
       that we are presently executing in the kernel */
    write_csr(sscratch, 0); // 初始化 supervisor scratch 寄存器为 0
ffffffffc0200858:	14005073          	csrwi	sscratch,0
    /* Set the exception vector address */
    write_csr(stvec, &__alltraps);
ffffffffc020085c:	00000797          	auipc	a5,0x0
ffffffffc0200860:	39478793          	addi	a5,a5,916 # ffffffffc0200bf0 <__alltraps>
ffffffffc0200864:	10579073          	csrw	stvec,a5
}
ffffffffc0200868:	8082                	ret

ffffffffc020086a <print_regs>:
    cprintf("  cause    0x%08x\n", tf->cause); // 打印 cause 寄存器值
}

// 打印寄存器信息
void print_regs(struct pushregs *gpr) {
    cprintf("  zero     0x%08x\n", gpr->zero);
ffffffffc020086a:	610c                	ld	a1,0(a0)
void print_regs(struct pushregs *gpr) {
ffffffffc020086c:	1141                	addi	sp,sp,-16
ffffffffc020086e:	e022                	sd	s0,0(sp)
ffffffffc0200870:	842a                	mv	s0,a0
    cprintf("  zero     0x%08x\n", gpr->zero);
ffffffffc0200872:	00002517          	auipc	a0,0x2
ffffffffc0200876:	be650513          	addi	a0,a0,-1050 # ffffffffc0202458 <commands+0x1d8>
void print_regs(struct pushregs *gpr) {
ffffffffc020087a:	e406                	sd	ra,8(sp)
    cprintf("  zero     0x%08x\n", gpr->zero);
ffffffffc020087c:	87bff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  ra       0x%08x\n", gpr->ra);
ffffffffc0200880:	640c                	ld	a1,8(s0)
ffffffffc0200882:	00002517          	auipc	a0,0x2
ffffffffc0200886:	bee50513          	addi	a0,a0,-1042 # ffffffffc0202470 <commands+0x1f0>
ffffffffc020088a:	86dff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  sp       0x%08x\n", gpr->sp);
ffffffffc020088e:	680c                	ld	a1,16(s0)
ffffffffc0200890:	00002517          	auipc	a0,0x2
ffffffffc0200894:	bf850513          	addi	a0,a0,-1032 # ffffffffc0202488 <commands+0x208>
ffffffffc0200898:	85fff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  gp       0x%08x\n", gpr->gp);
ffffffffc020089c:	6c0c                	ld	a1,24(s0)
ffffffffc020089e:	00002517          	auipc	a0,0x2
ffffffffc02008a2:	c0250513          	addi	a0,a0,-1022 # ffffffffc02024a0 <commands+0x220>
ffffffffc02008a6:	851ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  tp       0x%08x\n", gpr->tp);
ffffffffc02008aa:	700c                	ld	a1,32(s0)
ffffffffc02008ac:	00002517          	auipc	a0,0x2
ffffffffc02008b0:	c0c50513          	addi	a0,a0,-1012 # ffffffffc02024b8 <commands+0x238>
ffffffffc02008b4:	843ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  t0       0x%08x\n", gpr->t0);
ffffffffc02008b8:	740c                	ld	a1,40(s0)
ffffffffc02008ba:	00002517          	auipc	a0,0x2
ffffffffc02008be:	c1650513          	addi	a0,a0,-1002 # ffffffffc02024d0 <commands+0x250>
ffffffffc02008c2:	835ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  t1       0x%08x\n", gpr->t1);
ffffffffc02008c6:	780c                	ld	a1,48(s0)
ffffffffc02008c8:	00002517          	auipc	a0,0x2
ffffffffc02008cc:	c2050513          	addi	a0,a0,-992 # ffffffffc02024e8 <commands+0x268>
ffffffffc02008d0:	827ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  t2       0x%08x\n", gpr->t2);
ffffffffc02008d4:	7c0c                	ld	a1,56(s0)
ffffffffc02008d6:	00002517          	auipc	a0,0x2
ffffffffc02008da:	c2a50513          	addi	a0,a0,-982 # ffffffffc0202500 <commands+0x280>
ffffffffc02008de:	819ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  s0       0x%08x\n", gpr->s0);
ffffffffc02008e2:	602c                	ld	a1,64(s0)
ffffffffc02008e4:	00002517          	auipc	a0,0x2
ffffffffc02008e8:	c3450513          	addi	a0,a0,-972 # ffffffffc0202518 <commands+0x298>
ffffffffc02008ec:	80bff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  s1       0x%08x\n", gpr->s1);
ffffffffc02008f0:	642c                	ld	a1,72(s0)
ffffffffc02008f2:	00002517          	auipc	a0,0x2
ffffffffc02008f6:	c3e50513          	addi	a0,a0,-962 # ffffffffc0202530 <commands+0x2b0>
ffffffffc02008fa:	ffcff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  a0       0x%08x\n", gpr->a0);
ffffffffc02008fe:	682c                	ld	a1,80(s0)
ffffffffc0200900:	00002517          	auipc	a0,0x2
ffffffffc0200904:	c4850513          	addi	a0,a0,-952 # ffffffffc0202548 <commands+0x2c8>
ffffffffc0200908:	feeff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  a1       0x%08x\n", gpr->a1);
ffffffffc020090c:	6c2c                	ld	a1,88(s0)
ffffffffc020090e:	00002517          	auipc	a0,0x2
ffffffffc0200912:	c5250513          	addi	a0,a0,-942 # ffffffffc0202560 <commands+0x2e0>
ffffffffc0200916:	fe0ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  a2       0x%08x\n", gpr->a2);
ffffffffc020091a:	702c                	ld	a1,96(s0)
ffffffffc020091c:	00002517          	auipc	a0,0x2
ffffffffc0200920:	c5c50513          	addi	a0,a0,-932 # ffffffffc0202578 <commands+0x2f8>
ffffffffc0200924:	fd2ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  a3       0x%08x\n", gpr->a3);
ffffffffc0200928:	742c                	ld	a1,104(s0)
ffffffffc020092a:	00002517          	auipc	a0,0x2
ffffffffc020092e:	c6650513          	addi	a0,a0,-922 # ffffffffc0202590 <commands+0x310>
ffffffffc0200932:	fc4ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  a4       0x%08x\n", gpr->a4);
ffffffffc0200936:	782c                	ld	a1,112(s0)
ffffffffc0200938:	00002517          	auipc	a0,0x2
ffffffffc020093c:	c7050513          	addi	a0,a0,-912 # ffffffffc02025a8 <commands+0x328>
ffffffffc0200940:	fb6ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  a5       0x%08x\n", gpr->a5);
ffffffffc0200944:	7c2c                	ld	a1,120(s0)
ffffffffc0200946:	00002517          	auipc	a0,0x2
ffffffffc020094a:	c7a50513          	addi	a0,a0,-902 # ffffffffc02025c0 <commands+0x340>
ffffffffc020094e:	fa8ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  a6       0x%08x\n", gpr->a6);
ffffffffc0200952:	604c                	ld	a1,128(s0)
ffffffffc0200954:	00002517          	auipc	a0,0x2
ffffffffc0200958:	c8450513          	addi	a0,a0,-892 # ffffffffc02025d8 <commands+0x358>
ffffffffc020095c:	f9aff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  a7       0x%08x\n", gpr->a7);
ffffffffc0200960:	644c                	ld	a1,136(s0)
ffffffffc0200962:	00002517          	auipc	a0,0x2
ffffffffc0200966:	c8e50513          	addi	a0,a0,-882 # ffffffffc02025f0 <commands+0x370>
ffffffffc020096a:	f8cff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  s2       0x%08x\n", gpr->s2);
ffffffffc020096e:	684c                	ld	a1,144(s0)
ffffffffc0200970:	00002517          	auipc	a0,0x2
ffffffffc0200974:	c9850513          	addi	a0,a0,-872 # ffffffffc0202608 <commands+0x388>
ffffffffc0200978:	f7eff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  s3       0x%08x\n", gpr->s3);
ffffffffc020097c:	6c4c                	ld	a1,152(s0)
ffffffffc020097e:	00002517          	auipc	a0,0x2
ffffffffc0200982:	ca250513          	addi	a0,a0,-862 # ffffffffc0202620 <commands+0x3a0>
ffffffffc0200986:	f70ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  s4       0x%08x\n", gpr->s4);
ffffffffc020098a:	704c                	ld	a1,160(s0)
ffffffffc020098c:	00002517          	auipc	a0,0x2
ffffffffc0200990:	cac50513          	addi	a0,a0,-852 # ffffffffc0202638 <commands+0x3b8>
ffffffffc0200994:	f62ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  s5       0x%08x\n", gpr->s5);
ffffffffc0200998:	744c                	ld	a1,168(s0)
ffffffffc020099a:	00002517          	auipc	a0,0x2
ffffffffc020099e:	cb650513          	addi	a0,a0,-842 # ffffffffc0202650 <commands+0x3d0>
ffffffffc02009a2:	f54ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  s6       0x%08x\n", gpr->s6);
ffffffffc02009a6:	784c                	ld	a1,176(s0)
ffffffffc02009a8:	00002517          	auipc	a0,0x2
ffffffffc02009ac:	cc050513          	addi	a0,a0,-832 # ffffffffc0202668 <commands+0x3e8>
ffffffffc02009b0:	f46ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  s7       0x%08x\n", gpr->s7);
ffffffffc02009b4:	7c4c                	ld	a1,184(s0)
ffffffffc02009b6:	00002517          	auipc	a0,0x2
ffffffffc02009ba:	cca50513          	addi	a0,a0,-822 # ffffffffc0202680 <commands+0x400>
ffffffffc02009be:	f38ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  s8       0x%08x\n", gpr->s8);
ffffffffc02009c2:	606c                	ld	a1,192(s0)
ffffffffc02009c4:	00002517          	auipc	a0,0x2
ffffffffc02009c8:	cd450513          	addi	a0,a0,-812 # ffffffffc0202698 <commands+0x418>
ffffffffc02009cc:	f2aff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  s9       0x%08x\n", gpr->s9);
ffffffffc02009d0:	646c                	ld	a1,200(s0)
ffffffffc02009d2:	00002517          	auipc	a0,0x2
ffffffffc02009d6:	cde50513          	addi	a0,a0,-802 # ffffffffc02026b0 <commands+0x430>
ffffffffc02009da:	f1cff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  s10      0x%08x\n", gpr->s10);
ffffffffc02009de:	686c                	ld	a1,208(s0)
ffffffffc02009e0:	00002517          	auipc	a0,0x2
ffffffffc02009e4:	ce850513          	addi	a0,a0,-792 # ffffffffc02026c8 <commands+0x448>
ffffffffc02009e8:	f0eff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  s11      0x%08x\n", gpr->s11);
ffffffffc02009ec:	6c6c                	ld	a1,216(s0)
ffffffffc02009ee:	00002517          	auipc	a0,0x2
ffffffffc02009f2:	cf250513          	addi	a0,a0,-782 # ffffffffc02026e0 <commands+0x460>
ffffffffc02009f6:	f00ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  t3       0x%08x\n", gpr->t3);
ffffffffc02009fa:	706c                	ld	a1,224(s0)
ffffffffc02009fc:	00002517          	auipc	a0,0x2
ffffffffc0200a00:	cfc50513          	addi	a0,a0,-772 # ffffffffc02026f8 <commands+0x478>
ffffffffc0200a04:	ef2ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  t4       0x%08x\n", gpr->t4);
ffffffffc0200a08:	746c                	ld	a1,232(s0)
ffffffffc0200a0a:	00002517          	auipc	a0,0x2
ffffffffc0200a0e:	d0650513          	addi	a0,a0,-762 # ffffffffc0202710 <commands+0x490>
ffffffffc0200a12:	ee4ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  t5       0x%08x\n", gpr->t5);
ffffffffc0200a16:	786c                	ld	a1,240(s0)
ffffffffc0200a18:	00002517          	auipc	a0,0x2
ffffffffc0200a1c:	d1050513          	addi	a0,a0,-752 # ffffffffc0202728 <commands+0x4a8>
ffffffffc0200a20:	ed6ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  t6       0x%08x\n", gpr->t6);
ffffffffc0200a24:	7c6c                	ld	a1,248(s0)
}
ffffffffc0200a26:	6402                	ld	s0,0(sp)
ffffffffc0200a28:	60a2                	ld	ra,8(sp)
    cprintf("  t6       0x%08x\n", gpr->t6);
ffffffffc0200a2a:	00002517          	auipc	a0,0x2
ffffffffc0200a2e:	d1650513          	addi	a0,a0,-746 # ffffffffc0202740 <commands+0x4c0>
}
ffffffffc0200a32:	0141                	addi	sp,sp,16
    cprintf("  t6       0x%08x\n", gpr->t6);
ffffffffc0200a34:	ec2ff06f          	j	ffffffffc02000f6 <cprintf>

ffffffffc0200a38 <print_trapframe>:
void print_trapframe(struct trapframe *tf) {
ffffffffc0200a38:	1141                	addi	sp,sp,-16
ffffffffc0200a3a:	e022                	sd	s0,0(sp)
    cprintf("trapframe at %p\n", tf);
ffffffffc0200a3c:	85aa                	mv	a1,a0
void print_trapframe(struct trapframe *tf) {
ffffffffc0200a3e:	842a                	mv	s0,a0
    cprintf("trapframe at %p\n", tf);
ffffffffc0200a40:	00002517          	auipc	a0,0x2
ffffffffc0200a44:	d1850513          	addi	a0,a0,-744 # ffffffffc0202758 <commands+0x4d8>
void print_trapframe(struct trapframe *tf) {
ffffffffc0200a48:	e406                	sd	ra,8(sp)
    cprintf("trapframe at %p\n", tf);
ffffffffc0200a4a:	eacff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    print_regs(&tf->gpr);
ffffffffc0200a4e:	8522                	mv	a0,s0
ffffffffc0200a50:	e1bff0ef          	jal	ra,ffffffffc020086a <print_regs>
    cprintf("  status   0x%08x\n", tf->status); // 打印 status 寄存器值
ffffffffc0200a54:	10043583          	ld	a1,256(s0)
ffffffffc0200a58:	00002517          	auipc	a0,0x2
ffffffffc0200a5c:	d1850513          	addi	a0,a0,-744 # ffffffffc0202770 <commands+0x4f0>
ffffffffc0200a60:	e96ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  epc      0x%08x\n", tf->epc); // 打印 epc 寄存器值
ffffffffc0200a64:	10843583          	ld	a1,264(s0)
ffffffffc0200a68:	00002517          	auipc	a0,0x2
ffffffffc0200a6c:	d2050513          	addi	a0,a0,-736 # ffffffffc0202788 <commands+0x508>
ffffffffc0200a70:	e86ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  badvaddr 0x%08x\n", tf->badvaddr); // 打印 badvaddr 寄存器值
ffffffffc0200a74:	11043583          	ld	a1,272(s0)
ffffffffc0200a78:	00002517          	auipc	a0,0x2
ffffffffc0200a7c:	d2850513          	addi	a0,a0,-728 # ffffffffc02027a0 <commands+0x520>
ffffffffc0200a80:	e76ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    cprintf("  cause    0x%08x\n", tf->cause); // 打印 cause 寄存器值
ffffffffc0200a84:	11843583          	ld	a1,280(s0)
}
ffffffffc0200a88:	6402                	ld	s0,0(sp)
ffffffffc0200a8a:	60a2                	ld	ra,8(sp)
    cprintf("  cause    0x%08x\n", tf->cause); // 打印 cause 寄存器值
ffffffffc0200a8c:	00002517          	auipc	a0,0x2
ffffffffc0200a90:	d2c50513          	addi	a0,a0,-724 # ffffffffc02027b8 <commands+0x538>
}
ffffffffc0200a94:	0141                	addi	sp,sp,16
    cprintf("  cause    0x%08x\n", tf->cause); // 打印 cause 寄存器值
ffffffffc0200a96:	e60ff06f          	j	ffffffffc02000f6 <cprintf>

ffffffffc0200a9a <interrupt_handler>:

// 中断处理函数,trapframe 作为参数传递，保存的是中断/异常发生时的寄存器状态
// trapframe在trap.h中定义
void interrupt_handler(struct trapframe *tf) {
    intptr_t cause = (tf->cause << 1) >> 1;
ffffffffc0200a9a:	11853783          	ld	a5,280(a0)
ffffffffc0200a9e:	472d                	li	a4,11
ffffffffc0200aa0:	0786                	slli	a5,a5,0x1
ffffffffc0200aa2:	8385                	srli	a5,a5,0x1
ffffffffc0200aa4:	08f76363          	bltu	a4,a5,ffffffffc0200b2a <interrupt_handler+0x90>
ffffffffc0200aa8:	00002717          	auipc	a4,0x2
ffffffffc0200aac:	df070713          	addi	a4,a4,-528 # ffffffffc0202898 <commands+0x618>
ffffffffc0200ab0:	078a                	slli	a5,a5,0x2
ffffffffc0200ab2:	97ba                	add	a5,a5,a4
ffffffffc0200ab4:	439c                	lw	a5,0(a5)
ffffffffc0200ab6:	97ba                	add	a5,a5,a4
ffffffffc0200ab8:	8782                	jr	a5
            break;
        case IRQ_H_SOFT:
            cprintf("Hypervisor software interrupt\n");
            break;
        case IRQ_M_SOFT:
            cprintf("Machine software interrupt\n");
ffffffffc0200aba:	00002517          	auipc	a0,0x2
ffffffffc0200abe:	d7650513          	addi	a0,a0,-650 # ffffffffc0202830 <commands+0x5b0>
ffffffffc0200ac2:	e34ff06f          	j	ffffffffc02000f6 <cprintf>
            cprintf("Hypervisor software interrupt\n");
ffffffffc0200ac6:	00002517          	auipc	a0,0x2
ffffffffc0200aca:	d4a50513          	addi	a0,a0,-694 # ffffffffc0202810 <commands+0x590>
ffffffffc0200ace:	e28ff06f          	j	ffffffffc02000f6 <cprintf>
            cprintf("User software interrupt\n");
ffffffffc0200ad2:	00002517          	auipc	a0,0x2
ffffffffc0200ad6:	cfe50513          	addi	a0,a0,-770 # ffffffffc02027d0 <commands+0x550>
ffffffffc0200ada:	e1cff06f          	j	ffffffffc02000f6 <cprintf>
            break;
        case IRQ_U_TIMER:
            cprintf("User Timer interrupt\n");
ffffffffc0200ade:	00002517          	auipc	a0,0x2
ffffffffc0200ae2:	d7250513          	addi	a0,a0,-654 # ffffffffc0202850 <commands+0x5d0>
ffffffffc0200ae6:	e10ff06f          	j	ffffffffc02000f6 <cprintf>
void interrupt_handler(struct trapframe *tf) {
ffffffffc0200aea:	1141                	addi	sp,sp,-16
ffffffffc0200aec:	e406                	sd	ra,8(sp)
            // In fact, Call sbi_set_timer will clear STIP, or you can clear it
            // directly.
            // cprintf("Supervisor timer interrupt\n");
             /* LAB3 EXERCISE1   YOUR CODE :  */
            // (1)设置下次时钟中断
            clock_set_next_event();
ffffffffc0200aee:	991ff0ef          	jal	ra,ffffffffc020047e <clock_set_next_event>
            // (2)计数器（ticks）加一
            ticks++;
ffffffffc0200af2:	00007797          	auipc	a5,0x7
ffffffffc0200af6:	95678793          	addi	a5,a5,-1706 # ffffffffc0207448 <ticks>
ffffffffc0200afa:	6398                	ld	a4,0(a5)
ffffffffc0200afc:	0705                	addi	a4,a4,1
ffffffffc0200afe:	e398                	sd	a4,0(a5)
            // (3)当计数器加到100的时候，输出并增加打印计数
            if (ticks % TICK_NUM == 0) {
ffffffffc0200b00:	639c                	ld	a5,0(a5)
ffffffffc0200b02:	06400713          	li	a4,100
ffffffffc0200b06:	02e7f7b3          	remu	a5,a5,a4
ffffffffc0200b0a:	c38d                	beqz	a5,ffffffffc0200b2c <interrupt_handler+0x92>
            break;
        default:
            print_trapframe(tf);
            break;
    }
}
ffffffffc0200b0c:	60a2                	ld	ra,8(sp)
ffffffffc0200b0e:	0141                	addi	sp,sp,16
ffffffffc0200b10:	8082                	ret
            cprintf("Supervisor external interrupt\n");
ffffffffc0200b12:	00002517          	auipc	a0,0x2
ffffffffc0200b16:	d6650513          	addi	a0,a0,-666 # ffffffffc0202878 <commands+0x5f8>
ffffffffc0200b1a:	ddcff06f          	j	ffffffffc02000f6 <cprintf>
            cprintf("Supervisor software interrupt\n");
ffffffffc0200b1e:	00002517          	auipc	a0,0x2
ffffffffc0200b22:	cd250513          	addi	a0,a0,-814 # ffffffffc02027f0 <commands+0x570>
ffffffffc0200b26:	dd0ff06f          	j	ffffffffc02000f6 <cprintf>
            print_trapframe(tf);
ffffffffc0200b2a:	b739                	j	ffffffffc0200a38 <print_trapframe>
    cprintf("%d ticks\n", TICK_NUM);
ffffffffc0200b2c:	06400593          	li	a1,100
ffffffffc0200b30:	00002517          	auipc	a0,0x2
ffffffffc0200b34:	d3850513          	addi	a0,a0,-712 # ffffffffc0202868 <commands+0x5e8>
ffffffffc0200b38:	dbeff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
                print_count++;
ffffffffc0200b3c:	00007717          	auipc	a4,0x7
ffffffffc0200b40:	92470713          	addi	a4,a4,-1756 # ffffffffc0207460 <print_count>
ffffffffc0200b44:	431c                	lw	a5,0(a4)
                if (print_count >= 10) {
ffffffffc0200b46:	46a5                	li	a3,9
                print_count++;
ffffffffc0200b48:	0017861b          	addiw	a2,a5,1
ffffffffc0200b4c:	c310                	sw	a2,0(a4)
                if (print_count >= 10) {
ffffffffc0200b4e:	fac6dfe3          	bge	a3,a2,ffffffffc0200b0c <interrupt_handler+0x72>
}
ffffffffc0200b52:	60a2                	ld	ra,8(sp)
ffffffffc0200b54:	0141                	addi	sp,sp,16
                    sbi_shutdown();
ffffffffc0200b56:	3b20106f          	j	ffffffffc0201f08 <sbi_shutdown>

ffffffffc0200b5a <exception_handler>:

// 异常处理函数,trapframe 作为参数传递，保存的是异常发生时的寄存器状态
void exception_handler(struct trapframe *tf) {
    switch (tf->cause) {
ffffffffc0200b5a:	11853783          	ld	a5,280(a0)
void exception_handler(struct trapframe *tf) {
ffffffffc0200b5e:	1141                	addi	sp,sp,-16
ffffffffc0200b60:	e022                	sd	s0,0(sp)
ffffffffc0200b62:	e406                	sd	ra,8(sp)
    switch (tf->cause) {
ffffffffc0200b64:	470d                	li	a4,3
void exception_handler(struct trapframe *tf) {
ffffffffc0200b66:	842a                	mv	s0,a0
    switch (tf->cause) {
ffffffffc0200b68:	04e78663          	beq	a5,a4,ffffffffc0200bb4 <exception_handler+0x5a>
ffffffffc0200b6c:	02f76c63          	bltu	a4,a5,ffffffffc0200ba4 <exception_handler+0x4a>
ffffffffc0200b70:	4709                	li	a4,2
ffffffffc0200b72:	02e79563          	bne	a5,a4,ffffffffc0200b9c <exception_handler+0x42>
            break;
        case CAUSE_ILLEGAL_INSTRUCTION:
             // 非法指令异常处理
             /* LAB3 CHALLENGE3   YOUR CODE :  */
            // (1)输出指令异常类型
            cprintf("Exception type: Illegal instruction\n");
ffffffffc0200b76:	00002517          	auipc	a0,0x2
ffffffffc0200b7a:	d5250513          	addi	a0,a0,-686 # ffffffffc02028c8 <commands+0x648>
ffffffffc0200b7e:	d78ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
            // (2)输出异常指令地址
            cprintf("Illegal instruction caught at 0x%08x\n", tf->epc);
ffffffffc0200b82:	10843583          	ld	a1,264(s0)
ffffffffc0200b86:	00002517          	auipc	a0,0x2
ffffffffc0200b8a:	d6a50513          	addi	a0,a0,-662 # ffffffffc02028f0 <commands+0x670>
ffffffffc0200b8e:	d68ff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
            // (3)更新 tf->epc寄存器，跳过当前指令
            tf->epc += 2; // 假设每条指令占4字节
ffffffffc0200b92:	10843783          	ld	a5,264(s0)
ffffffffc0200b96:	0789                	addi	a5,a5,2
ffffffffc0200b98:	10f43423          	sd	a5,264(s0)
            break;
        default:
            print_trapframe(tf);
            break;
    }
}
ffffffffc0200b9c:	60a2                	ld	ra,8(sp)
ffffffffc0200b9e:	6402                	ld	s0,0(sp)
ffffffffc0200ba0:	0141                	addi	sp,sp,16
ffffffffc0200ba2:	8082                	ret
    switch (tf->cause) {
ffffffffc0200ba4:	17f1                	addi	a5,a5,-4
ffffffffc0200ba6:	471d                	li	a4,7
ffffffffc0200ba8:	fef77ae3          	bgeu	a4,a5,ffffffffc0200b9c <exception_handler+0x42>
}
ffffffffc0200bac:	6402                	ld	s0,0(sp)
ffffffffc0200bae:	60a2                	ld	ra,8(sp)
ffffffffc0200bb0:	0141                	addi	sp,sp,16
            print_trapframe(tf);
ffffffffc0200bb2:	b559                	j	ffffffffc0200a38 <print_trapframe>
            cprintf("Exception type: breakpoint\n");
ffffffffc0200bb4:	00002517          	auipc	a0,0x2
ffffffffc0200bb8:	d6450513          	addi	a0,a0,-668 # ffffffffc0202918 <commands+0x698>
ffffffffc0200bbc:	d3aff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
            cprintf("ebreak caught at 0x%08x\n", tf->epc);
ffffffffc0200bc0:	10843583          	ld	a1,264(s0)
ffffffffc0200bc4:	00002517          	auipc	a0,0x2
ffffffffc0200bc8:	d7450513          	addi	a0,a0,-652 # ffffffffc0202938 <commands+0x6b8>
ffffffffc0200bcc:	d2aff0ef          	jal	ra,ffffffffc02000f6 <cprintf>
            tf->epc += 2; // 假设每条指令占4字节
ffffffffc0200bd0:	10843783          	ld	a5,264(s0)
}
ffffffffc0200bd4:	60a2                	ld	ra,8(sp)
            tf->epc += 2; // 假设每条指令占4字节
ffffffffc0200bd6:	0789                	addi	a5,a5,2
ffffffffc0200bd8:	10f43423          	sd	a5,264(s0)
}
ffffffffc0200bdc:	6402                	ld	s0,0(sp)
ffffffffc0200bde:	0141                	addi	sp,sp,16
ffffffffc0200be0:	8082                	ret

ffffffffc0200be2 <trap>:

// 异常/中断分发函数
// 根据 trapframe 中的 cause 字段判断是中断还是异常
// 若 cause 为负数，则为中断，否则为异常
static inline void trap_dispatch(struct trapframe *tf) {
    if ((intptr_t)tf->cause < 0) {
ffffffffc0200be2:	11853783          	ld	a5,280(a0)
ffffffffc0200be6:	0007c363          	bltz	a5,ffffffffc0200bec <trap+0xa>
        // interrupts
        interrupt_handler(tf);
    } else {
        // exceptions
        exception_handler(tf);
ffffffffc0200bea:	bf85                	j	ffffffffc0200b5a <exception_handler>
        interrupt_handler(tf);
ffffffffc0200bec:	b57d                	j	ffffffffc0200a9a <interrupt_handler>
	...

ffffffffc0200bf0 <__alltraps>:
    .endm

    .globl __alltraps
    .align(2)
__alltraps:
    SAVE_ALL
ffffffffc0200bf0:	14011073          	csrw	sscratch,sp
ffffffffc0200bf4:	712d                	addi	sp,sp,-288
ffffffffc0200bf6:	e002                	sd	zero,0(sp)
ffffffffc0200bf8:	e406                	sd	ra,8(sp)
ffffffffc0200bfa:	ec0e                	sd	gp,24(sp)
ffffffffc0200bfc:	f012                	sd	tp,32(sp)
ffffffffc0200bfe:	f416                	sd	t0,40(sp)
ffffffffc0200c00:	f81a                	sd	t1,48(sp)
ffffffffc0200c02:	fc1e                	sd	t2,56(sp)
ffffffffc0200c04:	e0a2                	sd	s0,64(sp)
ffffffffc0200c06:	e4a6                	sd	s1,72(sp)
ffffffffc0200c08:	e8aa                	sd	a0,80(sp)
ffffffffc0200c0a:	ecae                	sd	a1,88(sp)
ffffffffc0200c0c:	f0b2                	sd	a2,96(sp)
ffffffffc0200c0e:	f4b6                	sd	a3,104(sp)
ffffffffc0200c10:	f8ba                	sd	a4,112(sp)
ffffffffc0200c12:	fcbe                	sd	a5,120(sp)
ffffffffc0200c14:	e142                	sd	a6,128(sp)
ffffffffc0200c16:	e546                	sd	a7,136(sp)
ffffffffc0200c18:	e94a                	sd	s2,144(sp)
ffffffffc0200c1a:	ed4e                	sd	s3,152(sp)
ffffffffc0200c1c:	f152                	sd	s4,160(sp)
ffffffffc0200c1e:	f556                	sd	s5,168(sp)
ffffffffc0200c20:	f95a                	sd	s6,176(sp)
ffffffffc0200c22:	fd5e                	sd	s7,184(sp)
ffffffffc0200c24:	e1e2                	sd	s8,192(sp)
ffffffffc0200c26:	e5e6                	sd	s9,200(sp)
ffffffffc0200c28:	e9ea                	sd	s10,208(sp)
ffffffffc0200c2a:	edee                	sd	s11,216(sp)
ffffffffc0200c2c:	f1f2                	sd	t3,224(sp)
ffffffffc0200c2e:	f5f6                	sd	t4,232(sp)
ffffffffc0200c30:	f9fa                	sd	t5,240(sp)
ffffffffc0200c32:	fdfe                	sd	t6,248(sp)
ffffffffc0200c34:	14001473          	csrrw	s0,sscratch,zero
ffffffffc0200c38:	100024f3          	csrr	s1,sstatus
ffffffffc0200c3c:	14102973          	csrr	s2,sepc
ffffffffc0200c40:	143029f3          	csrr	s3,stval
ffffffffc0200c44:	14202a73          	csrr	s4,scause
ffffffffc0200c48:	e822                	sd	s0,16(sp)
ffffffffc0200c4a:	e226                	sd	s1,256(sp)
ffffffffc0200c4c:	e64a                	sd	s2,264(sp)
ffffffffc0200c4e:	ea4e                	sd	s3,272(sp)
ffffffffc0200c50:	ee52                	sd	s4,280(sp)

    move  a0, sp
ffffffffc0200c52:	850a                	mv	a0,sp
    jal trap
ffffffffc0200c54:	f8fff0ef          	jal	ra,ffffffffc0200be2 <trap>

ffffffffc0200c58 <__trapret>:
    # sp should be the same as before "jal trap"

    .globl __trapret
__trapret:
    RESTORE_ALL
ffffffffc0200c58:	6492                	ld	s1,256(sp)
ffffffffc0200c5a:	6932                	ld	s2,264(sp)
ffffffffc0200c5c:	10049073          	csrw	sstatus,s1
ffffffffc0200c60:	14191073          	csrw	sepc,s2
ffffffffc0200c64:	60a2                	ld	ra,8(sp)
ffffffffc0200c66:	61e2                	ld	gp,24(sp)
ffffffffc0200c68:	7202                	ld	tp,32(sp)
ffffffffc0200c6a:	72a2                	ld	t0,40(sp)
ffffffffc0200c6c:	7342                	ld	t1,48(sp)
ffffffffc0200c6e:	73e2                	ld	t2,56(sp)
ffffffffc0200c70:	6406                	ld	s0,64(sp)
ffffffffc0200c72:	64a6                	ld	s1,72(sp)
ffffffffc0200c74:	6546                	ld	a0,80(sp)
ffffffffc0200c76:	65e6                	ld	a1,88(sp)
ffffffffc0200c78:	7606                	ld	a2,96(sp)
ffffffffc0200c7a:	76a6                	ld	a3,104(sp)
ffffffffc0200c7c:	7746                	ld	a4,112(sp)
ffffffffc0200c7e:	77e6                	ld	a5,120(sp)
ffffffffc0200c80:	680a                	ld	a6,128(sp)
ffffffffc0200c82:	68aa                	ld	a7,136(sp)
ffffffffc0200c84:	694a                	ld	s2,144(sp)
ffffffffc0200c86:	69ea                	ld	s3,152(sp)
ffffffffc0200c88:	7a0a                	ld	s4,160(sp)
ffffffffc0200c8a:	7aaa                	ld	s5,168(sp)
ffffffffc0200c8c:	7b4a                	ld	s6,176(sp)
ffffffffc0200c8e:	7bea                	ld	s7,184(sp)
ffffffffc0200c90:	6c0e                	ld	s8,192(sp)
ffffffffc0200c92:	6cae                	ld	s9,200(sp)
ffffffffc0200c94:	6d4e                	ld	s10,208(sp)
ffffffffc0200c96:	6dee                	ld	s11,216(sp)
ffffffffc0200c98:	7e0e                	ld	t3,224(sp)
ffffffffc0200c9a:	7eae                	ld	t4,232(sp)
ffffffffc0200c9c:	7f4e                	ld	t5,240(sp)
ffffffffc0200c9e:	7fee                	ld	t6,248(sp)
ffffffffc0200ca0:	6142                	ld	sp,16(sp)
    # return from supervisor call
    sret
ffffffffc0200ca2:	10200073          	sret

ffffffffc0200ca6 <default_init>:
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc0200ca6:	00006797          	auipc	a5,0x6
ffffffffc0200caa:	38278793          	addi	a5,a5,898 # ffffffffc0207028 <free_area>
ffffffffc0200cae:	e79c                	sd	a5,8(a5)
ffffffffc0200cb0:	e39c                	sd	a5,0(a5)
#define nr_free (free_area.nr_free)

static void
default_init(void) {
    list_init(&free_list);
    nr_free = 0;
ffffffffc0200cb2:	0007a823          	sw	zero,16(a5)
}
ffffffffc0200cb6:	8082                	ret

ffffffffc0200cb8 <default_nr_free_pages>:
}

static size_t
default_nr_free_pages(void) {
    return nr_free;
}
ffffffffc0200cb8:	00006517          	auipc	a0,0x6
ffffffffc0200cbc:	38056503          	lwu	a0,896(a0) # ffffffffc0207038 <free_area+0x10>
ffffffffc0200cc0:	8082                	ret

ffffffffc0200cc2 <default_check>:
}

// LAB2: below code is used to check the first fit allocation algorithm (your EXERCISE 1) 
// NOTICE: You SHOULD NOT CHANGE basic_check, default_check functions!
static void
default_check(void) {
ffffffffc0200cc2:	715d                	addi	sp,sp,-80
ffffffffc0200cc4:	e0a2                	sd	s0,64(sp)
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc0200cc6:	00006417          	auipc	s0,0x6
ffffffffc0200cca:	36240413          	addi	s0,s0,866 # ffffffffc0207028 <free_area>
ffffffffc0200cce:	641c                	ld	a5,8(s0)
ffffffffc0200cd0:	e486                	sd	ra,72(sp)
ffffffffc0200cd2:	fc26                	sd	s1,56(sp)
ffffffffc0200cd4:	f84a                	sd	s2,48(sp)
ffffffffc0200cd6:	f44e                	sd	s3,40(sp)
ffffffffc0200cd8:	f052                	sd	s4,32(sp)
ffffffffc0200cda:	ec56                	sd	s5,24(sp)
ffffffffc0200cdc:	e85a                	sd	s6,16(sp)
ffffffffc0200cde:	e45e                	sd	s7,8(sp)
ffffffffc0200ce0:	e062                	sd	s8,0(sp)
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200ce2:	2c878763          	beq	a5,s0,ffffffffc0200fb0 <default_check+0x2ee>
    int count = 0, total = 0;
ffffffffc0200ce6:	4481                	li	s1,0
ffffffffc0200ce8:	4901                	li	s2,0
 * test_bit - Determine whether a bit is set
 * @nr:     the bit to test
 * @addr:   the address to count from
 * */
static inline bool test_bit(int nr, volatile void *addr) {
    return (((*(volatile unsigned long *)addr) >> nr) & 1);
ffffffffc0200cea:	ff07b703          	ld	a4,-16(a5)
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
ffffffffc0200cee:	8b09                	andi	a4,a4,2
ffffffffc0200cf0:	2c070463          	beqz	a4,ffffffffc0200fb8 <default_check+0x2f6>
        count ++, total += p->property;
ffffffffc0200cf4:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200cf8:	679c                	ld	a5,8(a5)
ffffffffc0200cfa:	2905                	addiw	s2,s2,1
ffffffffc0200cfc:	9cb9                	addw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200cfe:	fe8796e3          	bne	a5,s0,ffffffffc0200cea <default_check+0x28>
    }
    assert(total == nr_free_pages());
ffffffffc0200d02:	89a6                	mv	s3,s1
ffffffffc0200d04:	2f9000ef          	jal	ra,ffffffffc02017fc <nr_free_pages>
ffffffffc0200d08:	71351863          	bne	a0,s3,ffffffffc0201418 <default_check+0x756>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200d0c:	4505                	li	a0,1
ffffffffc0200d0e:	271000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200d12:	8a2a                	mv	s4,a0
ffffffffc0200d14:	44050263          	beqz	a0,ffffffffc0201158 <default_check+0x496>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200d18:	4505                	li	a0,1
ffffffffc0200d1a:	265000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200d1e:	89aa                	mv	s3,a0
ffffffffc0200d20:	70050c63          	beqz	a0,ffffffffc0201438 <default_check+0x776>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200d24:	4505                	li	a0,1
ffffffffc0200d26:	259000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200d2a:	8aaa                	mv	s5,a0
ffffffffc0200d2c:	4a050663          	beqz	a0,ffffffffc02011d8 <default_check+0x516>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200d30:	2b3a0463          	beq	s4,s3,ffffffffc0200fd8 <default_check+0x316>
ffffffffc0200d34:	2aaa0263          	beq	s4,a0,ffffffffc0200fd8 <default_check+0x316>
ffffffffc0200d38:	2aa98063          	beq	s3,a0,ffffffffc0200fd8 <default_check+0x316>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200d3c:	000a2783          	lw	a5,0(s4)
ffffffffc0200d40:	2a079c63          	bnez	a5,ffffffffc0200ff8 <default_check+0x336>
ffffffffc0200d44:	0009a783          	lw	a5,0(s3)
ffffffffc0200d48:	2a079863          	bnez	a5,ffffffffc0200ff8 <default_check+0x336>
ffffffffc0200d4c:	411c                	lw	a5,0(a0)
ffffffffc0200d4e:	2a079563          	bnez	a5,ffffffffc0200ff8 <default_check+0x336>
extern struct Page *pages;
extern size_t npage;
extern const size_t nbase;
extern uint64_t va_pa_offset;

static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200d52:	00006797          	auipc	a5,0x6
ffffffffc0200d56:	71e7b783          	ld	a5,1822(a5) # ffffffffc0207470 <pages>
ffffffffc0200d5a:	40fa0733          	sub	a4,s4,a5
ffffffffc0200d5e:	870d                	srai	a4,a4,0x3
ffffffffc0200d60:	00002597          	auipc	a1,0x2
ffffffffc0200d64:	3805b583          	ld	a1,896(a1) # ffffffffc02030e0 <error_string+0x38>
ffffffffc0200d68:	02b70733          	mul	a4,a4,a1
ffffffffc0200d6c:	00002617          	auipc	a2,0x2
ffffffffc0200d70:	37c63603          	ld	a2,892(a2) # ffffffffc02030e8 <nbase>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200d74:	00006697          	auipc	a3,0x6
ffffffffc0200d78:	6f46b683          	ld	a3,1780(a3) # ffffffffc0207468 <npage>
ffffffffc0200d7c:	06b2                	slli	a3,a3,0xc
ffffffffc0200d7e:	9732                	add	a4,a4,a2

static inline uintptr_t page2pa(struct Page *page) {
    return page2ppn(page) << PGSHIFT;
ffffffffc0200d80:	0732                	slli	a4,a4,0xc
ffffffffc0200d82:	28d77b63          	bgeu	a4,a3,ffffffffc0201018 <default_check+0x356>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200d86:	40f98733          	sub	a4,s3,a5
ffffffffc0200d8a:	870d                	srai	a4,a4,0x3
ffffffffc0200d8c:	02b70733          	mul	a4,a4,a1
ffffffffc0200d90:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200d92:	0732                	slli	a4,a4,0xc
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200d94:	4cd77263          	bgeu	a4,a3,ffffffffc0201258 <default_check+0x596>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200d98:	40f507b3          	sub	a5,a0,a5
ffffffffc0200d9c:	878d                	srai	a5,a5,0x3
ffffffffc0200d9e:	02b787b3          	mul	a5,a5,a1
ffffffffc0200da2:	97b2                	add	a5,a5,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200da4:	07b2                	slli	a5,a5,0xc
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200da6:	30d7f963          	bgeu	a5,a3,ffffffffc02010b8 <default_check+0x3f6>
    assert(alloc_page() == NULL);
ffffffffc0200daa:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200dac:	00043c03          	ld	s8,0(s0)
ffffffffc0200db0:	00843b83          	ld	s7,8(s0)
    unsigned int nr_free_store = nr_free;
ffffffffc0200db4:	01042b03          	lw	s6,16(s0)
    elm->prev = elm->next = elm;
ffffffffc0200db8:	e400                	sd	s0,8(s0)
ffffffffc0200dba:	e000                	sd	s0,0(s0)
    nr_free = 0;
ffffffffc0200dbc:	00006797          	auipc	a5,0x6
ffffffffc0200dc0:	2607ae23          	sw	zero,636(a5) # ffffffffc0207038 <free_area+0x10>
    assert(alloc_page() == NULL);
ffffffffc0200dc4:	1bb000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200dc8:	2c051863          	bnez	a0,ffffffffc0201098 <default_check+0x3d6>
    free_page(p0);
ffffffffc0200dcc:	4585                	li	a1,1
ffffffffc0200dce:	8552                	mv	a0,s4
ffffffffc0200dd0:	1ed000ef          	jal	ra,ffffffffc02017bc <free_pages>
    free_page(p1);
ffffffffc0200dd4:	4585                	li	a1,1
ffffffffc0200dd6:	854e                	mv	a0,s3
ffffffffc0200dd8:	1e5000ef          	jal	ra,ffffffffc02017bc <free_pages>
    free_page(p2);
ffffffffc0200ddc:	4585                	li	a1,1
ffffffffc0200dde:	8556                	mv	a0,s5
ffffffffc0200de0:	1dd000ef          	jal	ra,ffffffffc02017bc <free_pages>
    assert(nr_free == 3);
ffffffffc0200de4:	4818                	lw	a4,16(s0)
ffffffffc0200de6:	478d                	li	a5,3
ffffffffc0200de8:	28f71863          	bne	a4,a5,ffffffffc0201078 <default_check+0x3b6>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200dec:	4505                	li	a0,1
ffffffffc0200dee:	191000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200df2:	89aa                	mv	s3,a0
ffffffffc0200df4:	26050263          	beqz	a0,ffffffffc0201058 <default_check+0x396>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200df8:	4505                	li	a0,1
ffffffffc0200dfa:	185000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200dfe:	8aaa                	mv	s5,a0
ffffffffc0200e00:	3a050c63          	beqz	a0,ffffffffc02011b8 <default_check+0x4f6>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200e04:	4505                	li	a0,1
ffffffffc0200e06:	179000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200e0a:	8a2a                	mv	s4,a0
ffffffffc0200e0c:	38050663          	beqz	a0,ffffffffc0201198 <default_check+0x4d6>
    assert(alloc_page() == NULL);
ffffffffc0200e10:	4505                	li	a0,1
ffffffffc0200e12:	16d000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200e16:	36051163          	bnez	a0,ffffffffc0201178 <default_check+0x4b6>
    free_page(p0);
ffffffffc0200e1a:	4585                	li	a1,1
ffffffffc0200e1c:	854e                	mv	a0,s3
ffffffffc0200e1e:	19f000ef          	jal	ra,ffffffffc02017bc <free_pages>
    assert(!list_empty(&free_list));
ffffffffc0200e22:	641c                	ld	a5,8(s0)
ffffffffc0200e24:	20878a63          	beq	a5,s0,ffffffffc0201038 <default_check+0x376>
    assert((p = alloc_page()) == p0);
ffffffffc0200e28:	4505                	li	a0,1
ffffffffc0200e2a:	155000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200e2e:	30a99563          	bne	s3,a0,ffffffffc0201138 <default_check+0x476>
    assert(alloc_page() == NULL);
ffffffffc0200e32:	4505                	li	a0,1
ffffffffc0200e34:	14b000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200e38:	2e051063          	bnez	a0,ffffffffc0201118 <default_check+0x456>
    assert(nr_free == 0);
ffffffffc0200e3c:	481c                	lw	a5,16(s0)
ffffffffc0200e3e:	2a079d63          	bnez	a5,ffffffffc02010f8 <default_check+0x436>
    free_page(p);
ffffffffc0200e42:	854e                	mv	a0,s3
ffffffffc0200e44:	4585                	li	a1,1
    free_list = free_list_store;
ffffffffc0200e46:	01843023          	sd	s8,0(s0)
ffffffffc0200e4a:	01743423          	sd	s7,8(s0)
    nr_free = nr_free_store;
ffffffffc0200e4e:	01642823          	sw	s6,16(s0)
    free_page(p);
ffffffffc0200e52:	16b000ef          	jal	ra,ffffffffc02017bc <free_pages>
    free_page(p1);
ffffffffc0200e56:	4585                	li	a1,1
ffffffffc0200e58:	8556                	mv	a0,s5
ffffffffc0200e5a:	163000ef          	jal	ra,ffffffffc02017bc <free_pages>
    free_page(p2);
ffffffffc0200e5e:	4585                	li	a1,1
ffffffffc0200e60:	8552                	mv	a0,s4
ffffffffc0200e62:	15b000ef          	jal	ra,ffffffffc02017bc <free_pages>

    basic_check();

    struct Page *p0 = alloc_pages(5), *p1, *p2;
ffffffffc0200e66:	4515                	li	a0,5
ffffffffc0200e68:	117000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200e6c:	89aa                	mv	s3,a0
    assert(p0 != NULL);
ffffffffc0200e6e:	26050563          	beqz	a0,ffffffffc02010d8 <default_check+0x416>
ffffffffc0200e72:	651c                	ld	a5,8(a0)
ffffffffc0200e74:	8385                	srli	a5,a5,0x1
    assert(!PageProperty(p0));
ffffffffc0200e76:	8b85                	andi	a5,a5,1
ffffffffc0200e78:	54079063          	bnez	a5,ffffffffc02013b8 <default_check+0x6f6>

    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);
ffffffffc0200e7c:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200e7e:	00043b03          	ld	s6,0(s0)
ffffffffc0200e82:	00843a83          	ld	s5,8(s0)
ffffffffc0200e86:	e000                	sd	s0,0(s0)
ffffffffc0200e88:	e400                	sd	s0,8(s0)
    assert(alloc_page() == NULL);
ffffffffc0200e8a:	0f5000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200e8e:	50051563          	bnez	a0,ffffffffc0201398 <default_check+0x6d6>

    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    free_pages(p0 + 2, 3);
ffffffffc0200e92:	05098a13          	addi	s4,s3,80
ffffffffc0200e96:	8552                	mv	a0,s4
ffffffffc0200e98:	458d                	li	a1,3
    unsigned int nr_free_store = nr_free;
ffffffffc0200e9a:	01042b83          	lw	s7,16(s0)
    nr_free = 0;
ffffffffc0200e9e:	00006797          	auipc	a5,0x6
ffffffffc0200ea2:	1807ad23          	sw	zero,410(a5) # ffffffffc0207038 <free_area+0x10>
    free_pages(p0 + 2, 3);
ffffffffc0200ea6:	117000ef          	jal	ra,ffffffffc02017bc <free_pages>
    assert(alloc_pages(4) == NULL);
ffffffffc0200eaa:	4511                	li	a0,4
ffffffffc0200eac:	0d3000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200eb0:	4c051463          	bnez	a0,ffffffffc0201378 <default_check+0x6b6>
ffffffffc0200eb4:	0589b783          	ld	a5,88(s3)
ffffffffc0200eb8:	8385                	srli	a5,a5,0x1
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
ffffffffc0200eba:	8b85                	andi	a5,a5,1
ffffffffc0200ebc:	48078e63          	beqz	a5,ffffffffc0201358 <default_check+0x696>
ffffffffc0200ec0:	0609a703          	lw	a4,96(s3)
ffffffffc0200ec4:	478d                	li	a5,3
ffffffffc0200ec6:	48f71963          	bne	a4,a5,ffffffffc0201358 <default_check+0x696>
    assert((p1 = alloc_pages(3)) != NULL);
ffffffffc0200eca:	450d                	li	a0,3
ffffffffc0200ecc:	0b3000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200ed0:	8c2a                	mv	s8,a0
ffffffffc0200ed2:	46050363          	beqz	a0,ffffffffc0201338 <default_check+0x676>
    assert(alloc_page() == NULL);
ffffffffc0200ed6:	4505                	li	a0,1
ffffffffc0200ed8:	0a7000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200edc:	42051e63          	bnez	a0,ffffffffc0201318 <default_check+0x656>
    assert(p0 + 2 == p1);
ffffffffc0200ee0:	418a1c63          	bne	s4,s8,ffffffffc02012f8 <default_check+0x636>

    p2 = p0 + 1;
    free_page(p0);
ffffffffc0200ee4:	4585                	li	a1,1
ffffffffc0200ee6:	854e                	mv	a0,s3
ffffffffc0200ee8:	0d5000ef          	jal	ra,ffffffffc02017bc <free_pages>
    free_pages(p1, 3);
ffffffffc0200eec:	458d                	li	a1,3
ffffffffc0200eee:	8552                	mv	a0,s4
ffffffffc0200ef0:	0cd000ef          	jal	ra,ffffffffc02017bc <free_pages>
ffffffffc0200ef4:	0089b783          	ld	a5,8(s3)
    p2 = p0 + 1;
ffffffffc0200ef8:	02898c13          	addi	s8,s3,40
ffffffffc0200efc:	8385                	srli	a5,a5,0x1
    assert(PageProperty(p0) && p0->property == 1);
ffffffffc0200efe:	8b85                	andi	a5,a5,1
ffffffffc0200f00:	3c078c63          	beqz	a5,ffffffffc02012d8 <default_check+0x616>
ffffffffc0200f04:	0109a703          	lw	a4,16(s3)
ffffffffc0200f08:	4785                	li	a5,1
ffffffffc0200f0a:	3cf71763          	bne	a4,a5,ffffffffc02012d8 <default_check+0x616>
ffffffffc0200f0e:	008a3783          	ld	a5,8(s4)
ffffffffc0200f12:	8385                	srli	a5,a5,0x1
    assert(PageProperty(p1) && p1->property == 3);
ffffffffc0200f14:	8b85                	andi	a5,a5,1
ffffffffc0200f16:	3a078163          	beqz	a5,ffffffffc02012b8 <default_check+0x5f6>
ffffffffc0200f1a:	010a2703          	lw	a4,16(s4)
ffffffffc0200f1e:	478d                	li	a5,3
ffffffffc0200f20:	38f71c63          	bne	a4,a5,ffffffffc02012b8 <default_check+0x5f6>

    assert((p0 = alloc_page()) == p2 - 1);
ffffffffc0200f24:	4505                	li	a0,1
ffffffffc0200f26:	059000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200f2a:	36a99763          	bne	s3,a0,ffffffffc0201298 <default_check+0x5d6>
    free_page(p0);
ffffffffc0200f2e:	4585                	li	a1,1
ffffffffc0200f30:	08d000ef          	jal	ra,ffffffffc02017bc <free_pages>
    assert((p0 = alloc_pages(2)) == p2 + 1);
ffffffffc0200f34:	4509                	li	a0,2
ffffffffc0200f36:	049000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200f3a:	32aa1f63          	bne	s4,a0,ffffffffc0201278 <default_check+0x5b6>

    free_pages(p0, 2);
ffffffffc0200f3e:	4589                	li	a1,2
ffffffffc0200f40:	07d000ef          	jal	ra,ffffffffc02017bc <free_pages>
    free_page(p2);
ffffffffc0200f44:	4585                	li	a1,1
ffffffffc0200f46:	8562                	mv	a0,s8
ffffffffc0200f48:	075000ef          	jal	ra,ffffffffc02017bc <free_pages>

    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200f4c:	4515                	li	a0,5
ffffffffc0200f4e:	031000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200f52:	89aa                	mv	s3,a0
ffffffffc0200f54:	48050263          	beqz	a0,ffffffffc02013d8 <default_check+0x716>
    assert(alloc_page() == NULL);
ffffffffc0200f58:	4505                	li	a0,1
ffffffffc0200f5a:	025000ef          	jal	ra,ffffffffc020177e <alloc_pages>
ffffffffc0200f5e:	2c051d63          	bnez	a0,ffffffffc0201238 <default_check+0x576>

    assert(nr_free == 0);
ffffffffc0200f62:	481c                	lw	a5,16(s0)
ffffffffc0200f64:	2a079a63          	bnez	a5,ffffffffc0201218 <default_check+0x556>
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);
ffffffffc0200f68:	4595                	li	a1,5
ffffffffc0200f6a:	854e                	mv	a0,s3
    nr_free = nr_free_store;
ffffffffc0200f6c:	01742823          	sw	s7,16(s0)
    free_list = free_list_store;
ffffffffc0200f70:	01643023          	sd	s6,0(s0)
ffffffffc0200f74:	01543423          	sd	s5,8(s0)
    free_pages(p0, 5);
ffffffffc0200f78:	045000ef          	jal	ra,ffffffffc02017bc <free_pages>
    return listelm->next;
ffffffffc0200f7c:	641c                	ld	a5,8(s0)

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200f7e:	00878963          	beq	a5,s0,ffffffffc0200f90 <default_check+0x2ce>
        struct Page *p = le2page(le, page_link);
        count --, total -= p->property;
ffffffffc0200f82:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200f86:	679c                	ld	a5,8(a5)
ffffffffc0200f88:	397d                	addiw	s2,s2,-1
ffffffffc0200f8a:	9c99                	subw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200f8c:	fe879be3          	bne	a5,s0,ffffffffc0200f82 <default_check+0x2c0>
    }
    assert(count == 0);
ffffffffc0200f90:	26091463          	bnez	s2,ffffffffc02011f8 <default_check+0x536>
    assert(total == 0);
ffffffffc0200f94:	46049263          	bnez	s1,ffffffffc02013f8 <default_check+0x736>
}
ffffffffc0200f98:	60a6                	ld	ra,72(sp)
ffffffffc0200f9a:	6406                	ld	s0,64(sp)
ffffffffc0200f9c:	74e2                	ld	s1,56(sp)
ffffffffc0200f9e:	7942                	ld	s2,48(sp)
ffffffffc0200fa0:	79a2                	ld	s3,40(sp)
ffffffffc0200fa2:	7a02                	ld	s4,32(sp)
ffffffffc0200fa4:	6ae2                	ld	s5,24(sp)
ffffffffc0200fa6:	6b42                	ld	s6,16(sp)
ffffffffc0200fa8:	6ba2                	ld	s7,8(sp)
ffffffffc0200faa:	6c02                	ld	s8,0(sp)
ffffffffc0200fac:	6161                	addi	sp,sp,80
ffffffffc0200fae:	8082                	ret
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200fb0:	4981                	li	s3,0
    int count = 0, total = 0;
ffffffffc0200fb2:	4481                	li	s1,0
ffffffffc0200fb4:	4901                	li	s2,0
ffffffffc0200fb6:	b3b9                	j	ffffffffc0200d04 <default_check+0x42>
        assert(PageProperty(p));
ffffffffc0200fb8:	00002697          	auipc	a3,0x2
ffffffffc0200fbc:	9a068693          	addi	a3,a3,-1632 # ffffffffc0202958 <commands+0x6d8>
ffffffffc0200fc0:	00002617          	auipc	a2,0x2
ffffffffc0200fc4:	9a860613          	addi	a2,a2,-1624 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0200fc8:	0f000593          	li	a1,240
ffffffffc0200fcc:	00002517          	auipc	a0,0x2
ffffffffc0200fd0:	9b450513          	addi	a0,a0,-1612 # ffffffffc0202980 <commands+0x700>
ffffffffc0200fd4:	c1cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200fd8:	00002697          	auipc	a3,0x2
ffffffffc0200fdc:	a4068693          	addi	a3,a3,-1472 # ffffffffc0202a18 <commands+0x798>
ffffffffc0200fe0:	00002617          	auipc	a2,0x2
ffffffffc0200fe4:	98860613          	addi	a2,a2,-1656 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0200fe8:	0bd00593          	li	a1,189
ffffffffc0200fec:	00002517          	auipc	a0,0x2
ffffffffc0200ff0:	99450513          	addi	a0,a0,-1644 # ffffffffc0202980 <commands+0x700>
ffffffffc0200ff4:	bfcff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200ff8:	00002697          	auipc	a3,0x2
ffffffffc0200ffc:	a4868693          	addi	a3,a3,-1464 # ffffffffc0202a40 <commands+0x7c0>
ffffffffc0201000:	00002617          	auipc	a2,0x2
ffffffffc0201004:	96860613          	addi	a2,a2,-1688 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201008:	0be00593          	li	a1,190
ffffffffc020100c:	00002517          	auipc	a0,0x2
ffffffffc0201010:	97450513          	addi	a0,a0,-1676 # ffffffffc0202980 <commands+0x700>
ffffffffc0201014:	bdcff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0201018:	00002697          	auipc	a3,0x2
ffffffffc020101c:	a6868693          	addi	a3,a3,-1432 # ffffffffc0202a80 <commands+0x800>
ffffffffc0201020:	00002617          	auipc	a2,0x2
ffffffffc0201024:	94860613          	addi	a2,a2,-1720 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201028:	0c000593          	li	a1,192
ffffffffc020102c:	00002517          	auipc	a0,0x2
ffffffffc0201030:	95450513          	addi	a0,a0,-1708 # ffffffffc0202980 <commands+0x700>
ffffffffc0201034:	bbcff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(!list_empty(&free_list));
ffffffffc0201038:	00002697          	auipc	a3,0x2
ffffffffc020103c:	ad068693          	addi	a3,a3,-1328 # ffffffffc0202b08 <commands+0x888>
ffffffffc0201040:	00002617          	auipc	a2,0x2
ffffffffc0201044:	92860613          	addi	a2,a2,-1752 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201048:	0d900593          	li	a1,217
ffffffffc020104c:	00002517          	auipc	a0,0x2
ffffffffc0201050:	93450513          	addi	a0,a0,-1740 # ffffffffc0202980 <commands+0x700>
ffffffffc0201054:	b9cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0201058:	00002697          	auipc	a3,0x2
ffffffffc020105c:	96068693          	addi	a3,a3,-1696 # ffffffffc02029b8 <commands+0x738>
ffffffffc0201060:	00002617          	auipc	a2,0x2
ffffffffc0201064:	90860613          	addi	a2,a2,-1784 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201068:	0d200593          	li	a1,210
ffffffffc020106c:	00002517          	auipc	a0,0x2
ffffffffc0201070:	91450513          	addi	a0,a0,-1772 # ffffffffc0202980 <commands+0x700>
ffffffffc0201074:	b7cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(nr_free == 3);
ffffffffc0201078:	00002697          	auipc	a3,0x2
ffffffffc020107c:	a8068693          	addi	a3,a3,-1408 # ffffffffc0202af8 <commands+0x878>
ffffffffc0201080:	00002617          	auipc	a2,0x2
ffffffffc0201084:	8e860613          	addi	a2,a2,-1816 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201088:	0d000593          	li	a1,208
ffffffffc020108c:	00002517          	auipc	a0,0x2
ffffffffc0201090:	8f450513          	addi	a0,a0,-1804 # ffffffffc0202980 <commands+0x700>
ffffffffc0201094:	b5cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0201098:	00002697          	auipc	a3,0x2
ffffffffc020109c:	a4868693          	addi	a3,a3,-1464 # ffffffffc0202ae0 <commands+0x860>
ffffffffc02010a0:	00002617          	auipc	a2,0x2
ffffffffc02010a4:	8c860613          	addi	a2,a2,-1848 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02010a8:	0cb00593          	li	a1,203
ffffffffc02010ac:	00002517          	auipc	a0,0x2
ffffffffc02010b0:	8d450513          	addi	a0,a0,-1836 # ffffffffc0202980 <commands+0x700>
ffffffffc02010b4:	b3cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc02010b8:	00002697          	auipc	a3,0x2
ffffffffc02010bc:	a0868693          	addi	a3,a3,-1528 # ffffffffc0202ac0 <commands+0x840>
ffffffffc02010c0:	00002617          	auipc	a2,0x2
ffffffffc02010c4:	8a860613          	addi	a2,a2,-1880 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02010c8:	0c200593          	li	a1,194
ffffffffc02010cc:	00002517          	auipc	a0,0x2
ffffffffc02010d0:	8b450513          	addi	a0,a0,-1868 # ffffffffc0202980 <commands+0x700>
ffffffffc02010d4:	b1cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(p0 != NULL);
ffffffffc02010d8:	00002697          	auipc	a3,0x2
ffffffffc02010dc:	a7868693          	addi	a3,a3,-1416 # ffffffffc0202b50 <commands+0x8d0>
ffffffffc02010e0:	00002617          	auipc	a2,0x2
ffffffffc02010e4:	88860613          	addi	a2,a2,-1912 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02010e8:	0f800593          	li	a1,248
ffffffffc02010ec:	00002517          	auipc	a0,0x2
ffffffffc02010f0:	89450513          	addi	a0,a0,-1900 # ffffffffc0202980 <commands+0x700>
ffffffffc02010f4:	afcff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(nr_free == 0);
ffffffffc02010f8:	00002697          	auipc	a3,0x2
ffffffffc02010fc:	a4868693          	addi	a3,a3,-1464 # ffffffffc0202b40 <commands+0x8c0>
ffffffffc0201100:	00002617          	auipc	a2,0x2
ffffffffc0201104:	86860613          	addi	a2,a2,-1944 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201108:	0df00593          	li	a1,223
ffffffffc020110c:	00002517          	auipc	a0,0x2
ffffffffc0201110:	87450513          	addi	a0,a0,-1932 # ffffffffc0202980 <commands+0x700>
ffffffffc0201114:	adcff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0201118:	00002697          	auipc	a3,0x2
ffffffffc020111c:	9c868693          	addi	a3,a3,-1592 # ffffffffc0202ae0 <commands+0x860>
ffffffffc0201120:	00002617          	auipc	a2,0x2
ffffffffc0201124:	84860613          	addi	a2,a2,-1976 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201128:	0dd00593          	li	a1,221
ffffffffc020112c:	00002517          	auipc	a0,0x2
ffffffffc0201130:	85450513          	addi	a0,a0,-1964 # ffffffffc0202980 <commands+0x700>
ffffffffc0201134:	abcff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert((p = alloc_page()) == p0);
ffffffffc0201138:	00002697          	auipc	a3,0x2
ffffffffc020113c:	9e868693          	addi	a3,a3,-1560 # ffffffffc0202b20 <commands+0x8a0>
ffffffffc0201140:	00002617          	auipc	a2,0x2
ffffffffc0201144:	82860613          	addi	a2,a2,-2008 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201148:	0dc00593          	li	a1,220
ffffffffc020114c:	00002517          	auipc	a0,0x2
ffffffffc0201150:	83450513          	addi	a0,a0,-1996 # ffffffffc0202980 <commands+0x700>
ffffffffc0201154:	a9cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0201158:	00002697          	auipc	a3,0x2
ffffffffc020115c:	86068693          	addi	a3,a3,-1952 # ffffffffc02029b8 <commands+0x738>
ffffffffc0201160:	00002617          	auipc	a2,0x2
ffffffffc0201164:	80860613          	addi	a2,a2,-2040 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201168:	0b900593          	li	a1,185
ffffffffc020116c:	00002517          	auipc	a0,0x2
ffffffffc0201170:	81450513          	addi	a0,a0,-2028 # ffffffffc0202980 <commands+0x700>
ffffffffc0201174:	a7cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0201178:	00002697          	auipc	a3,0x2
ffffffffc020117c:	96868693          	addi	a3,a3,-1688 # ffffffffc0202ae0 <commands+0x860>
ffffffffc0201180:	00001617          	auipc	a2,0x1
ffffffffc0201184:	7e860613          	addi	a2,a2,2024 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201188:	0d600593          	li	a1,214
ffffffffc020118c:	00001517          	auipc	a0,0x1
ffffffffc0201190:	7f450513          	addi	a0,a0,2036 # ffffffffc0202980 <commands+0x700>
ffffffffc0201194:	a5cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0201198:	00002697          	auipc	a3,0x2
ffffffffc020119c:	86068693          	addi	a3,a3,-1952 # ffffffffc02029f8 <commands+0x778>
ffffffffc02011a0:	00001617          	auipc	a2,0x1
ffffffffc02011a4:	7c860613          	addi	a2,a2,1992 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02011a8:	0d400593          	li	a1,212
ffffffffc02011ac:	00001517          	auipc	a0,0x1
ffffffffc02011b0:	7d450513          	addi	a0,a0,2004 # ffffffffc0202980 <commands+0x700>
ffffffffc02011b4:	a3cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02011b8:	00002697          	auipc	a3,0x2
ffffffffc02011bc:	82068693          	addi	a3,a3,-2016 # ffffffffc02029d8 <commands+0x758>
ffffffffc02011c0:	00001617          	auipc	a2,0x1
ffffffffc02011c4:	7a860613          	addi	a2,a2,1960 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02011c8:	0d300593          	li	a1,211
ffffffffc02011cc:	00001517          	auipc	a0,0x1
ffffffffc02011d0:	7b450513          	addi	a0,a0,1972 # ffffffffc0202980 <commands+0x700>
ffffffffc02011d4:	a1cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02011d8:	00002697          	auipc	a3,0x2
ffffffffc02011dc:	82068693          	addi	a3,a3,-2016 # ffffffffc02029f8 <commands+0x778>
ffffffffc02011e0:	00001617          	auipc	a2,0x1
ffffffffc02011e4:	78860613          	addi	a2,a2,1928 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02011e8:	0bb00593          	li	a1,187
ffffffffc02011ec:	00001517          	auipc	a0,0x1
ffffffffc02011f0:	79450513          	addi	a0,a0,1940 # ffffffffc0202980 <commands+0x700>
ffffffffc02011f4:	9fcff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(count == 0);
ffffffffc02011f8:	00002697          	auipc	a3,0x2
ffffffffc02011fc:	aa868693          	addi	a3,a3,-1368 # ffffffffc0202ca0 <commands+0xa20>
ffffffffc0201200:	00001617          	auipc	a2,0x1
ffffffffc0201204:	76860613          	addi	a2,a2,1896 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201208:	12500593          	li	a1,293
ffffffffc020120c:	00001517          	auipc	a0,0x1
ffffffffc0201210:	77450513          	addi	a0,a0,1908 # ffffffffc0202980 <commands+0x700>
ffffffffc0201214:	9dcff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(nr_free == 0);
ffffffffc0201218:	00002697          	auipc	a3,0x2
ffffffffc020121c:	92868693          	addi	a3,a3,-1752 # ffffffffc0202b40 <commands+0x8c0>
ffffffffc0201220:	00001617          	auipc	a2,0x1
ffffffffc0201224:	74860613          	addi	a2,a2,1864 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201228:	11a00593          	li	a1,282
ffffffffc020122c:	00001517          	auipc	a0,0x1
ffffffffc0201230:	75450513          	addi	a0,a0,1876 # ffffffffc0202980 <commands+0x700>
ffffffffc0201234:	9bcff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0201238:	00002697          	auipc	a3,0x2
ffffffffc020123c:	8a868693          	addi	a3,a3,-1880 # ffffffffc0202ae0 <commands+0x860>
ffffffffc0201240:	00001617          	auipc	a2,0x1
ffffffffc0201244:	72860613          	addi	a2,a2,1832 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201248:	11800593          	li	a1,280
ffffffffc020124c:	00001517          	auipc	a0,0x1
ffffffffc0201250:	73450513          	addi	a0,a0,1844 # ffffffffc0202980 <commands+0x700>
ffffffffc0201254:	99cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0201258:	00002697          	auipc	a3,0x2
ffffffffc020125c:	84868693          	addi	a3,a3,-1976 # ffffffffc0202aa0 <commands+0x820>
ffffffffc0201260:	00001617          	auipc	a2,0x1
ffffffffc0201264:	70860613          	addi	a2,a2,1800 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201268:	0c100593          	li	a1,193
ffffffffc020126c:	00001517          	auipc	a0,0x1
ffffffffc0201270:	71450513          	addi	a0,a0,1812 # ffffffffc0202980 <commands+0x700>
ffffffffc0201274:	97cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert((p0 = alloc_pages(2)) == p2 + 1);
ffffffffc0201278:	00002697          	auipc	a3,0x2
ffffffffc020127c:	9e868693          	addi	a3,a3,-1560 # ffffffffc0202c60 <commands+0x9e0>
ffffffffc0201280:	00001617          	auipc	a2,0x1
ffffffffc0201284:	6e860613          	addi	a2,a2,1768 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201288:	11200593          	li	a1,274
ffffffffc020128c:	00001517          	auipc	a0,0x1
ffffffffc0201290:	6f450513          	addi	a0,a0,1780 # ffffffffc0202980 <commands+0x700>
ffffffffc0201294:	95cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert((p0 = alloc_page()) == p2 - 1);
ffffffffc0201298:	00002697          	auipc	a3,0x2
ffffffffc020129c:	9a868693          	addi	a3,a3,-1624 # ffffffffc0202c40 <commands+0x9c0>
ffffffffc02012a0:	00001617          	auipc	a2,0x1
ffffffffc02012a4:	6c860613          	addi	a2,a2,1736 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02012a8:	11000593          	li	a1,272
ffffffffc02012ac:	00001517          	auipc	a0,0x1
ffffffffc02012b0:	6d450513          	addi	a0,a0,1748 # ffffffffc0202980 <commands+0x700>
ffffffffc02012b4:	93cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(PageProperty(p1) && p1->property == 3);
ffffffffc02012b8:	00002697          	auipc	a3,0x2
ffffffffc02012bc:	96068693          	addi	a3,a3,-1696 # ffffffffc0202c18 <commands+0x998>
ffffffffc02012c0:	00001617          	auipc	a2,0x1
ffffffffc02012c4:	6a860613          	addi	a2,a2,1704 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02012c8:	10e00593          	li	a1,270
ffffffffc02012cc:	00001517          	auipc	a0,0x1
ffffffffc02012d0:	6b450513          	addi	a0,a0,1716 # ffffffffc0202980 <commands+0x700>
ffffffffc02012d4:	91cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(PageProperty(p0) && p0->property == 1);
ffffffffc02012d8:	00002697          	auipc	a3,0x2
ffffffffc02012dc:	91868693          	addi	a3,a3,-1768 # ffffffffc0202bf0 <commands+0x970>
ffffffffc02012e0:	00001617          	auipc	a2,0x1
ffffffffc02012e4:	68860613          	addi	a2,a2,1672 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02012e8:	10d00593          	li	a1,269
ffffffffc02012ec:	00001517          	auipc	a0,0x1
ffffffffc02012f0:	69450513          	addi	a0,a0,1684 # ffffffffc0202980 <commands+0x700>
ffffffffc02012f4:	8fcff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(p0 + 2 == p1);
ffffffffc02012f8:	00002697          	auipc	a3,0x2
ffffffffc02012fc:	8e868693          	addi	a3,a3,-1816 # ffffffffc0202be0 <commands+0x960>
ffffffffc0201300:	00001617          	auipc	a2,0x1
ffffffffc0201304:	66860613          	addi	a2,a2,1640 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201308:	10800593          	li	a1,264
ffffffffc020130c:	00001517          	auipc	a0,0x1
ffffffffc0201310:	67450513          	addi	a0,a0,1652 # ffffffffc0202980 <commands+0x700>
ffffffffc0201314:	8dcff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0201318:	00001697          	auipc	a3,0x1
ffffffffc020131c:	7c868693          	addi	a3,a3,1992 # ffffffffc0202ae0 <commands+0x860>
ffffffffc0201320:	00001617          	auipc	a2,0x1
ffffffffc0201324:	64860613          	addi	a2,a2,1608 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201328:	10700593          	li	a1,263
ffffffffc020132c:	00001517          	auipc	a0,0x1
ffffffffc0201330:	65450513          	addi	a0,a0,1620 # ffffffffc0202980 <commands+0x700>
ffffffffc0201334:	8bcff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert((p1 = alloc_pages(3)) != NULL);
ffffffffc0201338:	00002697          	auipc	a3,0x2
ffffffffc020133c:	88868693          	addi	a3,a3,-1912 # ffffffffc0202bc0 <commands+0x940>
ffffffffc0201340:	00001617          	auipc	a2,0x1
ffffffffc0201344:	62860613          	addi	a2,a2,1576 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201348:	10600593          	li	a1,262
ffffffffc020134c:	00001517          	auipc	a0,0x1
ffffffffc0201350:	63450513          	addi	a0,a0,1588 # ffffffffc0202980 <commands+0x700>
ffffffffc0201354:	89cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
ffffffffc0201358:	00002697          	auipc	a3,0x2
ffffffffc020135c:	83868693          	addi	a3,a3,-1992 # ffffffffc0202b90 <commands+0x910>
ffffffffc0201360:	00001617          	auipc	a2,0x1
ffffffffc0201364:	60860613          	addi	a2,a2,1544 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201368:	10500593          	li	a1,261
ffffffffc020136c:	00001517          	auipc	a0,0x1
ffffffffc0201370:	61450513          	addi	a0,a0,1556 # ffffffffc0202980 <commands+0x700>
ffffffffc0201374:	87cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(alloc_pages(4) == NULL);
ffffffffc0201378:	00002697          	auipc	a3,0x2
ffffffffc020137c:	80068693          	addi	a3,a3,-2048 # ffffffffc0202b78 <commands+0x8f8>
ffffffffc0201380:	00001617          	auipc	a2,0x1
ffffffffc0201384:	5e860613          	addi	a2,a2,1512 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201388:	10400593          	li	a1,260
ffffffffc020138c:	00001517          	auipc	a0,0x1
ffffffffc0201390:	5f450513          	addi	a0,a0,1524 # ffffffffc0202980 <commands+0x700>
ffffffffc0201394:	85cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0201398:	00001697          	auipc	a3,0x1
ffffffffc020139c:	74868693          	addi	a3,a3,1864 # ffffffffc0202ae0 <commands+0x860>
ffffffffc02013a0:	00001617          	auipc	a2,0x1
ffffffffc02013a4:	5c860613          	addi	a2,a2,1480 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02013a8:	0fe00593          	li	a1,254
ffffffffc02013ac:	00001517          	auipc	a0,0x1
ffffffffc02013b0:	5d450513          	addi	a0,a0,1492 # ffffffffc0202980 <commands+0x700>
ffffffffc02013b4:	83cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(!PageProperty(p0));
ffffffffc02013b8:	00001697          	auipc	a3,0x1
ffffffffc02013bc:	7a868693          	addi	a3,a3,1960 # ffffffffc0202b60 <commands+0x8e0>
ffffffffc02013c0:	00001617          	auipc	a2,0x1
ffffffffc02013c4:	5a860613          	addi	a2,a2,1448 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02013c8:	0f900593          	li	a1,249
ffffffffc02013cc:	00001517          	auipc	a0,0x1
ffffffffc02013d0:	5b450513          	addi	a0,a0,1460 # ffffffffc0202980 <commands+0x700>
ffffffffc02013d4:	81cff0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc02013d8:	00002697          	auipc	a3,0x2
ffffffffc02013dc:	8a868693          	addi	a3,a3,-1880 # ffffffffc0202c80 <commands+0xa00>
ffffffffc02013e0:	00001617          	auipc	a2,0x1
ffffffffc02013e4:	58860613          	addi	a2,a2,1416 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02013e8:	11700593          	li	a1,279
ffffffffc02013ec:	00001517          	auipc	a0,0x1
ffffffffc02013f0:	59450513          	addi	a0,a0,1428 # ffffffffc0202980 <commands+0x700>
ffffffffc02013f4:	ffdfe0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(total == 0);
ffffffffc02013f8:	00002697          	auipc	a3,0x2
ffffffffc02013fc:	8b868693          	addi	a3,a3,-1864 # ffffffffc0202cb0 <commands+0xa30>
ffffffffc0201400:	00001617          	auipc	a2,0x1
ffffffffc0201404:	56860613          	addi	a2,a2,1384 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201408:	12600593          	li	a1,294
ffffffffc020140c:	00001517          	auipc	a0,0x1
ffffffffc0201410:	57450513          	addi	a0,a0,1396 # ffffffffc0202980 <commands+0x700>
ffffffffc0201414:	fddfe0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(total == nr_free_pages());
ffffffffc0201418:	00001697          	auipc	a3,0x1
ffffffffc020141c:	58068693          	addi	a3,a3,1408 # ffffffffc0202998 <commands+0x718>
ffffffffc0201420:	00001617          	auipc	a2,0x1
ffffffffc0201424:	54860613          	addi	a2,a2,1352 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201428:	0f300593          	li	a1,243
ffffffffc020142c:	00001517          	auipc	a0,0x1
ffffffffc0201430:	55450513          	addi	a0,a0,1364 # ffffffffc0202980 <commands+0x700>
ffffffffc0201434:	fbdfe0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0201438:	00001697          	auipc	a3,0x1
ffffffffc020143c:	5a068693          	addi	a3,a3,1440 # ffffffffc02029d8 <commands+0x758>
ffffffffc0201440:	00001617          	auipc	a2,0x1
ffffffffc0201444:	52860613          	addi	a2,a2,1320 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201448:	0ba00593          	li	a1,186
ffffffffc020144c:	00001517          	auipc	a0,0x1
ffffffffc0201450:	53450513          	addi	a0,a0,1332 # ffffffffc0202980 <commands+0x700>
ffffffffc0201454:	f9dfe0ef          	jal	ra,ffffffffc02003f0 <__panic>

ffffffffc0201458 <default_free_pages>:
default_free_pages(struct Page *base, size_t n) {
ffffffffc0201458:	1141                	addi	sp,sp,-16
ffffffffc020145a:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc020145c:	14058a63          	beqz	a1,ffffffffc02015b0 <default_free_pages+0x158>
    for (; p != base + n; p ++) {
ffffffffc0201460:	00259693          	slli	a3,a1,0x2
ffffffffc0201464:	96ae                	add	a3,a3,a1
ffffffffc0201466:	068e                	slli	a3,a3,0x3
ffffffffc0201468:	96aa                	add	a3,a3,a0
ffffffffc020146a:	87aa                	mv	a5,a0
ffffffffc020146c:	02d50263          	beq	a0,a3,ffffffffc0201490 <default_free_pages+0x38>
ffffffffc0201470:	6798                	ld	a4,8(a5)
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0201472:	8b05                	andi	a4,a4,1
ffffffffc0201474:	10071e63          	bnez	a4,ffffffffc0201590 <default_free_pages+0x138>
ffffffffc0201478:	6798                	ld	a4,8(a5)
ffffffffc020147a:	8b09                	andi	a4,a4,2
ffffffffc020147c:	10071a63          	bnez	a4,ffffffffc0201590 <default_free_pages+0x138>
        p->flags = 0;
ffffffffc0201480:	0007b423          	sd	zero,8(a5)



static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0201484:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc0201488:	02878793          	addi	a5,a5,40
ffffffffc020148c:	fed792e3          	bne	a5,a3,ffffffffc0201470 <default_free_pages+0x18>
    base->property = n;
ffffffffc0201490:	2581                	sext.w	a1,a1
ffffffffc0201492:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0201494:	00850893          	addi	a7,a0,8
    __op_bit(or, __NOP, nr, ((volatile unsigned long *)addr));
ffffffffc0201498:	4789                	li	a5,2
ffffffffc020149a:	40f8b02f          	amoor.d	zero,a5,(a7)
    nr_free += n;
ffffffffc020149e:	00006697          	auipc	a3,0x6
ffffffffc02014a2:	b8a68693          	addi	a3,a3,-1142 # ffffffffc0207028 <free_area>
ffffffffc02014a6:	4a98                	lw	a4,16(a3)
    return list->next == list;
ffffffffc02014a8:	669c                	ld	a5,8(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc02014aa:	01850613          	addi	a2,a0,24
    nr_free += n;
ffffffffc02014ae:	9db9                	addw	a1,a1,a4
ffffffffc02014b0:	ca8c                	sw	a1,16(a3)
    if (list_empty(&free_list)) {
ffffffffc02014b2:	0ad78863          	beq	a5,a3,ffffffffc0201562 <default_free_pages+0x10a>
            struct Page* page = le2page(le, page_link);
ffffffffc02014b6:	fe878713          	addi	a4,a5,-24
ffffffffc02014ba:	0006b803          	ld	a6,0(a3)
    if (list_empty(&free_list)) {
ffffffffc02014be:	4581                	li	a1,0
            if (base < page) {
ffffffffc02014c0:	00e56a63          	bltu	a0,a4,ffffffffc02014d4 <default_free_pages+0x7c>
    return listelm->next;
ffffffffc02014c4:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc02014c6:	06d70263          	beq	a4,a3,ffffffffc020152a <default_free_pages+0xd2>
    for (; p != base + n; p ++) {
ffffffffc02014ca:	87ba                	mv	a5,a4
            struct Page* page = le2page(le, page_link);
ffffffffc02014cc:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc02014d0:	fee57ae3          	bgeu	a0,a4,ffffffffc02014c4 <default_free_pages+0x6c>
ffffffffc02014d4:	c199                	beqz	a1,ffffffffc02014da <default_free_pages+0x82>
ffffffffc02014d6:	0106b023          	sd	a6,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc02014da:	6398                	ld	a4,0(a5)
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_add(list_entry_t *elm, list_entry_t *prev, list_entry_t *next) {
    prev->next = next->prev = elm;
ffffffffc02014dc:	e390                	sd	a2,0(a5)
ffffffffc02014de:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc02014e0:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc02014e2:	ed18                	sd	a4,24(a0)
    if (le != &free_list) {
ffffffffc02014e4:	02d70063          	beq	a4,a3,ffffffffc0201504 <default_free_pages+0xac>
        if (p + p->property == base) {
ffffffffc02014e8:	ff872803          	lw	a6,-8(a4)
        p = le2page(le, page_link);
ffffffffc02014ec:	fe870593          	addi	a1,a4,-24
        if (p + p->property == base) {
ffffffffc02014f0:	02081613          	slli	a2,a6,0x20
ffffffffc02014f4:	9201                	srli	a2,a2,0x20
ffffffffc02014f6:	00261793          	slli	a5,a2,0x2
ffffffffc02014fa:	97b2                	add	a5,a5,a2
ffffffffc02014fc:	078e                	slli	a5,a5,0x3
ffffffffc02014fe:	97ae                	add	a5,a5,a1
ffffffffc0201500:	02f50f63          	beq	a0,a5,ffffffffc020153e <default_free_pages+0xe6>
    return listelm->next;
ffffffffc0201504:	7118                	ld	a4,32(a0)
    if (le != &free_list) {
ffffffffc0201506:	00d70f63          	beq	a4,a3,ffffffffc0201524 <default_free_pages+0xcc>
        if (base + base->property == p) {
ffffffffc020150a:	490c                	lw	a1,16(a0)
        p = le2page(le, page_link);
ffffffffc020150c:	fe870693          	addi	a3,a4,-24
        if (base + base->property == p) {
ffffffffc0201510:	02059613          	slli	a2,a1,0x20
ffffffffc0201514:	9201                	srli	a2,a2,0x20
ffffffffc0201516:	00261793          	slli	a5,a2,0x2
ffffffffc020151a:	97b2                	add	a5,a5,a2
ffffffffc020151c:	078e                	slli	a5,a5,0x3
ffffffffc020151e:	97aa                	add	a5,a5,a0
ffffffffc0201520:	04f68863          	beq	a3,a5,ffffffffc0201570 <default_free_pages+0x118>
}
ffffffffc0201524:	60a2                	ld	ra,8(sp)
ffffffffc0201526:	0141                	addi	sp,sp,16
ffffffffc0201528:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc020152a:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc020152c:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc020152e:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc0201530:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc0201532:	02d70563          	beq	a4,a3,ffffffffc020155c <default_free_pages+0x104>
    prev->next = next->prev = elm;
ffffffffc0201536:	8832                	mv	a6,a2
ffffffffc0201538:	4585                	li	a1,1
    for (; p != base + n; p ++) {
ffffffffc020153a:	87ba                	mv	a5,a4
ffffffffc020153c:	bf41                	j	ffffffffc02014cc <default_free_pages+0x74>
            p->property += base->property;
ffffffffc020153e:	491c                	lw	a5,16(a0)
ffffffffc0201540:	0107883b          	addw	a6,a5,a6
ffffffffc0201544:	ff072c23          	sw	a6,-8(a4)
    __op_bit(and, __NOT, nr, ((volatile unsigned long *)addr));
ffffffffc0201548:	57f5                	li	a5,-3
ffffffffc020154a:	60f8b02f          	amoand.d	zero,a5,(a7)
    __list_del(listelm->prev, listelm->next);
ffffffffc020154e:	6d10                	ld	a2,24(a0)
ffffffffc0201550:	711c                	ld	a5,32(a0)
            base = p;
ffffffffc0201552:	852e                	mv	a0,a1
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc0201554:	e61c                	sd	a5,8(a2)
    return listelm->next;
ffffffffc0201556:	6718                	ld	a4,8(a4)
    next->prev = prev;
ffffffffc0201558:	e390                	sd	a2,0(a5)
ffffffffc020155a:	b775                	j	ffffffffc0201506 <default_free_pages+0xae>
ffffffffc020155c:	e290                	sd	a2,0(a3)
        while ((le = list_next(le)) != &free_list) {
ffffffffc020155e:	873e                	mv	a4,a5
ffffffffc0201560:	b761                	j	ffffffffc02014e8 <default_free_pages+0x90>
}
ffffffffc0201562:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0201564:	e390                	sd	a2,0(a5)
ffffffffc0201566:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0201568:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc020156a:	ed1c                	sd	a5,24(a0)
ffffffffc020156c:	0141                	addi	sp,sp,16
ffffffffc020156e:	8082                	ret
            base->property += p->property;
ffffffffc0201570:	ff872783          	lw	a5,-8(a4)
ffffffffc0201574:	ff070693          	addi	a3,a4,-16
ffffffffc0201578:	9dbd                	addw	a1,a1,a5
ffffffffc020157a:	c90c                	sw	a1,16(a0)
ffffffffc020157c:	57f5                	li	a5,-3
ffffffffc020157e:	60f6b02f          	amoand.d	zero,a5,(a3)
    __list_del(listelm->prev, listelm->next);
ffffffffc0201582:	6314                	ld	a3,0(a4)
ffffffffc0201584:	671c                	ld	a5,8(a4)
}
ffffffffc0201586:	60a2                	ld	ra,8(sp)
    prev->next = next;
ffffffffc0201588:	e69c                	sd	a5,8(a3)
    next->prev = prev;
ffffffffc020158a:	e394                	sd	a3,0(a5)
ffffffffc020158c:	0141                	addi	sp,sp,16
ffffffffc020158e:	8082                	ret
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0201590:	00001697          	auipc	a3,0x1
ffffffffc0201594:	73868693          	addi	a3,a3,1848 # ffffffffc0202cc8 <commands+0xa48>
ffffffffc0201598:	00001617          	auipc	a2,0x1
ffffffffc020159c:	3d060613          	addi	a2,a2,976 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02015a0:	08300593          	li	a1,131
ffffffffc02015a4:	00001517          	auipc	a0,0x1
ffffffffc02015a8:	3dc50513          	addi	a0,a0,988 # ffffffffc0202980 <commands+0x700>
ffffffffc02015ac:	e45fe0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(n > 0);
ffffffffc02015b0:	00001697          	auipc	a3,0x1
ffffffffc02015b4:	71068693          	addi	a3,a3,1808 # ffffffffc0202cc0 <commands+0xa40>
ffffffffc02015b8:	00001617          	auipc	a2,0x1
ffffffffc02015bc:	3b060613          	addi	a2,a2,944 # ffffffffc0202968 <commands+0x6e8>
ffffffffc02015c0:	08000593          	li	a1,128
ffffffffc02015c4:	00001517          	auipc	a0,0x1
ffffffffc02015c8:	3bc50513          	addi	a0,a0,956 # ffffffffc0202980 <commands+0x700>
ffffffffc02015cc:	e25fe0ef          	jal	ra,ffffffffc02003f0 <__panic>

ffffffffc02015d0 <default_alloc_pages>:
    assert(n > 0);
ffffffffc02015d0:	c959                	beqz	a0,ffffffffc0201666 <default_alloc_pages+0x96>
    if (n > nr_free) {
ffffffffc02015d2:	00006597          	auipc	a1,0x6
ffffffffc02015d6:	a5658593          	addi	a1,a1,-1450 # ffffffffc0207028 <free_area>
ffffffffc02015da:	0105a803          	lw	a6,16(a1)
ffffffffc02015de:	862a                	mv	a2,a0
ffffffffc02015e0:	02081793          	slli	a5,a6,0x20
ffffffffc02015e4:	9381                	srli	a5,a5,0x20
ffffffffc02015e6:	00a7ee63          	bltu	a5,a0,ffffffffc0201602 <default_alloc_pages+0x32>
    list_entry_t *le = &free_list;
ffffffffc02015ea:	87ae                	mv	a5,a1
ffffffffc02015ec:	a801                	j	ffffffffc02015fc <default_alloc_pages+0x2c>
        if (p->property >= n) {
ffffffffc02015ee:	ff87a703          	lw	a4,-8(a5)
ffffffffc02015f2:	02071693          	slli	a3,a4,0x20
ffffffffc02015f6:	9281                	srli	a3,a3,0x20
ffffffffc02015f8:	00c6f763          	bgeu	a3,a2,ffffffffc0201606 <default_alloc_pages+0x36>
    return listelm->next;
ffffffffc02015fc:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &free_list) {
ffffffffc02015fe:	feb798e3          	bne	a5,a1,ffffffffc02015ee <default_alloc_pages+0x1e>
        return NULL;
ffffffffc0201602:	4501                	li	a0,0
}
ffffffffc0201604:	8082                	ret
    return listelm->prev;
ffffffffc0201606:	0007b883          	ld	a7,0(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc020160a:	0087b303          	ld	t1,8(a5)
        struct Page *p = le2page(le, page_link);
ffffffffc020160e:	fe878513          	addi	a0,a5,-24
            p->property = page->property - n;
ffffffffc0201612:	00060e1b          	sext.w	t3,a2
    prev->next = next;
ffffffffc0201616:	0068b423          	sd	t1,8(a7)
    next->prev = prev;
ffffffffc020161a:	01133023          	sd	a7,0(t1)
        if (page->property > n) {
ffffffffc020161e:	02d67b63          	bgeu	a2,a3,ffffffffc0201654 <default_alloc_pages+0x84>
            struct Page *p = page + n;
ffffffffc0201622:	00261693          	slli	a3,a2,0x2
ffffffffc0201626:	96b2                	add	a3,a3,a2
ffffffffc0201628:	068e                	slli	a3,a3,0x3
ffffffffc020162a:	96aa                	add	a3,a3,a0
            p->property = page->property - n;
ffffffffc020162c:	41c7073b          	subw	a4,a4,t3
ffffffffc0201630:	ca98                	sw	a4,16(a3)
    __op_bit(or, __NOP, nr, ((volatile unsigned long *)addr));
ffffffffc0201632:	00868613          	addi	a2,a3,8
ffffffffc0201636:	4709                	li	a4,2
ffffffffc0201638:	40e6302f          	amoor.d	zero,a4,(a2)
    __list_add(elm, listelm, listelm->next);
ffffffffc020163c:	0088b703          	ld	a4,8(a7)
            list_add(prev, &(p->page_link));
ffffffffc0201640:	01868613          	addi	a2,a3,24
        nr_free -= n;
ffffffffc0201644:	0105a803          	lw	a6,16(a1)
    prev->next = next->prev = elm;
ffffffffc0201648:	e310                	sd	a2,0(a4)
ffffffffc020164a:	00c8b423          	sd	a2,8(a7)
    elm->next = next;
ffffffffc020164e:	f298                	sd	a4,32(a3)
    elm->prev = prev;
ffffffffc0201650:	0116bc23          	sd	a7,24(a3)
ffffffffc0201654:	41c8083b          	subw	a6,a6,t3
ffffffffc0201658:	0105a823          	sw	a6,16(a1)
    __op_bit(and, __NOT, nr, ((volatile unsigned long *)addr));
ffffffffc020165c:	5775                	li	a4,-3
ffffffffc020165e:	17c1                	addi	a5,a5,-16
ffffffffc0201660:	60e7b02f          	amoand.d	zero,a4,(a5)
}
ffffffffc0201664:	8082                	ret
default_alloc_pages(size_t n) {
ffffffffc0201666:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc0201668:	00001697          	auipc	a3,0x1
ffffffffc020166c:	65868693          	addi	a3,a3,1624 # ffffffffc0202cc0 <commands+0xa40>
ffffffffc0201670:	00001617          	auipc	a2,0x1
ffffffffc0201674:	2f860613          	addi	a2,a2,760 # ffffffffc0202968 <commands+0x6e8>
ffffffffc0201678:	06200593          	li	a1,98
ffffffffc020167c:	00001517          	auipc	a0,0x1
ffffffffc0201680:	30450513          	addi	a0,a0,772 # ffffffffc0202980 <commands+0x700>
default_alloc_pages(size_t n) {
ffffffffc0201684:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0201686:	d6bfe0ef          	jal	ra,ffffffffc02003f0 <__panic>

ffffffffc020168a <default_init_memmap>:
default_init_memmap(struct Page *base, size_t n) {
ffffffffc020168a:	1141                	addi	sp,sp,-16
ffffffffc020168c:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc020168e:	c9e1                	beqz	a1,ffffffffc020175e <default_init_memmap+0xd4>
    for (; p != base + n; p ++) {
ffffffffc0201690:	00259693          	slli	a3,a1,0x2
ffffffffc0201694:	96ae                	add	a3,a3,a1
ffffffffc0201696:	068e                	slli	a3,a3,0x3
ffffffffc0201698:	96aa                	add	a3,a3,a0
ffffffffc020169a:	87aa                	mv	a5,a0
ffffffffc020169c:	00d50f63          	beq	a0,a3,ffffffffc02016ba <default_init_memmap+0x30>
    return (((*(volatile unsigned long *)addr) >> nr) & 1);
ffffffffc02016a0:	6798                	ld	a4,8(a5)
        assert(PageReserved(p));
ffffffffc02016a2:	8b05                	andi	a4,a4,1
ffffffffc02016a4:	cf49                	beqz	a4,ffffffffc020173e <default_init_memmap+0xb4>
        p->flags = p->property = 0;
ffffffffc02016a6:	0007a823          	sw	zero,16(a5)
ffffffffc02016aa:	0007b423          	sd	zero,8(a5)
ffffffffc02016ae:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc02016b2:	02878793          	addi	a5,a5,40
ffffffffc02016b6:	fed795e3          	bne	a5,a3,ffffffffc02016a0 <default_init_memmap+0x16>
    base->property = n;
ffffffffc02016ba:	2581                	sext.w	a1,a1
ffffffffc02016bc:	c90c                	sw	a1,16(a0)
    __op_bit(or, __NOP, nr, ((volatile unsigned long *)addr));
ffffffffc02016be:	4789                	li	a5,2
ffffffffc02016c0:	00850713          	addi	a4,a0,8
ffffffffc02016c4:	40f7302f          	amoor.d	zero,a5,(a4)
    nr_free += n;
ffffffffc02016c8:	00006697          	auipc	a3,0x6
ffffffffc02016cc:	96068693          	addi	a3,a3,-1696 # ffffffffc0207028 <free_area>
ffffffffc02016d0:	4a98                	lw	a4,16(a3)
    return list->next == list;
ffffffffc02016d2:	669c                	ld	a5,8(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc02016d4:	01850613          	addi	a2,a0,24
    nr_free += n;
ffffffffc02016d8:	9db9                	addw	a1,a1,a4
ffffffffc02016da:	ca8c                	sw	a1,16(a3)
    if (list_empty(&free_list)) {
ffffffffc02016dc:	04d78a63          	beq	a5,a3,ffffffffc0201730 <default_init_memmap+0xa6>
            struct Page* page = le2page(le, page_link);
ffffffffc02016e0:	fe878713          	addi	a4,a5,-24
ffffffffc02016e4:	0006b803          	ld	a6,0(a3)
    if (list_empty(&free_list)) {
ffffffffc02016e8:	4581                	li	a1,0
            if (base < page) {
ffffffffc02016ea:	00e56a63          	bltu	a0,a4,ffffffffc02016fe <default_init_memmap+0x74>
    return listelm->next;
ffffffffc02016ee:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc02016f0:	02d70263          	beq	a4,a3,ffffffffc0201714 <default_init_memmap+0x8a>
    for (; p != base + n; p ++) {
ffffffffc02016f4:	87ba                	mv	a5,a4
            struct Page* page = le2page(le, page_link);
ffffffffc02016f6:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc02016fa:	fee57ae3          	bgeu	a0,a4,ffffffffc02016ee <default_init_memmap+0x64>
ffffffffc02016fe:	c199                	beqz	a1,ffffffffc0201704 <default_init_memmap+0x7a>
ffffffffc0201700:	0106b023          	sd	a6,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc0201704:	6398                	ld	a4,0(a5)
}
ffffffffc0201706:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0201708:	e390                	sd	a2,0(a5)
ffffffffc020170a:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc020170c:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc020170e:	ed18                	sd	a4,24(a0)
ffffffffc0201710:	0141                	addi	sp,sp,16
ffffffffc0201712:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc0201714:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0201716:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc0201718:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc020171a:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc020171c:	00d70663          	beq	a4,a3,ffffffffc0201728 <default_init_memmap+0x9e>
    prev->next = next->prev = elm;
ffffffffc0201720:	8832                	mv	a6,a2
ffffffffc0201722:	4585                	li	a1,1
    for (; p != base + n; p ++) {
ffffffffc0201724:	87ba                	mv	a5,a4
ffffffffc0201726:	bfc1                	j	ffffffffc02016f6 <default_init_memmap+0x6c>
}
ffffffffc0201728:	60a2                	ld	ra,8(sp)
ffffffffc020172a:	e290                	sd	a2,0(a3)
ffffffffc020172c:	0141                	addi	sp,sp,16
ffffffffc020172e:	8082                	ret
ffffffffc0201730:	60a2                	ld	ra,8(sp)
ffffffffc0201732:	e390                	sd	a2,0(a5)
ffffffffc0201734:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0201736:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0201738:	ed1c                	sd	a5,24(a0)
ffffffffc020173a:	0141                	addi	sp,sp,16
ffffffffc020173c:	8082                	ret
        assert(PageReserved(p));
ffffffffc020173e:	00001697          	auipc	a3,0x1
ffffffffc0201742:	5b268693          	addi	a3,a3,1458 # ffffffffc0202cf0 <commands+0xa70>
ffffffffc0201746:	00001617          	auipc	a2,0x1
ffffffffc020174a:	22260613          	addi	a2,a2,546 # ffffffffc0202968 <commands+0x6e8>
ffffffffc020174e:	04900593          	li	a1,73
ffffffffc0201752:	00001517          	auipc	a0,0x1
ffffffffc0201756:	22e50513          	addi	a0,a0,558 # ffffffffc0202980 <commands+0x700>
ffffffffc020175a:	c97fe0ef          	jal	ra,ffffffffc02003f0 <__panic>
    assert(n > 0);
ffffffffc020175e:	00001697          	auipc	a3,0x1
ffffffffc0201762:	56268693          	addi	a3,a3,1378 # ffffffffc0202cc0 <commands+0xa40>
ffffffffc0201766:	00001617          	auipc	a2,0x1
ffffffffc020176a:	20260613          	addi	a2,a2,514 # ffffffffc0202968 <commands+0x6e8>
ffffffffc020176e:	04600593          	li	a1,70
ffffffffc0201772:	00001517          	auipc	a0,0x1
ffffffffc0201776:	20e50513          	addi	a0,a0,526 # ffffffffc0202980 <commands+0x700>
ffffffffc020177a:	c77fe0ef          	jal	ra,ffffffffc02003f0 <__panic>

ffffffffc020177e <alloc_pages>:
#include <defs.h>
#include <intr.h>
#include <riscv.h>

static inline bool __intr_save(void) {
    if (read_csr(sstatus) & SSTATUS_SIE) {
ffffffffc020177e:	100027f3          	csrr	a5,sstatus
ffffffffc0201782:	8b89                	andi	a5,a5,2
ffffffffc0201784:	e799                	bnez	a5,ffffffffc0201792 <alloc_pages+0x14>
struct Page *alloc_pages(size_t n) {
    struct Page *page = NULL;
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        page = pmm_manager->alloc_pages(n);
ffffffffc0201786:	00006797          	auipc	a5,0x6
ffffffffc020178a:	cf27b783          	ld	a5,-782(a5) # ffffffffc0207478 <pmm_manager>
ffffffffc020178e:	6f9c                	ld	a5,24(a5)
ffffffffc0201790:	8782                	jr	a5
struct Page *alloc_pages(size_t n) {
ffffffffc0201792:	1141                	addi	sp,sp,-16
ffffffffc0201794:	e406                	sd	ra,8(sp)
ffffffffc0201796:	e022                	sd	s0,0(sp)
ffffffffc0201798:	842a                	mv	s0,a0
        intr_disable();
ffffffffc020179a:	8b8ff0ef          	jal	ra,ffffffffc0200852 <intr_disable>
        page = pmm_manager->alloc_pages(n);
ffffffffc020179e:	00006797          	auipc	a5,0x6
ffffffffc02017a2:	cda7b783          	ld	a5,-806(a5) # ffffffffc0207478 <pmm_manager>
ffffffffc02017a6:	6f9c                	ld	a5,24(a5)
ffffffffc02017a8:	8522                	mv	a0,s0
ffffffffc02017aa:	9782                	jalr	a5
ffffffffc02017ac:	842a                	mv	s0,a0
    return 0;
}

static inline void __intr_restore(bool flag) {
    if (flag) {
        intr_enable();
ffffffffc02017ae:	89eff0ef          	jal	ra,ffffffffc020084c <intr_enable>
    }
    local_intr_restore(intr_flag);
    return page;
}
ffffffffc02017b2:	60a2                	ld	ra,8(sp)
ffffffffc02017b4:	8522                	mv	a0,s0
ffffffffc02017b6:	6402                	ld	s0,0(sp)
ffffffffc02017b8:	0141                	addi	sp,sp,16
ffffffffc02017ba:	8082                	ret

ffffffffc02017bc <free_pages>:
    if (read_csr(sstatus) & SSTATUS_SIE) {
ffffffffc02017bc:	100027f3          	csrr	a5,sstatus
ffffffffc02017c0:	8b89                	andi	a5,a5,2
ffffffffc02017c2:	e799                	bnez	a5,ffffffffc02017d0 <free_pages+0x14>
// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        pmm_manager->free_pages(base, n);
ffffffffc02017c4:	00006797          	auipc	a5,0x6
ffffffffc02017c8:	cb47b783          	ld	a5,-844(a5) # ffffffffc0207478 <pmm_manager>
ffffffffc02017cc:	739c                	ld	a5,32(a5)
ffffffffc02017ce:	8782                	jr	a5
void free_pages(struct Page *base, size_t n) {
ffffffffc02017d0:	1101                	addi	sp,sp,-32
ffffffffc02017d2:	ec06                	sd	ra,24(sp)
ffffffffc02017d4:	e822                	sd	s0,16(sp)
ffffffffc02017d6:	e426                	sd	s1,8(sp)
ffffffffc02017d8:	842a                	mv	s0,a0
ffffffffc02017da:	84ae                	mv	s1,a1
        intr_disable();
ffffffffc02017dc:	876ff0ef          	jal	ra,ffffffffc0200852 <intr_disable>
        pmm_manager->free_pages(base, n);
ffffffffc02017e0:	00006797          	auipc	a5,0x6
ffffffffc02017e4:	c987b783          	ld	a5,-872(a5) # ffffffffc0207478 <pmm_manager>
ffffffffc02017e8:	739c                	ld	a5,32(a5)
ffffffffc02017ea:	85a6                	mv	a1,s1
ffffffffc02017ec:	8522                	mv	a0,s0
ffffffffc02017ee:	9782                	jalr	a5
    }
    local_intr_restore(intr_flag);
}
ffffffffc02017f0:	6442                	ld	s0,16(sp)
ffffffffc02017f2:	60e2                	ld	ra,24(sp)
ffffffffc02017f4:	64a2                	ld	s1,8(sp)
ffffffffc02017f6:	6105                	addi	sp,sp,32
        intr_enable();
ffffffffc02017f8:	854ff06f          	j	ffffffffc020084c <intr_enable>

ffffffffc02017fc <nr_free_pages>:
    if (read_csr(sstatus) & SSTATUS_SIE) {
ffffffffc02017fc:	100027f3          	csrr	a5,sstatus
ffffffffc0201800:	8b89                	andi	a5,a5,2
ffffffffc0201802:	e799                	bnez	a5,ffffffffc0201810 <nr_free_pages+0x14>
size_t nr_free_pages(void) {
    size_t ret;
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        ret = pmm_manager->nr_free_pages();
ffffffffc0201804:	00006797          	auipc	a5,0x6
ffffffffc0201808:	c747b783          	ld	a5,-908(a5) # ffffffffc0207478 <pmm_manager>
ffffffffc020180c:	779c                	ld	a5,40(a5)
ffffffffc020180e:	8782                	jr	a5
size_t nr_free_pages(void) {
ffffffffc0201810:	1141                	addi	sp,sp,-16
ffffffffc0201812:	e406                	sd	ra,8(sp)
ffffffffc0201814:	e022                	sd	s0,0(sp)
        intr_disable();
ffffffffc0201816:	83cff0ef          	jal	ra,ffffffffc0200852 <intr_disable>
        ret = pmm_manager->nr_free_pages();
ffffffffc020181a:	00006797          	auipc	a5,0x6
ffffffffc020181e:	c5e7b783          	ld	a5,-930(a5) # ffffffffc0207478 <pmm_manager>
ffffffffc0201822:	779c                	ld	a5,40(a5)
ffffffffc0201824:	9782                	jalr	a5
ffffffffc0201826:	842a                	mv	s0,a0
        intr_enable();
ffffffffc0201828:	824ff0ef          	jal	ra,ffffffffc020084c <intr_enable>
    }
    local_intr_restore(intr_flag);
    return ret;
}
ffffffffc020182c:	60a2                	ld	ra,8(sp)
ffffffffc020182e:	8522                	mv	a0,s0
ffffffffc0201830:	6402                	ld	s0,0(sp)
ffffffffc0201832:	0141                	addi	sp,sp,16
ffffffffc0201834:	8082                	ret

ffffffffc0201836 <pmm_init>:
    pmm_manager = &default_pmm_manager;
ffffffffc0201836:	00001797          	auipc	a5,0x1
ffffffffc020183a:	4e278793          	addi	a5,a5,1250 # ffffffffc0202d18 <default_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc020183e:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
    }
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc0201840:	7179                	addi	sp,sp,-48
ffffffffc0201842:	f022                	sd	s0,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201844:	00001517          	auipc	a0,0x1
ffffffffc0201848:	50c50513          	addi	a0,a0,1292 # ffffffffc0202d50 <default_pmm_manager+0x38>
    pmm_manager = &default_pmm_manager;
ffffffffc020184c:	00006417          	auipc	s0,0x6
ffffffffc0201850:	c2c40413          	addi	s0,s0,-980 # ffffffffc0207478 <pmm_manager>
void pmm_init(void) {
ffffffffc0201854:	f406                	sd	ra,40(sp)
ffffffffc0201856:	ec26                	sd	s1,24(sp)
ffffffffc0201858:	e44e                	sd	s3,8(sp)
ffffffffc020185a:	e84a                	sd	s2,16(sp)
ffffffffc020185c:	e052                	sd	s4,0(sp)
    pmm_manager = &default_pmm_manager;
ffffffffc020185e:	e01c                	sd	a5,0(s0)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201860:	897fe0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    pmm_manager->init();
ffffffffc0201864:	601c                	ld	a5,0(s0)
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201866:	00006497          	auipc	s1,0x6
ffffffffc020186a:	c2a48493          	addi	s1,s1,-982 # ffffffffc0207490 <va_pa_offset>
    pmm_manager->init();
ffffffffc020186e:	679c                	ld	a5,8(a5)
ffffffffc0201870:	9782                	jalr	a5
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201872:	57f5                	li	a5,-3
ffffffffc0201874:	07fa                	slli	a5,a5,0x1e
ffffffffc0201876:	e09c                	sd	a5,0(s1)
    uint64_t mem_begin = get_memory_base();
ffffffffc0201878:	fc1fe0ef          	jal	ra,ffffffffc0200838 <get_memory_base>
ffffffffc020187c:	89aa                	mv	s3,a0
    uint64_t mem_size  = get_memory_size();
ffffffffc020187e:	fc5fe0ef          	jal	ra,ffffffffc0200842 <get_memory_size>
    if (mem_size == 0) {
ffffffffc0201882:	16050163          	beqz	a0,ffffffffc02019e4 <pmm_init+0x1ae>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0201886:	892a                	mv	s2,a0
    cprintf("physcial memory map:\n");
ffffffffc0201888:	00001517          	auipc	a0,0x1
ffffffffc020188c:	51050513          	addi	a0,a0,1296 # ffffffffc0202d98 <default_pmm_manager+0x80>
ffffffffc0201890:	867fe0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0201894:	01298a33          	add	s4,s3,s2
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n", mem_size, mem_begin,
ffffffffc0201898:	864e                	mv	a2,s3
ffffffffc020189a:	fffa0693          	addi	a3,s4,-1
ffffffffc020189e:	85ca                	mv	a1,s2
ffffffffc02018a0:	00001517          	auipc	a0,0x1
ffffffffc02018a4:	51050513          	addi	a0,a0,1296 # ffffffffc0202db0 <default_pmm_manager+0x98>
ffffffffc02018a8:	84ffe0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc02018ac:	c80007b7          	lui	a5,0xc8000
ffffffffc02018b0:	8652                	mv	a2,s4
ffffffffc02018b2:	0d47e863          	bltu	a5,s4,ffffffffc0201982 <pmm_init+0x14c>
ffffffffc02018b6:	00007797          	auipc	a5,0x7
ffffffffc02018ba:	be978793          	addi	a5,a5,-1047 # ffffffffc020849f <end+0xfff>
ffffffffc02018be:	757d                	lui	a0,0xfffff
ffffffffc02018c0:	8d7d                	and	a0,a0,a5
ffffffffc02018c2:	8231                	srli	a2,a2,0xc
ffffffffc02018c4:	00006597          	auipc	a1,0x6
ffffffffc02018c8:	ba458593          	addi	a1,a1,-1116 # ffffffffc0207468 <npage>
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc02018cc:	00006817          	auipc	a6,0x6
ffffffffc02018d0:	ba480813          	addi	a6,a6,-1116 # ffffffffc0207470 <pages>
    npage = maxpa / PGSIZE;
ffffffffc02018d4:	e190                	sd	a2,0(a1)
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc02018d6:	00a83023          	sd	a0,0(a6)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc02018da:	000807b7          	lui	a5,0x80
ffffffffc02018de:	02f60663          	beq	a2,a5,ffffffffc020190a <pmm_init+0xd4>
ffffffffc02018e2:	4701                	li	a4,0
ffffffffc02018e4:	4781                	li	a5,0
ffffffffc02018e6:	4305                	li	t1,1
ffffffffc02018e8:	fff808b7          	lui	a7,0xfff80
        SetPageReserved(pages + i);
ffffffffc02018ec:	953a                	add	a0,a0,a4
ffffffffc02018ee:	00850693          	addi	a3,a0,8 # fffffffffffff008 <end+0x3fdf7b68>
ffffffffc02018f2:	4066b02f          	amoor.d	zero,t1,(a3)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc02018f6:	6190                	ld	a2,0(a1)
ffffffffc02018f8:	0785                	addi	a5,a5,1
        SetPageReserved(pages + i);
ffffffffc02018fa:	00083503          	ld	a0,0(a6)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc02018fe:	011606b3          	add	a3,a2,a7
ffffffffc0201902:	02870713          	addi	a4,a4,40
ffffffffc0201906:	fed7e3e3          	bltu	a5,a3,ffffffffc02018ec <pmm_init+0xb6>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc020190a:	00261693          	slli	a3,a2,0x2
ffffffffc020190e:	96b2                	add	a3,a3,a2
ffffffffc0201910:	fec007b7          	lui	a5,0xfec00
ffffffffc0201914:	97aa                	add	a5,a5,a0
ffffffffc0201916:	068e                	slli	a3,a3,0x3
ffffffffc0201918:	96be                	add	a3,a3,a5
ffffffffc020191a:	c02007b7          	lui	a5,0xc0200
ffffffffc020191e:	0af6e763          	bltu	a3,a5,ffffffffc02019cc <pmm_init+0x196>
ffffffffc0201922:	6098                	ld	a4,0(s1)
    mem_end = ROUNDDOWN(mem_end, PGSIZE);
ffffffffc0201924:	77fd                	lui	a5,0xfffff
ffffffffc0201926:	00fa75b3          	and	a1,s4,a5
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc020192a:	8e99                	sub	a3,a3,a4
    if (freemem < mem_end) {
ffffffffc020192c:	04b6ee63          	bltu	a3,a1,ffffffffc0201988 <pmm_init+0x152>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc0201930:	601c                	ld	a5,0(s0)
ffffffffc0201932:	7b9c                	ld	a5,48(a5)
ffffffffc0201934:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc0201936:	00001517          	auipc	a0,0x1
ffffffffc020193a:	50250513          	addi	a0,a0,1282 # ffffffffc0202e38 <default_pmm_manager+0x120>
ffffffffc020193e:	fb8fe0ef          	jal	ra,ffffffffc02000f6 <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc0201942:	00004597          	auipc	a1,0x4
ffffffffc0201946:	6be58593          	addi	a1,a1,1726 # ffffffffc0206000 <boot_page_table_sv39>
ffffffffc020194a:	00006797          	auipc	a5,0x6
ffffffffc020194e:	b2b7bf23          	sd	a1,-1218(a5) # ffffffffc0207488 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc0201952:	c02007b7          	lui	a5,0xc0200
ffffffffc0201956:	0af5e363          	bltu	a1,a5,ffffffffc02019fc <pmm_init+0x1c6>
ffffffffc020195a:	6090                	ld	a2,0(s1)
}
ffffffffc020195c:	7402                	ld	s0,32(sp)
ffffffffc020195e:	70a2                	ld	ra,40(sp)
ffffffffc0201960:	64e2                	ld	s1,24(sp)
ffffffffc0201962:	6942                	ld	s2,16(sp)
ffffffffc0201964:	69a2                	ld	s3,8(sp)
ffffffffc0201966:	6a02                	ld	s4,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc0201968:	40c58633          	sub	a2,a1,a2
ffffffffc020196c:	00006797          	auipc	a5,0x6
ffffffffc0201970:	b0c7ba23          	sd	a2,-1260(a5) # ffffffffc0207480 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0201974:	00001517          	auipc	a0,0x1
ffffffffc0201978:	4e450513          	addi	a0,a0,1252 # ffffffffc0202e58 <default_pmm_manager+0x140>
}
ffffffffc020197c:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc020197e:	f78fe06f          	j	ffffffffc02000f6 <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0201982:	c8000637          	lui	a2,0xc8000
ffffffffc0201986:	bf05                	j	ffffffffc02018b6 <pmm_init+0x80>
    mem_begin = ROUNDUP(freemem, PGSIZE);
ffffffffc0201988:	6705                	lui	a4,0x1
ffffffffc020198a:	177d                	addi	a4,a4,-1
ffffffffc020198c:	96ba                	add	a3,a3,a4
ffffffffc020198e:	8efd                	and	a3,a3,a5
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc0201990:	00c6d793          	srli	a5,a3,0xc
ffffffffc0201994:	02c7f063          	bgeu	a5,a2,ffffffffc02019b4 <pmm_init+0x17e>
    pmm_manager->init_memmap(base, n);
ffffffffc0201998:	6010                	ld	a2,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc020199a:	fff80737          	lui	a4,0xfff80
ffffffffc020199e:	973e                	add	a4,a4,a5
ffffffffc02019a0:	00271793          	slli	a5,a4,0x2
ffffffffc02019a4:	97ba                	add	a5,a5,a4
ffffffffc02019a6:	6a18                	ld	a4,16(a2)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
ffffffffc02019a8:	8d95                	sub	a1,a1,a3
ffffffffc02019aa:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc02019ac:	81b1                	srli	a1,a1,0xc
ffffffffc02019ae:	953e                	add	a0,a0,a5
ffffffffc02019b0:	9702                	jalr	a4
}
ffffffffc02019b2:	bfbd                	j	ffffffffc0201930 <pmm_init+0xfa>
        panic("pa2page called with invalid pa");
ffffffffc02019b4:	00001617          	auipc	a2,0x1
ffffffffc02019b8:	45460613          	addi	a2,a2,1108 # ffffffffc0202e08 <default_pmm_manager+0xf0>
ffffffffc02019bc:	06b00593          	li	a1,107
ffffffffc02019c0:	00001517          	auipc	a0,0x1
ffffffffc02019c4:	46850513          	addi	a0,a0,1128 # ffffffffc0202e28 <default_pmm_manager+0x110>
ffffffffc02019c8:	a29fe0ef          	jal	ra,ffffffffc02003f0 <__panic>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc02019cc:	00001617          	auipc	a2,0x1
ffffffffc02019d0:	41460613          	addi	a2,a2,1044 # ffffffffc0202de0 <default_pmm_manager+0xc8>
ffffffffc02019d4:	07100593          	li	a1,113
ffffffffc02019d8:	00001517          	auipc	a0,0x1
ffffffffc02019dc:	3b050513          	addi	a0,a0,944 # ffffffffc0202d88 <default_pmm_manager+0x70>
ffffffffc02019e0:	a11fe0ef          	jal	ra,ffffffffc02003f0 <__panic>
        panic("DTB memory info not available");
ffffffffc02019e4:	00001617          	auipc	a2,0x1
ffffffffc02019e8:	38460613          	addi	a2,a2,900 # ffffffffc0202d68 <default_pmm_manager+0x50>
ffffffffc02019ec:	05a00593          	li	a1,90
ffffffffc02019f0:	00001517          	auipc	a0,0x1
ffffffffc02019f4:	39850513          	addi	a0,a0,920 # ffffffffc0202d88 <default_pmm_manager+0x70>
ffffffffc02019f8:	9f9fe0ef          	jal	ra,ffffffffc02003f0 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc02019fc:	86ae                	mv	a3,a1
ffffffffc02019fe:	00001617          	auipc	a2,0x1
ffffffffc0201a02:	3e260613          	addi	a2,a2,994 # ffffffffc0202de0 <default_pmm_manager+0xc8>
ffffffffc0201a06:	08c00593          	li	a1,140
ffffffffc0201a0a:	00001517          	auipc	a0,0x1
ffffffffc0201a0e:	37e50513          	addi	a0,a0,894 # ffffffffc0202d88 <default_pmm_manager+0x70>
ffffffffc0201a12:	9dffe0ef          	jal	ra,ffffffffc02003f0 <__panic>

ffffffffc0201a16 <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc0201a16:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201a1a:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc0201a1c:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201a20:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc0201a22:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201a26:	f022                	sd	s0,32(sp)
ffffffffc0201a28:	ec26                	sd	s1,24(sp)
ffffffffc0201a2a:	e84a                	sd	s2,16(sp)
ffffffffc0201a2c:	f406                	sd	ra,40(sp)
ffffffffc0201a2e:	e44e                	sd	s3,8(sp)
ffffffffc0201a30:	84aa                	mv	s1,a0
ffffffffc0201a32:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc0201a34:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc0201a38:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc0201a3a:	03067e63          	bgeu	a2,a6,ffffffffc0201a76 <printnum+0x60>
ffffffffc0201a3e:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc0201a40:	00805763          	blez	s0,ffffffffc0201a4e <printnum+0x38>
ffffffffc0201a44:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc0201a46:	85ca                	mv	a1,s2
ffffffffc0201a48:	854e                	mv	a0,s3
ffffffffc0201a4a:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc0201a4c:	fc65                	bnez	s0,ffffffffc0201a44 <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201a4e:	1a02                	slli	s4,s4,0x20
ffffffffc0201a50:	00001797          	auipc	a5,0x1
ffffffffc0201a54:	44878793          	addi	a5,a5,1096 # ffffffffc0202e98 <default_pmm_manager+0x180>
ffffffffc0201a58:	020a5a13          	srli	s4,s4,0x20
ffffffffc0201a5c:	9a3e                	add	s4,s4,a5
}
ffffffffc0201a5e:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201a60:	000a4503          	lbu	a0,0(s4)
}
ffffffffc0201a64:	70a2                	ld	ra,40(sp)
ffffffffc0201a66:	69a2                	ld	s3,8(sp)
ffffffffc0201a68:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201a6a:	85ca                	mv	a1,s2
ffffffffc0201a6c:	87a6                	mv	a5,s1
}
ffffffffc0201a6e:	6942                	ld	s2,16(sp)
ffffffffc0201a70:	64e2                	ld	s1,24(sp)
ffffffffc0201a72:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201a74:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc0201a76:	03065633          	divu	a2,a2,a6
ffffffffc0201a7a:	8722                	mv	a4,s0
ffffffffc0201a7c:	f9bff0ef          	jal	ra,ffffffffc0201a16 <printnum>
ffffffffc0201a80:	b7f9                	j	ffffffffc0201a4e <printnum+0x38>

ffffffffc0201a82 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc0201a82:	7119                	addi	sp,sp,-128
ffffffffc0201a84:	f4a6                	sd	s1,104(sp)
ffffffffc0201a86:	f0ca                	sd	s2,96(sp)
ffffffffc0201a88:	ecce                	sd	s3,88(sp)
ffffffffc0201a8a:	e8d2                	sd	s4,80(sp)
ffffffffc0201a8c:	e4d6                	sd	s5,72(sp)
ffffffffc0201a8e:	e0da                	sd	s6,64(sp)
ffffffffc0201a90:	fc5e                	sd	s7,56(sp)
ffffffffc0201a92:	f06a                	sd	s10,32(sp)
ffffffffc0201a94:	fc86                	sd	ra,120(sp)
ffffffffc0201a96:	f8a2                	sd	s0,112(sp)
ffffffffc0201a98:	f862                	sd	s8,48(sp)
ffffffffc0201a9a:	f466                	sd	s9,40(sp)
ffffffffc0201a9c:	ec6e                	sd	s11,24(sp)
ffffffffc0201a9e:	892a                	mv	s2,a0
ffffffffc0201aa0:	84ae                	mv	s1,a1
ffffffffc0201aa2:	8d32                	mv	s10,a2
ffffffffc0201aa4:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201aa6:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc0201aaa:	5b7d                	li	s6,-1
ffffffffc0201aac:	00001a97          	auipc	s5,0x1
ffffffffc0201ab0:	420a8a93          	addi	s5,s5,1056 # ffffffffc0202ecc <default_pmm_manager+0x1b4>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201ab4:	00001b97          	auipc	s7,0x1
ffffffffc0201ab8:	5f4b8b93          	addi	s7,s7,1524 # ffffffffc02030a8 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201abc:	000d4503          	lbu	a0,0(s10)
ffffffffc0201ac0:	001d0413          	addi	s0,s10,1
ffffffffc0201ac4:	01350a63          	beq	a0,s3,ffffffffc0201ad8 <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc0201ac8:	c121                	beqz	a0,ffffffffc0201b08 <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc0201aca:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201acc:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc0201ace:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201ad0:	fff44503          	lbu	a0,-1(s0)
ffffffffc0201ad4:	ff351ae3          	bne	a0,s3,ffffffffc0201ac8 <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201ad8:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc0201adc:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc0201ae0:	4c81                	li	s9,0
ffffffffc0201ae2:	4881                	li	a7,0
        width = precision = -1;
ffffffffc0201ae4:	5c7d                	li	s8,-1
ffffffffc0201ae6:	5dfd                	li	s11,-1
ffffffffc0201ae8:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc0201aec:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201aee:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201af2:	0ff5f593          	zext.b	a1,a1
ffffffffc0201af6:	00140d13          	addi	s10,s0,1
ffffffffc0201afa:	04b56263          	bltu	a0,a1,ffffffffc0201b3e <vprintfmt+0xbc>
ffffffffc0201afe:	058a                	slli	a1,a1,0x2
ffffffffc0201b00:	95d6                	add	a1,a1,s5
ffffffffc0201b02:	4194                	lw	a3,0(a1)
ffffffffc0201b04:	96d6                	add	a3,a3,s5
ffffffffc0201b06:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc0201b08:	70e6                	ld	ra,120(sp)
ffffffffc0201b0a:	7446                	ld	s0,112(sp)
ffffffffc0201b0c:	74a6                	ld	s1,104(sp)
ffffffffc0201b0e:	7906                	ld	s2,96(sp)
ffffffffc0201b10:	69e6                	ld	s3,88(sp)
ffffffffc0201b12:	6a46                	ld	s4,80(sp)
ffffffffc0201b14:	6aa6                	ld	s5,72(sp)
ffffffffc0201b16:	6b06                	ld	s6,64(sp)
ffffffffc0201b18:	7be2                	ld	s7,56(sp)
ffffffffc0201b1a:	7c42                	ld	s8,48(sp)
ffffffffc0201b1c:	7ca2                	ld	s9,40(sp)
ffffffffc0201b1e:	7d02                	ld	s10,32(sp)
ffffffffc0201b20:	6de2                	ld	s11,24(sp)
ffffffffc0201b22:	6109                	addi	sp,sp,128
ffffffffc0201b24:	8082                	ret
            padc = '0';
ffffffffc0201b26:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc0201b28:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201b2c:	846a                	mv	s0,s10
ffffffffc0201b2e:	00140d13          	addi	s10,s0,1
ffffffffc0201b32:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201b36:	0ff5f593          	zext.b	a1,a1
ffffffffc0201b3a:	fcb572e3          	bgeu	a0,a1,ffffffffc0201afe <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc0201b3e:	85a6                	mv	a1,s1
ffffffffc0201b40:	02500513          	li	a0,37
ffffffffc0201b44:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc0201b46:	fff44783          	lbu	a5,-1(s0)
ffffffffc0201b4a:	8d22                	mv	s10,s0
ffffffffc0201b4c:	f73788e3          	beq	a5,s3,ffffffffc0201abc <vprintfmt+0x3a>
ffffffffc0201b50:	ffed4783          	lbu	a5,-2(s10)
ffffffffc0201b54:	1d7d                	addi	s10,s10,-1
ffffffffc0201b56:	ff379de3          	bne	a5,s3,ffffffffc0201b50 <vprintfmt+0xce>
ffffffffc0201b5a:	b78d                	j	ffffffffc0201abc <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc0201b5c:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc0201b60:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201b64:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc0201b66:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc0201b6a:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201b6e:	02d86463          	bltu	a6,a3,ffffffffc0201b96 <vprintfmt+0x114>
                ch = *fmt;
ffffffffc0201b72:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0201b76:	002c169b          	slliw	a3,s8,0x2
ffffffffc0201b7a:	0186873b          	addw	a4,a3,s8
ffffffffc0201b7e:	0017171b          	slliw	a4,a4,0x1
ffffffffc0201b82:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc0201b84:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0201b88:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc0201b8a:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc0201b8e:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201b92:	fed870e3          	bgeu	a6,a3,ffffffffc0201b72 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc0201b96:	f40ddce3          	bgez	s11,ffffffffc0201aee <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc0201b9a:	8de2                	mv	s11,s8
ffffffffc0201b9c:	5c7d                	li	s8,-1
ffffffffc0201b9e:	bf81                	j	ffffffffc0201aee <vprintfmt+0x6c>
            if (width < 0)
ffffffffc0201ba0:	fffdc693          	not	a3,s11
ffffffffc0201ba4:	96fd                	srai	a3,a3,0x3f
ffffffffc0201ba6:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201baa:	00144603          	lbu	a2,1(s0)
ffffffffc0201bae:	2d81                	sext.w	s11,s11
ffffffffc0201bb0:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201bb2:	bf35                	j	ffffffffc0201aee <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc0201bb4:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201bb8:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc0201bbc:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201bbe:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc0201bc0:	bfd9                	j	ffffffffc0201b96 <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0201bc2:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201bc4:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201bc8:	01174463          	blt	a4,a7,ffffffffc0201bd0 <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc0201bcc:	1a088e63          	beqz	a7,ffffffffc0201d88 <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc0201bd0:	000a3603          	ld	a2,0(s4)
ffffffffc0201bd4:	46c1                	li	a3,16
ffffffffc0201bd6:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc0201bd8:	2781                	sext.w	a5,a5
ffffffffc0201bda:	876e                	mv	a4,s11
ffffffffc0201bdc:	85a6                	mv	a1,s1
ffffffffc0201bde:	854a                	mv	a0,s2
ffffffffc0201be0:	e37ff0ef          	jal	ra,ffffffffc0201a16 <printnum>
            break;
ffffffffc0201be4:	bde1                	j	ffffffffc0201abc <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc0201be6:	000a2503          	lw	a0,0(s4)
ffffffffc0201bea:	85a6                	mv	a1,s1
ffffffffc0201bec:	0a21                	addi	s4,s4,8
ffffffffc0201bee:	9902                	jalr	s2
            break;
ffffffffc0201bf0:	b5f1                	j	ffffffffc0201abc <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201bf2:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201bf4:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201bf8:	01174463          	blt	a4,a7,ffffffffc0201c00 <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc0201bfc:	18088163          	beqz	a7,ffffffffc0201d7e <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc0201c00:	000a3603          	ld	a2,0(s4)
ffffffffc0201c04:	46a9                	li	a3,10
ffffffffc0201c06:	8a2e                	mv	s4,a1
ffffffffc0201c08:	bfc1                	j	ffffffffc0201bd8 <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201c0a:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc0201c0e:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201c10:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201c12:	bdf1                	j	ffffffffc0201aee <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc0201c14:	85a6                	mv	a1,s1
ffffffffc0201c16:	02500513          	li	a0,37
ffffffffc0201c1a:	9902                	jalr	s2
            break;
ffffffffc0201c1c:	b545                	j	ffffffffc0201abc <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201c1e:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc0201c22:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201c24:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201c26:	b5e1                	j	ffffffffc0201aee <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc0201c28:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201c2a:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201c2e:	01174463          	blt	a4,a7,ffffffffc0201c36 <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc0201c32:	14088163          	beqz	a7,ffffffffc0201d74 <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc0201c36:	000a3603          	ld	a2,0(s4)
ffffffffc0201c3a:	46a1                	li	a3,8
ffffffffc0201c3c:	8a2e                	mv	s4,a1
ffffffffc0201c3e:	bf69                	j	ffffffffc0201bd8 <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc0201c40:	03000513          	li	a0,48
ffffffffc0201c44:	85a6                	mv	a1,s1
ffffffffc0201c46:	e03e                	sd	a5,0(sp)
ffffffffc0201c48:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc0201c4a:	85a6                	mv	a1,s1
ffffffffc0201c4c:	07800513          	li	a0,120
ffffffffc0201c50:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201c52:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc0201c54:	6782                	ld	a5,0(sp)
ffffffffc0201c56:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201c58:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc0201c5c:	bfb5                	j	ffffffffc0201bd8 <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201c5e:	000a3403          	ld	s0,0(s4)
ffffffffc0201c62:	008a0713          	addi	a4,s4,8
ffffffffc0201c66:	e03a                	sd	a4,0(sp)
ffffffffc0201c68:	14040263          	beqz	s0,ffffffffc0201dac <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc0201c6c:	0fb05763          	blez	s11,ffffffffc0201d5a <vprintfmt+0x2d8>
ffffffffc0201c70:	02d00693          	li	a3,45
ffffffffc0201c74:	0cd79163          	bne	a5,a3,ffffffffc0201d36 <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201c78:	00044783          	lbu	a5,0(s0)
ffffffffc0201c7c:	0007851b          	sext.w	a0,a5
ffffffffc0201c80:	cf85                	beqz	a5,ffffffffc0201cb8 <vprintfmt+0x236>
ffffffffc0201c82:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201c86:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201c8a:	000c4563          	bltz	s8,ffffffffc0201c94 <vprintfmt+0x212>
ffffffffc0201c8e:	3c7d                	addiw	s8,s8,-1
ffffffffc0201c90:	036c0263          	beq	s8,s6,ffffffffc0201cb4 <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc0201c94:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201c96:	0e0c8e63          	beqz	s9,ffffffffc0201d92 <vprintfmt+0x310>
ffffffffc0201c9a:	3781                	addiw	a5,a5,-32
ffffffffc0201c9c:	0ef47b63          	bgeu	s0,a5,ffffffffc0201d92 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc0201ca0:	03f00513          	li	a0,63
ffffffffc0201ca4:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201ca6:	000a4783          	lbu	a5,0(s4)
ffffffffc0201caa:	3dfd                	addiw	s11,s11,-1
ffffffffc0201cac:	0a05                	addi	s4,s4,1
ffffffffc0201cae:	0007851b          	sext.w	a0,a5
ffffffffc0201cb2:	ffe1                	bnez	a5,ffffffffc0201c8a <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc0201cb4:	01b05963          	blez	s11,ffffffffc0201cc6 <vprintfmt+0x244>
ffffffffc0201cb8:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc0201cba:	85a6                	mv	a1,s1
ffffffffc0201cbc:	02000513          	li	a0,32
ffffffffc0201cc0:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0201cc2:	fe0d9be3          	bnez	s11,ffffffffc0201cb8 <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201cc6:	6a02                	ld	s4,0(sp)
ffffffffc0201cc8:	bbd5                	j	ffffffffc0201abc <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201cca:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201ccc:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc0201cd0:	01174463          	blt	a4,a7,ffffffffc0201cd8 <vprintfmt+0x256>
    else if (lflag) {
ffffffffc0201cd4:	08088d63          	beqz	a7,ffffffffc0201d6e <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc0201cd8:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc0201cdc:	0a044d63          	bltz	s0,ffffffffc0201d96 <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc0201ce0:	8622                	mv	a2,s0
ffffffffc0201ce2:	8a66                	mv	s4,s9
ffffffffc0201ce4:	46a9                	li	a3,10
ffffffffc0201ce6:	bdcd                	j	ffffffffc0201bd8 <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc0201ce8:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201cec:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc0201cee:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc0201cf0:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc0201cf4:	8fb5                	xor	a5,a5,a3
ffffffffc0201cf6:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201cfa:	02d74163          	blt	a4,a3,ffffffffc0201d1c <vprintfmt+0x29a>
ffffffffc0201cfe:	00369793          	slli	a5,a3,0x3
ffffffffc0201d02:	97de                	add	a5,a5,s7
ffffffffc0201d04:	639c                	ld	a5,0(a5)
ffffffffc0201d06:	cb99                	beqz	a5,ffffffffc0201d1c <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc0201d08:	86be                	mv	a3,a5
ffffffffc0201d0a:	00001617          	auipc	a2,0x1
ffffffffc0201d0e:	1be60613          	addi	a2,a2,446 # ffffffffc0202ec8 <default_pmm_manager+0x1b0>
ffffffffc0201d12:	85a6                	mv	a1,s1
ffffffffc0201d14:	854a                	mv	a0,s2
ffffffffc0201d16:	0ce000ef          	jal	ra,ffffffffc0201de4 <printfmt>
ffffffffc0201d1a:	b34d                	j	ffffffffc0201abc <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc0201d1c:	00001617          	auipc	a2,0x1
ffffffffc0201d20:	19c60613          	addi	a2,a2,412 # ffffffffc0202eb8 <default_pmm_manager+0x1a0>
ffffffffc0201d24:	85a6                	mv	a1,s1
ffffffffc0201d26:	854a                	mv	a0,s2
ffffffffc0201d28:	0bc000ef          	jal	ra,ffffffffc0201de4 <printfmt>
ffffffffc0201d2c:	bb41                	j	ffffffffc0201abc <vprintfmt+0x3a>
                p = "(null)";
ffffffffc0201d2e:	00001417          	auipc	s0,0x1
ffffffffc0201d32:	18240413          	addi	s0,s0,386 # ffffffffc0202eb0 <default_pmm_manager+0x198>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201d36:	85e2                	mv	a1,s8
ffffffffc0201d38:	8522                	mv	a0,s0
ffffffffc0201d3a:	e43e                	sd	a5,8(sp)
ffffffffc0201d3c:	200000ef          	jal	ra,ffffffffc0201f3c <strnlen>
ffffffffc0201d40:	40ad8dbb          	subw	s11,s11,a0
ffffffffc0201d44:	01b05b63          	blez	s11,ffffffffc0201d5a <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc0201d48:	67a2                	ld	a5,8(sp)
ffffffffc0201d4a:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201d4e:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc0201d50:	85a6                	mv	a1,s1
ffffffffc0201d52:	8552                	mv	a0,s4
ffffffffc0201d54:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201d56:	fe0d9ce3          	bnez	s11,ffffffffc0201d4e <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201d5a:	00044783          	lbu	a5,0(s0)
ffffffffc0201d5e:	00140a13          	addi	s4,s0,1
ffffffffc0201d62:	0007851b          	sext.w	a0,a5
ffffffffc0201d66:	d3a5                	beqz	a5,ffffffffc0201cc6 <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201d68:	05e00413          	li	s0,94
ffffffffc0201d6c:	bf39                	j	ffffffffc0201c8a <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc0201d6e:	000a2403          	lw	s0,0(s4)
ffffffffc0201d72:	b7ad                	j	ffffffffc0201cdc <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc0201d74:	000a6603          	lwu	a2,0(s4)
ffffffffc0201d78:	46a1                	li	a3,8
ffffffffc0201d7a:	8a2e                	mv	s4,a1
ffffffffc0201d7c:	bdb1                	j	ffffffffc0201bd8 <vprintfmt+0x156>
ffffffffc0201d7e:	000a6603          	lwu	a2,0(s4)
ffffffffc0201d82:	46a9                	li	a3,10
ffffffffc0201d84:	8a2e                	mv	s4,a1
ffffffffc0201d86:	bd89                	j	ffffffffc0201bd8 <vprintfmt+0x156>
ffffffffc0201d88:	000a6603          	lwu	a2,0(s4)
ffffffffc0201d8c:	46c1                	li	a3,16
ffffffffc0201d8e:	8a2e                	mv	s4,a1
ffffffffc0201d90:	b5a1                	j	ffffffffc0201bd8 <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc0201d92:	9902                	jalr	s2
ffffffffc0201d94:	bf09                	j	ffffffffc0201ca6 <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc0201d96:	85a6                	mv	a1,s1
ffffffffc0201d98:	02d00513          	li	a0,45
ffffffffc0201d9c:	e03e                	sd	a5,0(sp)
ffffffffc0201d9e:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc0201da0:	6782                	ld	a5,0(sp)
ffffffffc0201da2:	8a66                	mv	s4,s9
ffffffffc0201da4:	40800633          	neg	a2,s0
ffffffffc0201da8:	46a9                	li	a3,10
ffffffffc0201daa:	b53d                	j	ffffffffc0201bd8 <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc0201dac:	03b05163          	blez	s11,ffffffffc0201dce <vprintfmt+0x34c>
ffffffffc0201db0:	02d00693          	li	a3,45
ffffffffc0201db4:	f6d79de3          	bne	a5,a3,ffffffffc0201d2e <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc0201db8:	00001417          	auipc	s0,0x1
ffffffffc0201dbc:	0f840413          	addi	s0,s0,248 # ffffffffc0202eb0 <default_pmm_manager+0x198>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201dc0:	02800793          	li	a5,40
ffffffffc0201dc4:	02800513          	li	a0,40
ffffffffc0201dc8:	00140a13          	addi	s4,s0,1
ffffffffc0201dcc:	bd6d                	j	ffffffffc0201c86 <vprintfmt+0x204>
ffffffffc0201dce:	00001a17          	auipc	s4,0x1
ffffffffc0201dd2:	0e3a0a13          	addi	s4,s4,227 # ffffffffc0202eb1 <default_pmm_manager+0x199>
ffffffffc0201dd6:	02800513          	li	a0,40
ffffffffc0201dda:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201dde:	05e00413          	li	s0,94
ffffffffc0201de2:	b565                	j	ffffffffc0201c8a <vprintfmt+0x208>

ffffffffc0201de4 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201de4:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc0201de6:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201dea:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201dec:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201dee:	ec06                	sd	ra,24(sp)
ffffffffc0201df0:	f83a                	sd	a4,48(sp)
ffffffffc0201df2:	fc3e                	sd	a5,56(sp)
ffffffffc0201df4:	e0c2                	sd	a6,64(sp)
ffffffffc0201df6:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc0201df8:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201dfa:	c89ff0ef          	jal	ra,ffffffffc0201a82 <vprintfmt>
}
ffffffffc0201dfe:	60e2                	ld	ra,24(sp)
ffffffffc0201e00:	6161                	addi	sp,sp,80
ffffffffc0201e02:	8082                	ret

ffffffffc0201e04 <readline>:
 * The readline() function returns the text of the line read. If some errors
 * are happened, NULL is returned. The return value is a global variable,
 * thus it should be copied before it is used.
 * */
char *
readline(const char *prompt) {
ffffffffc0201e04:	715d                	addi	sp,sp,-80
ffffffffc0201e06:	e486                	sd	ra,72(sp)
ffffffffc0201e08:	e0a6                	sd	s1,64(sp)
ffffffffc0201e0a:	fc4a                	sd	s2,56(sp)
ffffffffc0201e0c:	f84e                	sd	s3,48(sp)
ffffffffc0201e0e:	f452                	sd	s4,40(sp)
ffffffffc0201e10:	f056                	sd	s5,32(sp)
ffffffffc0201e12:	ec5a                	sd	s6,24(sp)
ffffffffc0201e14:	e85e                	sd	s7,16(sp)
    if (prompt != NULL) {
ffffffffc0201e16:	c901                	beqz	a0,ffffffffc0201e26 <readline+0x22>
ffffffffc0201e18:	85aa                	mv	a1,a0
        cprintf("%s", prompt);
ffffffffc0201e1a:	00001517          	auipc	a0,0x1
ffffffffc0201e1e:	0ae50513          	addi	a0,a0,174 # ffffffffc0202ec8 <default_pmm_manager+0x1b0>
ffffffffc0201e22:	ad4fe0ef          	jal	ra,ffffffffc02000f6 <cprintf>
readline(const char *prompt) {
ffffffffc0201e26:	4481                	li	s1,0
    while (1) {
        c = getchar();
        if (c < 0) {
            return NULL;
        }
        else if (c >= ' ' && i < BUFSIZE - 1) {
ffffffffc0201e28:	497d                	li	s2,31
            cputchar(c);
            buf[i ++] = c;
        }
        else if (c == '\b' && i > 0) {
ffffffffc0201e2a:	49a1                	li	s3,8
            cputchar(c);
            i --;
        }
        else if (c == '\n' || c == '\r') {
ffffffffc0201e2c:	4aa9                	li	s5,10
ffffffffc0201e2e:	4b35                	li	s6,13
            buf[i ++] = c;
ffffffffc0201e30:	00005b97          	auipc	s7,0x5
ffffffffc0201e34:	210b8b93          	addi	s7,s7,528 # ffffffffc0207040 <buf>
        else if (c >= ' ' && i < BUFSIZE - 1) {
ffffffffc0201e38:	3fe00a13          	li	s4,1022
        c = getchar();
ffffffffc0201e3c:	b32fe0ef          	jal	ra,ffffffffc020016e <getchar>
        if (c < 0) {
ffffffffc0201e40:	00054a63          	bltz	a0,ffffffffc0201e54 <readline+0x50>
        else if (c >= ' ' && i < BUFSIZE - 1) {
ffffffffc0201e44:	00a95a63          	bge	s2,a0,ffffffffc0201e58 <readline+0x54>
ffffffffc0201e48:	029a5263          	bge	s4,s1,ffffffffc0201e6c <readline+0x68>
        c = getchar();
ffffffffc0201e4c:	b22fe0ef          	jal	ra,ffffffffc020016e <getchar>
        if (c < 0) {
ffffffffc0201e50:	fe055ae3          	bgez	a0,ffffffffc0201e44 <readline+0x40>
            return NULL;
ffffffffc0201e54:	4501                	li	a0,0
ffffffffc0201e56:	a091                	j	ffffffffc0201e9a <readline+0x96>
        else if (c == '\b' && i > 0) {
ffffffffc0201e58:	03351463          	bne	a0,s3,ffffffffc0201e80 <readline+0x7c>
ffffffffc0201e5c:	e8a9                	bnez	s1,ffffffffc0201eae <readline+0xaa>
        c = getchar();
ffffffffc0201e5e:	b10fe0ef          	jal	ra,ffffffffc020016e <getchar>
        if (c < 0) {
ffffffffc0201e62:	fe0549e3          	bltz	a0,ffffffffc0201e54 <readline+0x50>
        else if (c >= ' ' && i < BUFSIZE - 1) {
ffffffffc0201e66:	fea959e3          	bge	s2,a0,ffffffffc0201e58 <readline+0x54>
ffffffffc0201e6a:	4481                	li	s1,0
            cputchar(c);
ffffffffc0201e6c:	e42a                	sd	a0,8(sp)
ffffffffc0201e6e:	abefe0ef          	jal	ra,ffffffffc020012c <cputchar>
            buf[i ++] = c;
ffffffffc0201e72:	6522                	ld	a0,8(sp)
ffffffffc0201e74:	009b87b3          	add	a5,s7,s1
ffffffffc0201e78:	2485                	addiw	s1,s1,1
ffffffffc0201e7a:	00a78023          	sb	a0,0(a5)
ffffffffc0201e7e:	bf7d                	j	ffffffffc0201e3c <readline+0x38>
        else if (c == '\n' || c == '\r') {
ffffffffc0201e80:	01550463          	beq	a0,s5,ffffffffc0201e88 <readline+0x84>
ffffffffc0201e84:	fb651ce3          	bne	a0,s6,ffffffffc0201e3c <readline+0x38>
            cputchar(c);
ffffffffc0201e88:	aa4fe0ef          	jal	ra,ffffffffc020012c <cputchar>
            buf[i] = '\0';
ffffffffc0201e8c:	00005517          	auipc	a0,0x5
ffffffffc0201e90:	1b450513          	addi	a0,a0,436 # ffffffffc0207040 <buf>
ffffffffc0201e94:	94aa                	add	s1,s1,a0
ffffffffc0201e96:	00048023          	sb	zero,0(s1)
            return buf;
        }
    }
}
ffffffffc0201e9a:	60a6                	ld	ra,72(sp)
ffffffffc0201e9c:	6486                	ld	s1,64(sp)
ffffffffc0201e9e:	7962                	ld	s2,56(sp)
ffffffffc0201ea0:	79c2                	ld	s3,48(sp)
ffffffffc0201ea2:	7a22                	ld	s4,40(sp)
ffffffffc0201ea4:	7a82                	ld	s5,32(sp)
ffffffffc0201ea6:	6b62                	ld	s6,24(sp)
ffffffffc0201ea8:	6bc2                	ld	s7,16(sp)
ffffffffc0201eaa:	6161                	addi	sp,sp,80
ffffffffc0201eac:	8082                	ret
            cputchar(c);
ffffffffc0201eae:	4521                	li	a0,8
ffffffffc0201eb0:	a7cfe0ef          	jal	ra,ffffffffc020012c <cputchar>
            i --;
ffffffffc0201eb4:	34fd                	addiw	s1,s1,-1
ffffffffc0201eb6:	b759                	j	ffffffffc0201e3c <readline+0x38>

ffffffffc0201eb8 <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc0201eb8:	4781                	li	a5,0
ffffffffc0201eba:	00005717          	auipc	a4,0x5
ffffffffc0201ebe:	15e73703          	ld	a4,350(a4) # ffffffffc0207018 <SBI_CONSOLE_PUTCHAR>
ffffffffc0201ec2:	88ba                	mv	a7,a4
ffffffffc0201ec4:	852a                	mv	a0,a0
ffffffffc0201ec6:	85be                	mv	a1,a5
ffffffffc0201ec8:	863e                	mv	a2,a5
ffffffffc0201eca:	00000073          	ecall
ffffffffc0201ece:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc0201ed0:	8082                	ret

ffffffffc0201ed2 <sbi_set_timer>:
    __asm__ volatile (
ffffffffc0201ed2:	4781                	li	a5,0
ffffffffc0201ed4:	00005717          	auipc	a4,0x5
ffffffffc0201ed8:	5c473703          	ld	a4,1476(a4) # ffffffffc0207498 <SBI_SET_TIMER>
ffffffffc0201edc:	88ba                	mv	a7,a4
ffffffffc0201ede:	852a                	mv	a0,a0
ffffffffc0201ee0:	85be                	mv	a1,a5
ffffffffc0201ee2:	863e                	mv	a2,a5
ffffffffc0201ee4:	00000073          	ecall
ffffffffc0201ee8:	87aa                	mv	a5,a0

void sbi_set_timer(unsigned long long stime_value) {
    sbi_call(SBI_SET_TIMER, stime_value, 0, 0);
}
ffffffffc0201eea:	8082                	ret

ffffffffc0201eec <sbi_console_getchar>:
    __asm__ volatile (
ffffffffc0201eec:	4501                	li	a0,0
ffffffffc0201eee:	00005797          	auipc	a5,0x5
ffffffffc0201ef2:	1227b783          	ld	a5,290(a5) # ffffffffc0207010 <SBI_CONSOLE_GETCHAR>
ffffffffc0201ef6:	88be                	mv	a7,a5
ffffffffc0201ef8:	852a                	mv	a0,a0
ffffffffc0201efa:	85aa                	mv	a1,a0
ffffffffc0201efc:	862a                	mv	a2,a0
ffffffffc0201efe:	00000073          	ecall
ffffffffc0201f02:	852a                	mv	a0,a0

int sbi_console_getchar(void) {
    return sbi_call(SBI_CONSOLE_GETCHAR, 0, 0, 0);
}
ffffffffc0201f04:	2501                	sext.w	a0,a0
ffffffffc0201f06:	8082                	ret

ffffffffc0201f08 <sbi_shutdown>:
    __asm__ volatile (
ffffffffc0201f08:	4781                	li	a5,0
ffffffffc0201f0a:	00005717          	auipc	a4,0x5
ffffffffc0201f0e:	11673703          	ld	a4,278(a4) # ffffffffc0207020 <SBI_SHUTDOWN>
ffffffffc0201f12:	88ba                	mv	a7,a4
ffffffffc0201f14:	853e                	mv	a0,a5
ffffffffc0201f16:	85be                	mv	a1,a5
ffffffffc0201f18:	863e                	mv	a2,a5
ffffffffc0201f1a:	00000073          	ecall
ffffffffc0201f1e:	87aa                	mv	a5,a0

void sbi_shutdown(void)
{
	sbi_call(SBI_SHUTDOWN, 0, 0, 0);
ffffffffc0201f20:	8082                	ret

ffffffffc0201f22 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc0201f22:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc0201f26:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc0201f28:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc0201f2a:	cb81                	beqz	a5,ffffffffc0201f3a <strlen+0x18>
        cnt ++;
ffffffffc0201f2c:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc0201f2e:	00a707b3          	add	a5,a4,a0
ffffffffc0201f32:	0007c783          	lbu	a5,0(a5)
ffffffffc0201f36:	fbfd                	bnez	a5,ffffffffc0201f2c <strlen+0xa>
ffffffffc0201f38:	8082                	ret
    }
    return cnt;
}
ffffffffc0201f3a:	8082                	ret

ffffffffc0201f3c <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc0201f3c:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201f3e:	e589                	bnez	a1,ffffffffc0201f48 <strnlen+0xc>
ffffffffc0201f40:	a811                	j	ffffffffc0201f54 <strnlen+0x18>
        cnt ++;
ffffffffc0201f42:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201f44:	00f58863          	beq	a1,a5,ffffffffc0201f54 <strnlen+0x18>
ffffffffc0201f48:	00f50733          	add	a4,a0,a5
ffffffffc0201f4c:	00074703          	lbu	a4,0(a4)
ffffffffc0201f50:	fb6d                	bnez	a4,ffffffffc0201f42 <strnlen+0x6>
ffffffffc0201f52:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc0201f54:	852e                	mv	a0,a1
ffffffffc0201f56:	8082                	ret

ffffffffc0201f58 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201f58:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201f5c:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201f60:	cb89                	beqz	a5,ffffffffc0201f72 <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc0201f62:	0505                	addi	a0,a0,1
ffffffffc0201f64:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201f66:	fee789e3          	beq	a5,a4,ffffffffc0201f58 <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201f6a:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc0201f6e:	9d19                	subw	a0,a0,a4
ffffffffc0201f70:	8082                	ret
ffffffffc0201f72:	4501                	li	a0,0
ffffffffc0201f74:	bfed                	j	ffffffffc0201f6e <strcmp+0x16>

ffffffffc0201f76 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201f76:	c20d                	beqz	a2,ffffffffc0201f98 <strncmp+0x22>
ffffffffc0201f78:	962e                	add	a2,a2,a1
ffffffffc0201f7a:	a031                	j	ffffffffc0201f86 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc0201f7c:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201f7e:	00e79a63          	bne	a5,a4,ffffffffc0201f92 <strncmp+0x1c>
ffffffffc0201f82:	00b60b63          	beq	a2,a1,ffffffffc0201f98 <strncmp+0x22>
ffffffffc0201f86:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc0201f8a:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201f8c:	fff5c703          	lbu	a4,-1(a1)
ffffffffc0201f90:	f7f5                	bnez	a5,ffffffffc0201f7c <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201f92:	40e7853b          	subw	a0,a5,a4
}
ffffffffc0201f96:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201f98:	4501                	li	a0,0
ffffffffc0201f9a:	8082                	ret

ffffffffc0201f9c <strchr>:
 * The strchr() function returns a pointer to the first occurrence of
 * character in @s. If the value is not found, the function returns 'NULL'.
 * */
char *
strchr(const char *s, char c) {
    while (*s != '\0') {
ffffffffc0201f9c:	00054783          	lbu	a5,0(a0)
ffffffffc0201fa0:	c799                	beqz	a5,ffffffffc0201fae <strchr+0x12>
        if (*s == c) {
ffffffffc0201fa2:	00f58763          	beq	a1,a5,ffffffffc0201fb0 <strchr+0x14>
    while (*s != '\0') {
ffffffffc0201fa6:	00154783          	lbu	a5,1(a0)
            return (char *)s;
        }
        s ++;
ffffffffc0201faa:	0505                	addi	a0,a0,1
    while (*s != '\0') {
ffffffffc0201fac:	fbfd                	bnez	a5,ffffffffc0201fa2 <strchr+0x6>
    }
    return NULL;
ffffffffc0201fae:	4501                	li	a0,0
}
ffffffffc0201fb0:	8082                	ret

ffffffffc0201fb2 <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc0201fb2:	ca01                	beqz	a2,ffffffffc0201fc2 <memset+0x10>
ffffffffc0201fb4:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc0201fb6:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc0201fb8:	0785                	addi	a5,a5,1
ffffffffc0201fba:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc0201fbe:	fec79de3          	bne	a5,a2,ffffffffc0201fb8 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc0201fc2:	8082                	ret
