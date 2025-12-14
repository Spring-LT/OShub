# Lab5-gdb调试实验报告

## 使用双重 GDB 调试系统调用（`ecall`）与返回（`sret`）全过程

------

## 一、实验目的

本实验通过 **双重 GDB（Guest + QEMU）调试方案**，在 RISC-V 架构下，完整观察并分析：

1. 用户态程序如何通过 `ecall` 指令触发系统调用
2. QEMU 在 **TCG 翻译阶段**如何识别 `ecall` 并“注入异常”
3. 该异常在 **运行期**如何被分发为正确的特权级异常（U/S/M ecall）
4. 内核完成系统调用后，`sret` 指令如何在 QEMU 中被处理并返回用户态

实验重点在于**通过调试证据理解 QEMU 是如何用软件模拟硬件特权级机制的**。

------

## 二、实验环境与调试方案

### 2.1 实验环境

- 架构：RISC-V 64
- 操作系统：ucore
- 模拟器：QEMU 4.1.1（TCG 模式）
- 调试工具：
  - **终端3：riscv64-unknown-elf-gdb**（调试 ucore / 用户程序）
  - **终端2：gdb attach QEMU 进程**（调试 QEMU 源码）

### 2.2 双重 GDB 调试方案说明

| 调试对象  | 作用                                                  |
| --------- | ----------------------------------------------------- |
| ucore GDB | 观察 **用户态 / 内核态指令执行、PC、寄存器、调用栈**  |
| QEMU GDB  | 观察 **指令翻译、TCG IR 生成、helper 调用、异常分发** |

该方案使我们能够同时看到：**“来宾认为发生了什么”** 与 **“QEMU 实际做了什么”**

------

## 三、`ecall` 指令的完整调试与证据分析（重点）

------

### 3.1 用户态触发 `ecall`：系统调用入口的确定

#### 3.1.1 加载用户程序符号

由于 `make gdb` 默认只加载内核符号，需要手动加载用户程序：

```gdb
(gdb) add-symbol-file obj/__user_exit.out
```

否则无法在 `user/libs/syscall.c` 下断点。

------

#### 3.1.2 在用户态 syscall 函数断点

```gdb
(gdb) break user/libs/syscall.c:19
(gdb) continue
```

命中断点后反汇编当前指令：

```gdb
(gdb) x/7i $pc
```

**关键证据（用户态 ecall）**：

```
0x8000f8:  ld a0,8(sp)
...
0x800104: ecall
```

并查看调用栈：

```gdb
(gdb) bt
syscall
└─ sys_putc
   └─ cprintf
      └─ main
```

**结论**：`0x800104: ecall` 是所有用户系统调用的必经点。

------

### 3.2 QEMU 翻译阶段如何“看到”这条 ecall

------

#### 3.2.1 条件断点锁定目标指令

在 **QEMU GDB（终端2）** 中：

```gdb
(gdb) break riscv_tr_translate_insn \
      if ((DisasContext*)dcbase)->base.pc_next == 0x800104
(gdb) continue
```

然后在 **终端3** 执行一次：

```gdb
(gdb) si
```

------

#### 3.2.2 命中 QEMU 翻译入口的证据

```gdb
Thread hit Breakpoint, riscv_tr_translate_insn
```

检查翻译地址：

```gdb
(gdb) p/x ((DisasContext*)dcbase)->base.pc_next
$1 = 0x800104
```

查看源码位置：

```gdb
(gdb) list
ctx->opcode = cpu_ldl_code(env, ctx->base.pc_next);
decode_opc(ctx);
```

------

#### 3.2.3 opcode 取证（SYSTEM 指令）

```gdb
(gdb) p/x ctx->opcode
$2 = 0x73
```

**分析**：

- `0x73` → RISC-V SYSTEM 指令
- `ecall / ebreak / csr` 都属于该类

------

### 3.3 ecall 在 QEMU 中的翻译处理：`trans_ecall`

------

#### 3.3.1 命中 `trans_ecall`

```gdb
(gdb) break target/riscv/insn_trans/trans_privileged.inc.c:21
(gdb) continue
```

触发下一次系统调用后命中：

```c
static bool trans_ecall(DisasContext *ctx, arg_ecall *a)
{
    /* always generates U-level ECALL, fixed in do_interrupt handler */
    generate_exception(ctx, RISCV_EXCP_U_ECALL);
    exit_tb(ctx);
    ctx->base.is_jmp = DISAS_NORETURN;
    return true;
}
```

------

#### 3.3.2 关键分析（非常重要）

1. **翻译阶段并不真正“陷入内核”**

2. QEMU **统一生成 `RISCV_EXCP_U_ECALL`**

3. 注释明确说明：

   > *真正的特权级区分在后续 do_interrupt 中完成*

------

### 3.4 异常注入机制：TCG helper 的使用

------

#### 3.4.1 进入 `generate_exception`

```gdb
(gdb) step
static void generate_exception(DisasContext *ctx, int excp)
{
    tcg_gen_movi_tl(cpu_pc, ctx->base.pc_next);
    TCGv_i32 helper_tmp = tcg_const_i32(excp);
    gen_helper_raise_exception(cpu_env, helper_tmp);
    ctx->base.is_jmp = DISAS_NORETURN;
}
```

------

#### 3.4.2 核心结论（ecall 的本质）

> **QEMU 不是立即跳转到内核代码，而是在翻译阶段生成 TCG IR，
>  在运行期通过 helper 调用“注入异常”。**

------

### 3.5 运行期异常触发：helper → riscv_raise_exception

------

```gdb
(gdb) break helper_raise_exception
(gdb) continue
```

命中：

```c
void helper_raise_exception(...)
{
    riscv_raise_exception(env, exception, 0);
}
```

并确认参数：

```gdb
(gdb) p exception
$ = 8   // RISCV_EXCP_U_ECALL
```

------

### 3.6 ecall 异常分发：特权级相关的 cause 修正

------

#### 3.6.1 cpu_helper.c 中的分发逻辑

```c
static const int ecall_cause_map[] = {
    [PRV_U] = RISCV_EXCP_U_ECALL,
    [PRV_S] = RISCV_EXCP_S_ECALL,
    [PRV_H] = RISCV_EXCP_H_ECALL,
    [PRV_M] = RISCV_EXCP_M_ECALL
};
/* ecall is dispatched as one cause so translate based on mode */
cause = ecall_cause_map[env->priv];
```

------

#### 3.6.2 关键理解

| 阶段   | 行为                              |
| ------ | --------------------------------- |
| 翻译期 | 固定生成 `U_ECALL`                |
| 运行期 | 根据 `env->priv` 修正为 S/M ecall |
| 结果   | 进入内核 trap handler             |

 **这正是 QEMU 模拟硬件行为的关键设计**

------

## 四、`sret` 指令的完整调试与证据分析

------

### 4.1 sret指令定位与调试

#### 4.1.1 定位sret指令位置

通过搜索trapentry.S文件，确认sret指令位于`__trapret`函数中：

```bash
# 搜索sret指令位置
(gdb) search_by_regex "sret" /mnt/d/oshub/labcode/lab5/kern/trap/trapentry.S
```

**关键证据**：sret指令位于trapentry.S文件的133行，在RESTORE_ALL宏之后直接执行。

#### 4.1.2 设置断点并执行sret

在ucore GDB中设置断点并执行到sret指令：

```bash
# 设置__trapret断点
(gdb) b __trapret
Breakpoint 3 at 0xffffffffc0200f4a: file kern/trap/trapentry.S, line 131.

# 执行到sret指令
(gdb) n
# 多次执行n命令，直到到达sret指令
(gdb) x/5i $pc
=> 0xffffffffc0200f4e <__trapret+4>:   sret
```

**关键证据**：当前PC指向sret指令（地址：`0xffffffffc0200f4e`），准备执行特权级切换。

### 4.2 QEMU中sret指令的处理

#### 4.2.1 设置QEMU断点

在QEMU GDB中设置关键断点：

```bash
# 设置helper_sret断点
(gdb) b helper_sret
Breakpoint 6 at 0x576f0bfbed64: file /mnt/d/WSL/qemu-4.1.1/target/riscv/op_helper.c, line 76.

# 设置riscv_tr_translate_insn断点
(gdb) b riscv_tr_translate_insn
Breakpoint 7 at 0x576f0bfb3b7c: file /mnt/d/WSL/qemu-4.1.1/target/riscv/translate.c, line 796.
```

#### 4.2.2 观察指令翻译过程

当ucore执行sret指令时，QEMU开始翻译过程：

```bash
# 检查指令编码
(gdb) p/x ctx->opcode
$1 = 0x10200073  # sret指令编码

# 检查指令地址
(gdb) p/x ctx->base.pc_next
$2 = 0xffffffffc0200f4e  # sret指令地址
```

**关键证据**：QEMU成功识别sret指令（编码：`0x10200073`），并开始翻译过程。

#### 4.2.3 helper_sret函数执行

QEMU执行helper_sret函数，完成特权级切换：

```bash
# 检查当前特权级
(gdb) p/x env->priv
$23 = 0x1  # Supervisor模式

# 检查mstatus寄存器
(gdb) p/x env->mstatus
$24 = 0x8000000000046020  # SPP位被设置

# 单步执行特权级切换
(gdb) n
...
(gdb) p/x env->priv
$25 = 0x0  # User模式（切换成功）
```

**关键证据**：`env->priv`从`0x1`（Supervisor）变为`0x0`（User），特权级切换成功。

### 4.3 特权级切换验证

在ucore GDB中验证特权级切换结果：

```bash
# 检查PC跳转
(gdb) x/5i $pc
=> 0x800108 <syscall+48>: sd  a0,28(sp)

# 尝试访问sstatus寄存器（验证特权级）
(gdb) p/x $sstatus
Could not fetch register "sstatus"; remote failure reply 'E14'

# 检查调用栈
(gdb) bt
#0  0x0000000000800108 in syscall (num=0, num@entry=30) at user/libs/syscall.c:19
```

**关键证据**：

1. PC成功跳转到用户程序地址`0x800108`
2. 无法访问sstatus寄存器（E14错误），证明当前处于User模式
3. 调用栈显示处于用户空间的syscall函数

------

## 五、TCG 翻译机制的整体理解

| 指令  | QEMU 行为                    |
| ----- | ---------------------------- |
| ecall | 翻译期 → helper → 异常注入   |
| sret  | 翻译期 → helper → 修改特权级 |

> **TCG 不是“解释执行”，而是生成一段主机代码来“模拟硬件语义”**

------



------

## 六、调试要求详细回答

### 6.1 ecall 和 sret 指令的 QEMU 处理流程

#### 6.1.1 ecall 指令处理流程

1. **用户态触发**：用户程序执行到 `0x800104: ecall`，调用栈显示从用户库进入 `syscall` 再触发 `ecall`。
2. **QEMU 翻译入口锁定**：在 QEMU 侧对 `riscv_tr_translate_insn` 下条件断点，确保只在 `pc_next==0x800104` 的那次翻译停下，并确认取指与解码入口：`ctx->opcode = cpu_ldl_code(...); decode_opc(ctx);`
3. **指令解码到 trans_ecall**：命中 `trans_ecall`，执行 `generate_exception(ctx, RISCV_EXCP_U_ECALL);`，并且翻译阶段固定生成 U-level ECALL，后续在 do_interrupt 修正。
4. **TCG 注入异常**：`generate_exception` 中通过 `gen_helper_raise_exception(cpu_env, helper_tmp)` 生成 helper 调用，从而把异常注入到运行期执行模型中，而不是直接跳转；并设置 `ctx->base.is_jmp = DISAS_NORETURN` 结束 TB。
5. **运行期异常分发（cause 修正）**：`cpu_helper.c` 内的 `ecall_cause_map` 与注释 “translate based on mode” 表明：虽然翻译阶段统一注入 `U_ECALL`，但进入异常处理时会依据 `env->priv` 将 cause 映射为 U/S/H/M 的不同 ecall 异常原因。

#### 6.1.2 sret 指令处理流程

- `riscv_tr_translate_insn` 识别 `sret`（编码 `0x10200073`），翻译生成对 `helper_sret` 的调用；`helper_sret` 完成 sepc 恢复、mstatus 位处理（SPP/SPIE）与 `riscv_cpu_set_mode` 切换特权级，最终返回用户地址继续执行。
- 关键函数：`helper_sret`（op_helper.c:76-102）。

------

### 6.2 TCG 翻译功能分析（结合 ecall 与 sret）

1. **TCG 的角色**：QEMU 并非逐条“解释执行”目标指令，而是将目标 ISA（RISC-V）的指令翻译成中间表示/主机可执行代码块（TB），并缓存复用。
2. **为什么 ecall 是“注入异常”**：在 TCG 模型中，`ecall` 这样的“陷入”不会用真实硬件跳转实现，而是在翻译阶段生成 helper（如 `gen_helper_raise_exception`）来在运行期触发异常处理逻辑，从而模拟硬件行为。
3. **与 Lab2 的联系**：Lab2 中地址翻译/页表访问同样依赖 QEMU 对目标指令的翻译执行；本实验进一步展示了“特权级指令 + 异常/返回”在 TCG 下的实现方式。

------

### 6.3 有趣的调试细节

- **反向证据**：User 模式下无法访问 `sstatus`/`sepc` 等 CSR（E14）不是失败，而是特权级保护生效、已经回到 U-mode 的证据。 
- **host gdb 读不到 guest 地址**：在 QEMU 源码 gdb 里直接 `x 0x800104` 失败，是因为它默认读取宿主进程虚拟内存；需要用 `ctx->opcode/cpu_ldl_code` 这类 QEMU 内部取指数据结构来验证 guest 指令内容。

------

### 6.4 大模型辅助解决的问题

#### 6.4.1 ecall 观测点选择与双端联动

- 通过分析“所有系统调用最终会落到用户态 `syscall` 内联汇编的 `ecall`”，选择 `0x800104 ecall` 作为必经观测点，并在 ucore 侧单步精准停住。 
- 指导在 QEMU 侧用条件断点锁定 `pc_next == 0x800104`，避免 QEMU 在大量翻译点频繁停住。

#### 6.4.2 ecall 路径的关键证据链定位

- 明确并取证 `trans_ecall → generate_exception → gen_helper_raise_exception` 的完整链路，作为实验最核心证据。 

#### 6.4.3 sret 部分

- 定位 `__trapret` 中的 `sret`、设置 QEMU 侧断点（`helper_sret`）、以及解释 CSR 访问错误作为特权级切换证据等。  

------

## 七、实验总结

通过双重 GDB，本次实验在“用户态 ecall 触发系统调用”与“内核态 sret 返回用户态”两个关键点上都完成了源码级取证：

- **ecall**：从用户态 `0x800104: ecall` 出发，证实 QEMU 在翻译阶段命中 `trans_ecall` 并调用 `generate_exception(ctx, RISCV_EXCP_U_ECALL)`，随后通过 `gen_helper_raise_exception` 在 TCG 模型下注入异常；并结合 `cpu_helper.c` 的 `ecall_cause_map` 说明最终 cause 会在运行期按特权级修正。   
- **sret**：定位到 `__trapret` 的 `sret`，并在 QEMU 侧断到 `helper_sret`，理解其通过 `sepc/mstatus` 等完成返回地址恢复与特权级切换；最终在用户态通过 PC 回到 `0x800108` 以及 CSR 访问 E14 的反向证据验证返回成功。 

整体上，本实验不仅加深了对 RISC-V 特权级陷入/返回机制的理解，也训练了在“来宾 + 模拟器源码”双层结构下定位关键路径、提取可写入报告证据的调试能力。

这不仅加深了对 **RISC-V 特权级机制** 的理解，也真正理解了：

> **模拟器并不是“黑盒”，而是一套严谨的软件硬件抽象系统。**

