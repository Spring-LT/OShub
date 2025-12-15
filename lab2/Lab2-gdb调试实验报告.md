## 分支任务：gdb 调试页表查询过程

### 一、实验目的

本分支任务的目标是在 **RISC-V Sv39** 虚拟内存模式下，通过“双重 GDB”调试，观察一次真实访存（指令取指/读写数据）在 QEMU 中如何完成：

1. **TLB 查询（TLB lookup）**：判断是否命中已有缓存映射
2. **TLB miss 处理**：触发 QEMU 的 `tlb_fill` 路径
3. **页表遍历（page walk）**：在 QEMU 中执行 Sv39 的多级页表查询
4. **填充 TLB（TLB fill）**：将新映射写入 QEMU 的软件 TLB
5. 对比 QEMU TLB 与真实 CPU TLB 的**逻辑差异**

### 二、实验环境与双重 GDB 调试方案

#### 2.1 实验环境

- ucore：`OShub/lab2`
- QEMU：`qemu-4.1.1`（建议使用 `--enable-debug` 编译的“调试版”可执行文件）
- 调试工具：
  - **Guest GDB**：`riscv64-unknown-elf-gdb`（连接 QEMU gdbstub，调试 ucore）
  - **Host GDB**：系统 `gdb`（`attach` 到 QEMU 进程，调试 QEMU 源码）

#### 2.2 调试版 QEMU 与 Makefile 配置（关键）

为了让 Host GDB 能够下断点、查看源码，需要使用带调试信息的 QEMU 可执行文件。本次实验使用的调试版 QEMU 路径为：

- `/home/insung/os/qemu-4.1.1/riscv64-softmmu/qemu-system-riscv64`

在 ucore 的 `Makefile` 中将 `QEMU := ...` 指向带调试信息的 QEMU 可执行文件（以上路径或你系统中实际的调试版路径），然后再使用 `make debug` 启动。

#### 2.3 三终端流程（推荐）

- **终端1（启动 QEMU 并暂停）**
  - 在 `lab2` 目录：
    - `make debug`
  - `-S` 会让 CPU 在复位后暂停，等待 gdbstub 连接。

- **终端2（Host GDB attach QEMU）**
  - 找到 QEMU PID 后 `gdb` attach：
    - `attach <PID>`
  - 建议在 host gdb 中设置：
    - `handle SIGPIPE nostop noprint`

- **终端3（Guest GDB 连接 gdbstub）**
  - 在 `lab2` 目录：
    - `make gdb`

**双重 GDB 的价值**：

- Guest GDB 告诉你“来宾 CPU 认为自己执行到哪里、将访问哪个虚拟地址”。
- Host GDB 让你看到“QEMU 如何用软件模拟硬件 MMU 的 TLB 与页表遍历”。

#### 2.4 三终端的“推荐执行顺序”（避免卡住）

1. **终端1**：`make debug`（QEMU 处于 `-S` 暂停状态）
2. **终端2**：`gdb` → `attach <PID>` → 在 QEMU 源码处下好断点 → `continue`
3. **终端3**：`make gdb` 连接 gdbstub，开始 `continue/si` 推动 ucore 执行

如果你先在终端3 `continue`，但终端2 没有提前设置好条件断点，Host GDB 可能会错过你想观察的那次“特定地址的访存”。

### 三、ucore 侧：开启分页与必经访存点

#### 3.1 写入 satp + 刷新 TLB

`kern/init/entry.S` 中 `kern_entry` 完成了 Sv39 的开启：

- 计算 `boot_page_table_sv39` 的**物理页号**
- `csrw satp, t0`
- `sfence.vma` 刷新 TLB

#### 3.2 “一定会触发地址翻译”的访存：跳转到 `kern_init`

在 `sfence.vma` 之后：

- 设置 `sp = bootstacktop`（访问栈时会产生数据访存）
- `jr t0` 跳转到 `kern_init`（下一条取指必然发生“指令取指访存”）

结合本实验的 `.qemu.out` 输出：

- `kern_init` 的虚拟地址为 `0xffffffffc02000dc`
- 因此 `jr` 之后的第一条取指，必然会对虚拟地址 `0xffffffffc02000dc` 做地址翻译

这非常适合作为 QEMU 侧“页表查询过程”的观测入口。

### 四、QEMU 侧：地址翻译的关键调用路径（TLB → page walk → fill）

本实验重点在“QEMU 怎么模拟硬件 MMU”。以一次典型的访存为例（取指/读/写都类似），核心路径如下：

#### 4.1 TLB 查询入口：`accel/tcg/cputlb.c`

- **取指**：`get_page_addr_code(CPUArchState *env, target_ulong addr)`
- **读内存**：`load_helper(...)`
- **写内存**：`store_helper(...)`

这三类入口都会做同样的检查：

1. 计算 `mmu_idx = cpu_mmu_index(env, ifetch)`（RISC-V 上一般等于 `env->priv`，区分 U/S/M）
2. 从软件 TLB 表中取 `CPUTLBEntry *entry = tlb_entry(env, mmu_idx, addr)`
3. `tlb_hit(entry->addr_xxx, addr)` 判断是否命中
4. 若未命中：
  - 先尝试 **victim TLB**：`victim_tlb_hit(...)`
  - 若仍未命中：调用 `tlb_fill(...)`

补充说明：

- `tlb_hit(...)` 的本质是检查“本次访问的虚拟页号”是否与 `CPUTLBEntry.addr_read/write/code` 缓存的页号匹配。
- `victim_tlb_hit(...)` 是一个小型的“受害者缓存”，用于缓解主 TLB 的冲突 miss（这也是 QEMU 的 TLB 与很多教科书里“单一 TLB”模型的一个区别）。

#### 4.2 TLB miss：`tlb_fill` 调到架构相关的 `riscv_cpu_tlb_fill`

`accel/tcg/cputlb.c`：

- `tlb_fill(...)` 内部会调用 `CPUClass *cc = CPU_GET_CLASS(cpu)`
- 然后执行：`cc->tlb_fill(...)`
- 对 RISC-V 来说，这会进入：`target/riscv/cpu_helper.c::riscv_cpu_tlb_fill(...)`

#### 4.3 page walk：`get_physical_address`（Sv39 多级页表遍历）

`target/riscv/cpu_helper.c`：

- `riscv_cpu_tlb_fill` 调用 `get_physical_address(env, &pa, &prot, address, access_type, mmu_idx)`
- `get_physical_address` 会：
  - 根据 `satp.mode` 判断 Sv32/Sv39/Sv48...
  - 设置 `levels = 3`（Sv39）、`ptidxbits = 9`、`ptesize = 8`
  - `base = satp.ppn << 12` 得到根页表物理地址
  - 循环 `for (i = 0; i < levels; i++)` 逐级读取 PTE
  - 依据 PTE 的 `V/R/W/X/U/A/D` 等位，判断是“中间节点”还是“叶子节点”，并执行权限检查
  - 成功时计算 `*physical` 与 `*prot` 返回

#### 4.4 fill：`tlb_set_page`

当 `get_physical_address` 成功后：

- `riscv_cpu_tlb_fill` 会调用：
  - `tlb_set_page(cs, address & TARGET_PAGE_MASK, pa & TARGET_PAGE_MASK, prot, mmu_idx, TARGET_PAGE_SIZE);`
- 最终写入 `CPUTLBEntry`，完成本次 TLB fill

### 五、关键分支与循环解释（对应 Sv39 地址翻译过程）

本节对应指导书要求中的“关键调用路径 + 关键分支语句 + 循环解释”。

#### 5.1 关键分支 1：是否启用 MMU（是否需要查页表）

在 `get_physical_address` 的早期有一个非常关键的分支：

- 若 `mode == PRV_M` 或 CPU 不具备 MMU 特性（`!riscv_feature(env, RISCV_FEATURE_MMU)`）
  - 直接 `*physical = addr`，无需页表遍历

这对应“未开启虚拟地址空间（或特权级/配置使得不走页表）”的情况。

进一步细化（对应源码中的两类“无需页表遍历”的路径）：

1. `mode == PRV_M` 或 CPU 无 MMU 特性：直接 `physical = addr`
2. `satp.mode == MBARE`：同样直接 `physical = addr`

#### 5.2 关键循环：Sv39 三层页表遍历

`get_physical_address` 中的循环：

- `levels = 3`（Sv39）
- `ptshift` 初始为 `(levels - 1) * ptidxbits = 18`
- 每一轮：
  1. 计算当前层索引 `idx = (addr >> (PGSHIFT + ptshift)) & ((1 << ptidxbits) - 1)`
  2. 计算 PTE 物理地址 `pte_addr = base + idx * ptesize`
  3. 从物理内存读出 `pte = ldq_phys(cs->as, pte_addr)`
  4. 若 `pte.V == 0`：无效映射 → fail
  5. 若 `pte` 只有 `V`（无 R/W/X）：说明这是**中间页表项**，令 `base = ppn << 12` 进入下一层
  6. 若是叶子项（有 R/W/X）：执行权限与一致性检查，最终组合物理地址

**这三个循环分别对应 Sv39 的：VPN2 → VPN1 → VPN0**。

实验中 ucore 的 `boot_page_table_sv39` 直接在根页表（VPN2 层）放置 1GiB 大页叶子项，因此 page walk 循环会在 **第 1 次迭代就命中叶子项并返回**（不会真的走到 VPN1/VPN0）。

#### 5.3 关键分支 2：中间节点 vs 叶子节点

```text
if (!(pte & (PTE_R | PTE_W | PTE_X)))
    // Inner PTE, continue walking
else
    // Leaf PTE
```

- 只有 `V=1` 且 `R=W=X=0`：说明该 PTE 指向下一层页表
- 任意 `R/W/X` 有一个为 1：说明该 PTE 是叶子项（指向物理页/大页）

#### 5.4 关键分支 3：权限检查（R/W/X/U/SUM/MXR 等）

QEMU 会检查：

- `PTE_U` 与当前 `mode` 的匹配
- `MMU_DATA_LOAD / MMU_DATA_STORE / MMU_INST_FETCH` 对应 `PTE_R/PTE_W/PTE_X`
- `mstatus.MXR`：允许“X 页可读”
- `mstatus.SUM`：S-mode 是否允许访问用户页（以及取指是否被禁止）

这些分支是页表查询过程里最重要的“合法性判定”。

#### 5.5 关键分支 4：A/D 位更新与 restart 机制

在叶子 PTE 命中后，QEMU 会尝试设置：

- `A`（Accessed）
- `D`（Dirty，仅 store 时需要）

并且为支持并发（MTTCG）使用 CAS 原子更新；如果更新时发现 PTE 被改写，则 `goto restart` 重新 walk。

这点非常“硬件化”：真实硬件通常也会自动维护 A/D 位（或通过页故障让 OS 维护），QEMU 在这里用软件模拟了这种行为。

#### 5.6 示例：用 `kern_init` 的取指说明一次 Sv39 映射

ucore 的启动页表在 `entry.S` 中只设置了一个**一级（VPN2）叶子项**，把 `0xffffffffc0000000` 映射到 `0x80000000`（1GiB 大页）。

对 `kern_init`：

- 虚拟地址：`0xffffffffc02000dc`
- 根页表物理地址（来自 `.qemu.out`）：`satp physical address: 0x0000000080205000`
- `VPN2 = 0x1ff`（因此会访问根页表最后一项）
- 访问的 PTE 地址：`0x80205000 + 0x1ff * 8 = 0x80205ff8`
- 该 PTE 映射到物理基址 `0x80000000`，因此最终物理地址为：
  - `0x80000000 + (0xffffffffc02000dc - 0xffffffffc0000000) = 0x802000dc`

这条取证链是报告里最关键的一条“页表查询过程可解释证据”。

### 六、如何在 QEMU 源码中找到“查 TLB 的 C 代码”（并通过调试说明细节）

**TLB 查询**并不在 `target/riscv`，而在 TCG softmmu 的公共实现：

- `accel/tcg/cputlb.c::load_helper`（读）
- `accel/tcg/cputlb.c::store_helper`（写）
- `accel/tcg/cputlb.c::get_page_addr_code`（取指）

其中最核心的“查 TLB”语句是：

- `tlb_hit(tlb_addr, addr)`：检查 `addr_xxx` 是否命中同一页
- `victim_tlb_hit(...)`：检查 victim tlb（避免部分冲突 miss）

当 miss 时，会调用：

- `tlb_fill(...)` → `cc->tlb_fill(...)` → `riscv_cpu_tlb_fill(...)`

### 七、QEMU TLB 与真实 CPU TLB 的逻辑区别

本实验强调“逻辑差异”，而不是微结构细节。

#### 7.1 真实 CPU 的 TLB（概念层）

- 本质是硬件缓存：缓存 VPN→PPN 的翻译结果
- 通常是固定容量、（组）相联结构，替换策略由硬件实现
- miss 后由硬件 page-walk 单元遍历页表并填充（或通过异常让 OS 处理）
- TLB 条目通常包含 ASID/权限/页大小等信息（具体实现因 CPU 而异）

#### 7.2 QEMU 的 TLB（本实验观察到的实现层）

- QEMU 的 TLB 是**软件数据结构**（`CPUTLBEntry` 数组 + victim tlb）
- 它不仅缓存“VPN→PPN”，还缓存“guest 地址 → host 指针偏移（addend）/ iotlb”等信息，用于加速 softmmu 访存
- QEMU 可能动态调整 TLB 大小（与真实硬件的“固定容量 TLB”有明显不同）
- QEMU 的 TLB 还要处理 MMIO、dirty tracking、`TLB_RECHECK` 等额外语义（真实 CPU TLB 通常不携带这些“模拟器运行时”元信息）

补充：QEMU TLB 在 softmmu 场景下还需要支持“将 guest 地址快速转成 host 地址”的加速机制，因此 `CPUTLBEntry` 内的 `addend` 在命中时可以直接用于计算 host 指针（这也是为什么它不仅仅是 VPN→PPN 的缓存）。

#### 7.3 对比实验思路：开启/不开启虚拟地址空间

- **不开启虚拟地址空间**（`satp.mode = BARE` 或 QEMU 判断不需要 MMU）：
  - `get_physical_address` 会走“直接映射”分支：`physical = addr`
  - 不会发生 Sv39 的页表遍历循环
- **开启虚拟地址空间**：
  - 必然出现 `get_physical_address` 的 Sv39 walk

 虽然两者都可能会走到 `cputlb.c` 的 TLB 查询/填充框架，但“是否执行页表遍历”是最本质的分界。

### 八、建议的断点与调试策略（可复现流程）

#### 8.1 推荐观测地址

- `kern_init` 的虚拟地址：`0xffffffffc02000dc`（可从 `.qemu.out` 取证）
- `boot_page_table_sv39` 的物理地址：`0x80205000`（可从 `.qemu.out` 取证）

本实验用它来构造一条最短、最“确定会发生”的观测链：

- ucore 执行 `jr kern_init` 时的下一条取指地址（虚拟）固定为 `0xffffffffc02000dc`
- 这次取指会触发 QEMU 的 `MMU_INST_FETCH` 翻译路径

#### 8.2 Host GDB（调 QEMU）推荐断点

1. **TLB miss 入口（通用）**

- 在 `target/riscv/cpu_helper.c`：
  - `b riscv_cpu_tlb_fill if address == 0xffffffffc02000dc`

可强化为“按地址 + 按访问类型”双条件（取指为 `MMU_INST_FETCH == 2`）：

```gdb
(gdb) b riscv_cpu_tlb_fill if address == 0xffffffffc02000dc && (int)access_type == 2
```

为了更贴近“先查 TLB，再 page walk”的硬件流程，并满足“找到查 TLB 的 C 代码并通过调试说明细节”的要求，我们额外在 `accel/tcg/cputlb.c` 的取指入口下一个同样按地址过滤的条件断点：

```gdb
(gdb) b get_page_addr_code if addr == 0xffffffffc02000dc
```

2. **页表遍历入口**

- `b get_physical_address if addr == 0xffffffffc02000dc`

同时过滤 `access_type`：

```gdb
(gdb) b get_physical_address if addr == 0xffffffffc02000dc && access_type == 2
```

3. **观察 Sv39 三层循环关键变量**

- 在 `get_physical_address` 循环体内观察：
  - `base / idx / pte_addr / pte / ppn / ptshift / levels`

在 Host GDB 中命中 `get_physical_address` 后，立即打印/记录以下变量：

```gdb
(gdb) p/x env->satp
(gdb) p levels
(gdb) p ptidxbits
(gdb) p ptesize
(gdb) p/x base
(gdb) p ptshift
```

并在循环第 1 次迭代时记录：

```gdb
(gdb) p i
(gdb) p/x idx
(gdb) p/x pte_addr
(gdb) p/x pte
(gdb) p/x ppn
```

4. **观察 TLB set page**

- `b tlb_set_page`
- 或更细：`b tlb_set_page_with_attrs`

推荐使用条件断点避免过多停下：

```gdb
(gdb) b tlb_set_page_with_attrs if vaddr == 0xffffffffc0200000
```

#### 8.3 Guest GDB（调 ucore）配合方法

- 在 `kern_entry` 附近单步直到 `csrw satp` 之后，再观察下一条取指：
  - `x/10i $pc`
  - `p/x $pc`
- 一旦 guest 侧准备执行 `jr kern_init`，host 侧的条件断点就能把 QEMU 停在正确位置

如果需要在 guest 侧明确确认“下一条将要取指的虚拟地址”，可以用：

```gdb
(gdb) x/5i $pc
(gdb) p/x $pc
```

#### 8.4 条件断点的意义

QEMU 的 `load_helper/store_helper/get_page_addr_code` 调用频率极高；如果无条件断点，很容易陷入“每条指令都停一次”。

因此强烈建议使用：

- **按地址过滤**：只关注 `addr == 目标虚拟地址`
- **按访问类型过滤**：只关注 `access_type == MMU_INST_FETCH`（取指）或 `MMU_DATA_LOAD/STORE`

#### 8.5 单步演示：把一次 Sv39 翻译写成“可验证证据链”

1. **命中 `get_physical_address`**，确认：
   - `vm == VM_1_10_SV39`
   - `levels == 3`、`ptidxbits == 9`、`ptesize == 8`
   - `base == 0x80205000`（应与 `.qemu.out` 的 `satp physical address` 一致）

2. **循环第 1 次迭代（i=0，VPN2）**，看到：
   - `idx == 0x1ff`
   - `pte_addr == 0x80205ff8`（由 `base + idx * 8` 得到）
   - `pte` 的 `V/R/W/X` 位为真（叶子项）

3. **翻译结果验证**：
   - 在 `riscv_cpu_tlb_fill` 中，最终 `pa` 应为 `0x802000dc`
   - 与手工计算一致：
     - `0x80000000 + (0xffffffffc02000dc - 0xffffffffc0000000) = 0x802000dc`

4. **命中 `tlb_set_page_with_attrs`**：确认 vaddr 页对齐后被写入软件 TLB

以上 4 步即可覆盖调试要求中的“通过调试演示虚拟地址如何在 QEMU 模拟中翻译成物理地址”。

#### 8.6 对比实验：未开启虚拟地址空间（MBARE）vs 开启（Sv39）

为了回答“QEMU 的 TLB 与真实 CPU TLB 的逻辑区别”，指导书提示可以对比“未开启虚拟地址空间”的路径。这里给出一个可复现的对比方法：

1. **选择未开启虚拟内存时的一次取指地址**：ucore 初始入口通常在 `0x80200000` 左右（paging 未开启前）
2. 在 Host GDB 下断点观察：

```gdb
(gdb) b riscv_cpu_tlb_fill if address == 0x80200000 && (int)access_type == 2
(gdb) b get_physical_address
```

3. 让系统运行到命中后，在 `get_physical_address` 中你会观察到：

- `vm == VM_1_10_MBARE`，并在 `case VM_1_10_MBARE:` 分支直接 `physical = addr` 返回
- **不会执行**后续的 Sv39 多级页表遍历循环

4. 再对比 Sv39 情况（`addr == 0xffffffffc02000dc`），会进入多级 walk 逻辑。

对比结论（逻辑层）：

- 两种情况下 **都可能经过** `cputlb.c` 的 TLB 查询/填充框架（因为这是 QEMU softmmu 的通用加速机制）
- 但只有在 Sv39 等模式下，才会发生“按 `satp.ppn` 指向的页表逐级读取 PTE”的 page walk

### 九、调试过程中的有趣细节（经验）

1. **`get_physical_address` 里注释提示 `env->pc` 不可靠**
   - 源码提示：该函数内看到的 `env->pc` 未必正确，但异常处理 `riscv_cpu_do_interrupt` 中的 PC 才是正确的。

2. **Host GDB 不能直接 `x/` guest 地址来读指令**
   - host gdb 看到的是“宿主进程地址空间”，guest 虚拟地址需通过 QEMU 内部数据结构取证（例如 `ctx->opcode` / `cpu_ldl_code` 或 page walk 里的 `ldq_phys`）。

3. **调试 QEMU 进程时常见 SIGPIPE 干扰**
   - `handle SIGPIPE nostop noprint` 可以避免调试被频繁打断。

4. **为什么必须使用条件断点**
   - `load_helper/store_helper/get_page_addr_code` 触发频率极高；无条件断点会导致每条指令都停下，几乎无法推进。

### 十、大模型辅助记录

| 问题场景 | 我当时的困惑/现象 | 我问大模型的话术（示例） | 大模型给出的关键线索 | 我如何验证（证据） |
| --- | --- | --- | --- | --- |
| 定位 TLB lookup | 只在 `target/riscv` 里搜不到“查 tlb”的代码 | “QEMU-4.1.1 softmmu 下 TLB lookup 的 C 代码在哪个文件/函数？miss 后调用链是什么？” | `accel/tcg/cputlb.c::{get_page_addr_code,load_helper,store_helper}`，miss→`tlb_fill`→`riscv_cpu_tlb_fill` | grep 命中 + Host GDB 下断点命中 |
| 看懂 page walk 循环 | 不理解 `idx/pte_addr/ldq_phys` 在做什么 | “Sv39 page walk 中这三个循环每层在算什么索引？`pte_addr = base + idx*8` 对应哪一级页表？” | VPN2/VPN1/VPN0 的逐级索引与 PTE 读取 | 在 Host GDB 打印 `idx/pte_addr/pte` 与手算一致 |
| 解释 MBARE 对比 | 不清楚“未开启虚拟地址空间”时 QEMU 是否还走 TLB | “satp=BARE 时 QEMU 的翻译函数会发生什么？是否还会经过 cputlb？” | `get_physical_address` 会在 `MBARE` 分支直接 `physical=addr`；但 softmmu 仍可能缓存 | 在 Host GDB 命中 `VM_1_10_MBARE` 分支 + 对比 Sv39 |

### 十一、实验总结

本分支任务通过“双重 GDB”建立了从 ucore 的“某次访存（取指/读写）”到 QEMU 内部“TLB 命中/缺失、Sv39 页表遍历、TLB 填充”的完整证据链：

- ucore 侧：`entry.S` 写入 `satp` 并 `sfence.vma` 后，跳转到 `kern_init` 的下一条取指必然触发翻译。
- QEMU 侧：`cputlb.c` 进行软件 TLB 查询，miss 后进入 `tlb_fill`，再到 RISC-V 的 `riscv_cpu_tlb_fill`，最终在 `get_physical_address` 中执行 Sv39 walk。

通过对关键分支与循环的解释，可以把“硬件地址翻译流程”与“QEMU 软件模拟实现”一一对应，从而更扎实地理解虚拟内存与 TLB 的工作机理。