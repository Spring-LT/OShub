# LAB8

**23级信息安全  2310411 李听泉**

**23级信息安全  2313876 李子凝**

**23级信息安全  2312092 李朝阳**

> [!NOTE]
>
> **小组分工：**
>
> 李子凝：负责challenge2实现以及OS与实验之间的知识点
>
> 李朝阳：负责challenge1实现以及练习2内容
>
> 李听泉：负责challenge3以及练习一

----

## 练习1：理解文件系统与I/O缓冲机制（思考题）

### 1.1 SFS文件系统的I/O流程

请描述在 `sfs_io_nolock` 中，文件读写操作的完整流程，包括：
- 如何处理非对齐的起始块和结束块
- 如何通过 `sfs_bmap_load_nolock` 获取磁盘块号
- 与 `iobuf` 机制的交互关系

**回答：**
- `sfs_io_nolock` 将 I/O 请求分为三阶段处理：起始部分块、中间完整块、结束部分块。
- 首先计算 `blkoff = offset % SFS_BLKSIZE`，若非零则通过 `sfs_bmap_load_nolock` 获取块号并调用 `sfs_buf_op` 进行部分读写。
- 中间完整块循环调用 `sfs_block_op` 进行整块读写，每次递增 `blkno` 和 `offset`。
- 结束部分块同样通过 `sfs_bmap_load_nolock` + `sfs_buf_op` 处理。
- `sfs_io` 在外层加锁，并在 `sfs_io_nolock` 返回后调用 `iobuf_skip` 更新 `iobuf` 的 `io_base`、`io_offset` 与 `io_resid`，实现缓冲区指针推进。

### 1.2 文件描述符与进程文件表

请说明在 `do_fork` 中如何复制父进程的文件描述符表，以及在 `do_execve` 中如何关闭所有文件描述符。

**回答：**
- `do_fork` 调用 `copy_files(clone_flags, proc)`，通过 `files_count` 计数管理共享或复制；若不共享则复制 `fd_array` 并增加引用计数。
- `do_execve` 在加载新程序前调用 `files_closeall(current->filesp)`，遍历文件描述符表，对所有打开的文件调用 `file_close`，释放资源并重置状态。

----

## 练习2：实现基于文件系统的进程加载（编程题）

### 2.1 `load_icode` 的实现要点

请概述 `load_icode(int fd, int argc, char **kargv)` 的实现步骤，并说明如何通过文件描述符加载 ELF 程序。

**实现步骤：**
1. 创建新进程的 `mm_struct` 与页目录 `setup_pgdir`。
2. 通过 `load_icode_read(fd, &elf, sizeof(elfhdr), 0)` 读取 ELF 头，校验魔数。
3. 读取程序头表，遍历所有 `PT_LOAD` 段：
   - 调用 `mm_map` 建立 VMA。
   - 对每个段，调用 `pgdir_alloc_page` 分配物理页，通过 `load_icode_read` 从文件读取内容并拷贝到页中。
   - 对 BSS 部分（`p_filesz < p_memsz`）`memset` 清零。
4. 建立用户栈 VMA，分配 4 页栈空间。
5. 设置 `current->mm`、`pgdir`，调用 `lsatp` 切换页表。
6. 在用户栈中构造 `argc` 与 `argv` 指针数组，通过 `copy_to_user` 写入用户空间。
7. 设置 `trapframe`：`epc` 设为程序入口，`sp` 为栈顶，`status` 清除 `SPP` 并置 `SPIE`，确保返回用户态。

### 2.2 关键函数调用关系

```
do_execve
 ├─ sysfile_open
 ├─ load_icode(fd, argc, kargv)
 │   ├─ load_icode_read (读取 ELF 头与程序头)
 │   ├─ mm_create / setup_pgdir
 │   ├─ mm_map (建立 VMA)
 │   ├─ pgdir_alloc_page (分配物理页)
 │   ├─ load_icode_read (加载段内容)
 │   └─ copy_to_user (写入 argv 到用户栈)
 └─ set_proc_name
```

----

## 练习3：文件系统与调度器集成（思考题）

### 3.1 调度器中的进程切换

请说明在 `proc_run` 中为何要在 `switch_to` 前调用 `flush_tlb`，以及与 `lsatp` 的配合关系。

**回答：**
- `lsatp(next->pgdir)` 更新 SATP 寄存器指向新进程的页目录基址，切换地址空间。
- `flush_tlb` 清空 TLB，防止旧进程的页表缓存影响新进程的地址翻译，保证地址空间隔离。
- `switch_to` 完成上下文切换（寄存器/PC）。顺序必须为：更新页目录 → 刷新 TLB → 切换上下文。

### 3.2 Stride 调度器的优先级处理

在 `stride_enqueue` 中如何处理 `lab6_priority` 为 0 的情况？在 `stride_pick_next` 中如何计算步长？

**回答：**
- `stride_enqueue` 若发现 `proc->lab6_priority == 0`，则强制设为 1，避免除零错误。
- `stride_pick_next` 计算步长：`proc->lab6_stride += BIG_STRIDE / priority`，其中 `BIG_STRIDE = 1 << 30`，优先级越高步长越小，调度频率越高。

----

## Challenge 1：实现文件系统写操作（扩展）

### 1.1 写路径的设计

在 `sfs_io_nolock` 中，`write` 布尔值决定调用 `sfs_wbuf` / `sfs_wblock`。写操作需要：
- 若写入超出文件末尾，更新 `sin->din->size` 并标记 `dirty`。
- 对未分配的块，通过 `sfs_bmap_get_nolock` 分配新块并更新索引。

### 1.2 关键修改点

- `sfs_bmap_load_nolock` 在 `create` 为真时调用 `sfs_bmap_get_nolock` 分配新块，并递增 `din->blocks`。
- `sfs_io_nolock` 结尾处，若 `offset + alen > sin->din->size` 则更新文件大小并置脏标记。

（注：本次实验主要完成读路径，写路径为扩展设计）

----

## Challenge 2：支持多级目录（设计）

### 2.1 目录项结构

设计 `struct sfs_dentry` 包含 `ino`、`name[FILENAME_MAX]`、`next` 指针，用于链式管理。

### 2.2 路径解析

在 `vfs_lookup` 中递归或迭代解析路径分量：
- 每次调用 `vop_lookup` 在当前 inode 下查找下一级目录项。
- 若为目录，则递归进入；若为文件，则返回 inode。

### 2.3 创建与删除

- `vop_mkdir`：分配新 inode，初始化为目录类型，插入父目录的目录项链表。
- `vop_unlink`：从父目录链表中移除目录项，递减 inode 引用计数。

（设计要点：保持与现有 VFS 接口兼容，扩展 SFS 磁盘 inode 格式支持目录类型）

----

## Challenge 3：实现管道（pipe）机制（设计）

### 3.1 管道的数据结构

```c
struct pipe_inode {
    struct inode inode;
    char *buffer;          // 环形缓冲区
    size_t size;           // 缓冲区大小
    size_t head, tail;     // 读写指针
    wait_queue_t read_q;   // 读等待队列
    wait_queue_t write_q;  // 写等待队列
};
```

### 3.2 pipe_read 与 pipe_write

- `pipe_read`：若缓冲区为空且写入端未关闭，则进程在 `read_q` 上睡眠；唤醒写入者。
- `pipe_write`：若缓冲区满且读取端未关闭，则进程在 `write_q` 上睡眠；唤醒读取者。

### 3.3 文件系统接口

在 `sys_pipe` 中创建一对文件描述符，分别绑定到管道的读端与写端，通过 `file->pipe_inode` 指向同一管道对象，实现进程间通信。

（设计要点：环形缓冲区同步、阻塞/唤醒机制、文件描述符管理）

----

## 实验总结

本次 Lab8 完成了：
- 文件系统 I/O 核心路径 `sfs_io_nolock` 的实现，支持非对齐读写与块映射。
- 进程加载机制 `load_icode`，通过文件描述符从磁盘加载 ELF 程序，建立完整用户态执行环境。
- 文件描述符在 `fork`/`exec` 中的复制与关闭逻辑，确保资源正确管理。
- 调度器与地址空间切换的配合（`lsatp` + `flush_tlb`），保证进程隔离。
- 通过 `make grade` 验证，最终得分 100/100，所有功能测试通过。

通过本实验，深入理解了文件系统与进程管理的集成，掌握了用户态程序加载、I/O 缓冲、地址空间切换等核心机制。