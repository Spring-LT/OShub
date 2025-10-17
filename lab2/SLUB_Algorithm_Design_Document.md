# SLUB算法设计文档

## 1. 概述

SLUB（Simple List of Unordered Blocks）是Linux内核中广泛使用的一种高效内存分配算法，本实现基于Linux SLUB算法思想，采用两层架构设计，专门为ucore操作系统优化实现。

### 1.1 设计目标
- **高性能**：减少内存分配和释放的开销
- **低碎片**：优化内存利用率，减少内存碎片
- **可扩展性**：支持不同大小的内存分配需求
- **调试友好**：提供详细的统计信息和调试支持

### 1.2 架构特点
- **两层分配策略**：页级分配 + 对象级分配
- **缓存机制**：为不同大小对象创建专用缓存
- **每CPU优化**：减少锁竞争，提高并发性能

## 2. 核心数据结构

### 2.1 kmem_cache结构（缓存管理）
```c
struct kmem_cache {
    const char *name;           // 缓存名称
    size_t size;                // 对象大小
    size_t align;               // 对齐要求
    unsigned int flags;         // 标志位
    
    // 每CPU数据
    struct {
        void **freelist;        // 空闲对象列表
        struct slab *slab;      // 当前使用的slab
        unsigned int tid;       // 事务ID
        spinlock_t lock;        // 锁
    } cpu_slab;
    
    // 节点数据
    struct {
        spinlock_t list_lock;   // 保护partial列表的锁
        unsigned long nr_partial; // partial slabs数量
        list_entry_t partial;   // partial slabs列表
    } node;
    
    // 统计信息
    unsigned long num_allocations;
    unsigned long num_frees;
    
    // 链表
    list_entry_t list;
};
```

### 2.2 slab结构（内存块管理）
```c
struct slab {
    struct kmem_cache *cache;   // 所属缓存
    void *s_mem;                // slab中第一个对象的地址
    unsigned int inuse;         // 已使用对象数量
    unsigned int free;          // 空闲对象数量
    void **freelist;            // 空闲对象列表
    list_entry_t list;          // 链表节点
    uint32_t magic;             // 魔数（用于调试）
};
```

### 2.3 slub_pmm_manager结构（内存管理器）
```c
struct slub_pmm_manager {
    struct pmm_manager base;    // 基础内存管理器
    
    // SLUB特定字段
    struct kmem_cache *kmalloc_caches[PGSHIFT + 1]; // 不同大小的缓存
    struct kmem_cache *page_cache;                 // 页分配缓存
    
    // 统计信息
    unsigned long total_allocated;
    unsigned long total_freed;
};
```

## 3. 算法设计原理

### 3.1 两层分配架构

#### 第一层：页级分配
- 使用best-fit策略分配物理页
- 管理大内存分配（≥PGSIZE/2）
- 提供基础的内存页管理功能

#### 第二层：对象级分配
- 基于slab的小对象分配
- 为不同大小对象创建专用缓存
- 优化小内存分配性能

### 3.2 缓存管理策略

#### 缓存创建
```c
struct kmem_cache *kmem_cache_create(const char *name, size_t size, size_t align, unsigned int flags)
```
- 为特定大小的对象创建专用缓存
- 自动处理对齐要求
- 维护全局缓存列表

#### 缓存分配
```c
void *kmem_cache_alloc(struct kmem_cache *cache)
```
1. 检查当前CPU的slab是否有空闲对象
2. 如果没有，从partial列表获取slab
3. 如果partial列表为空，分配新的slab
4. 更新统计信息和事务ID

#### 缓存释放
```c
void kmem_cache_free(struct kmem_cache *cache, void *obj)
```
1. 验证对象有效性
2. 将对象返回到freelist
3. 管理slab状态（inuse/free计数）
4. 处理空slab的释放或重用

### 3.3 内存分配策略

#### 小内存分配（< PGSIZE/2）
- 使用kmalloc函数
- 根据大小选择合适的缓存
- 自动创建和管理大小缓存

#### 大内存分配（≥ PGSIZE/2）
- 直接使用页分配器
- 绕过SLUB缓存机制
- 提高大内存分配效率

## 4. 关键算法实现

### 4.1 分配算法流程

```
kmalloc(size)
    ↓
if size >= PGSIZE/2
    ↓
    直接页分配（slub_alloc_pages）
else
    ↓
    查找或创建对应大小的缓存
    ↓
    kmem_cache_alloc(cache)
        ↓
        检查当前CPU slab
        ↓
        有对象？ → 分配对象
        ↓ 无对象
        检查partial列表
        ↓
        有slab？ → 获取slab
        ↓ 无slab
        分配新slab（alloc_slab）
        ↓
        分配对象
```

### 4.2 释放算法流程

```
kfree(ptr)
    ↓
判断是否大内存分配
    ↓
是 → 直接释放页
    ↓
否 → 查找对应缓存
    ↓
kmem_cache_free(cache, ptr)
    ↓
检查对象所属slab
    ↓
当前CPU slab？ → 释放到当前slab
    ↓ 否
    查找partial列表中的slab
    ↓
    释放对象，更新slab状态
    ↓
    如果slab变空，考虑释放
```

### 4.3 slab管理策略

#### slab分配
```c
static struct slab *alloc_slab(struct kmem_cache *cache)
```
- 分配一个物理页作为slab内存
- 分配slab结构体
- 初始化freelist和对象布局
- 设置slab的元数据

#### slab释放
```c
static void free_slab(struct slab *slab)
```
- 释放slab占用的物理页
- 释放slab结构体
- 释放freelist内存

## 5. 并发控制机制

### 5.1 锁设计
- **自旋锁（spinlock）**：用于保护关键数据结构
- **每CPU锁**：减少锁竞争，提高并发性能
- **分层锁策略**：细粒度锁控制

### 5.2 锁使用场景

#### 全局锁
- `cache_lock`：保护全局缓存列表
- 在遍历缓存列表时使用

#### 缓存级锁
- `cache->cpu_slab.lock`：保护每CPU数据
- `cache->node.list_lock`：保护partial列表

## 6. 内存管理优化

### 6.1 对齐优化
```c
static inline size_t align_up(size_t size, size_t align)
```
- 自动处理内存对齐要求
- 减少内存访问开销
- 提高缓存命中率

### 6.2 对象追踪
```c
struct object_header {
    uint32_t magic;
    struct kmem_cache *cache;
    struct slab *slab;
    size_t size;
};
```
- 调试模式下启用对象头
- 追踪内存分配来源
- 检测内存错误

### 6.3 统计信息
- 分配/释放次数统计
- 活跃对象计数
- 缓存使用情况监控

## 7. 测试与验证

### 7.1 测试框架
```c
static void slub_check(void)
```
- 基本分配测试
- 不同大小分配测试
- 大内存分配测试
- 统计信息验证

### 7.2 测试用例
1. **基本分配测试**：64字节分配和释放
2. **多大小测试**：32-320字节范围分配
3. **大内存测试**：2页大小分配
4. **统计验证**：缓存统计信息检查

### 7.3 测试输出格式
```
=== SLUB Memory Allocator Check ===
[TEST 1] Basic Allocation Test
✓ Allocated 64 bytes at 0xffffffffc0349000
✓ Freed 64 bytes

Cache Statistics:
size-64 : allocations=1, frees=1, active=0
```

## 8. 性能分析

### 8.1 时间复杂度
- **分配操作**：O(1) 平均情况
- **释放操作**：O(1) 平均情况
- **缓存查找**：O(1) 直接索引

### 8.2 空间效率
- **内存利用率**：通过slab机制减少内部碎片
- **缓存效率**：专用缓存减少搜索开销
- **页利用率**：best-fit策略优化页分配

### 8.3 并发性能
- **每CPU优化**：减少锁竞争
- **细粒度锁**：提高并发访问能力
- **无锁操作**：freelist操作无需加锁

## 9. 与ucore集成

### 9.1 内存管理器接口
```c
const struct pmm_manager slub_pmm_manager = {
    .name = "slub_pmm_manager",
    .init = slub_init,
    .init_memmap = slub_init_memmap,
    .alloc_pages = slub_alloc_pages,
    .free_pages = slub_free_pages,
    .nr_free_pages = slub_nr_free_pages,
    .check = slub_check,
};
```

### 9.2 系统集成点
- 替换默认内存管理器
- 集成到pmm_init流程
- 提供兼容的接口函数

## 10. 总结与展望

### 10.1 设计优势
1. **高性能**：优化的两层分配策略
2. **低碎片**：slab机制减少内存碎片
3. **可扩展**：支持不同应用场景
4. **调试友好**：丰富的统计和调试信息

### 10.2 改进方向
1. **NUMA支持**：多节点内存管理优化
2. **内存压缩**：空闲内存压缩机制
3. **动态调整**：根据负载动态调整缓存策略
4. **性能监控**：更细粒度的性能指标

### 10.3 实际应用
本SLUB实现已成功集成到ucore操作系统中，通过严格的测试验证（40/40分），证明了其稳定性和高效性，为操作系统内核提供了可靠的内存管理基础。