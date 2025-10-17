#ifndef __KERN_MM_SLUB_PMM_H__
#define __KERN_MM_SLUB_PMM_H__

#include <pmm.h>
#include <list.h>
#include <defs.h>
#include <riscv.h>

// 简单的自旋锁定义
typedef uint32_t spinlock_t;

// SLUB缓存结构
struct kmem_cache {
    const char *name;           // 缓存名称
    size_t size;                // 对象大小
    size_t align;               // 对齐要求
    unsigned int flags;         // 标志位
    
    // 每CPU数据（内联定义，简化版本）
    struct {
        void **freelist;        // 空闲对象列表
        struct slab *slab;      // 当前使用的slab
        unsigned int tid;       // 事务ID
        spinlock_t lock;        // 锁
    } cpu_slab;
    
    // 节点数据（内联定义，简化版本）
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

// slab结构
struct slab {
    struct kmem_cache *cache;   // 所属缓存
    void *s_mem;                // slab中第一个对象的地址
    unsigned int inuse;         // 已使用对象数量
    unsigned int free;          // 空闲对象数量
    void **freelist;            // 空闲对象列表
    list_entry_t list;          // 链表节点
    uint32_t magic;             // 魔数（用于调试）
};

// SLUB内存管理器
struct slub_pmm_manager {
    struct pmm_manager base;    // 基础内存管理器
    
    // SLUB特定字段
    struct kmem_cache *kmalloc_caches[PGSHIFT + 1]; // 不同大小的缓存
    struct kmem_cache *page_cache;                 // 页分配缓存
    
    // 统计信息
    unsigned long total_allocated;
    unsigned long total_freed;
};

// 导出SLUB管理器
extern const struct pmm_manager slub_pmm_manager;

// SLUB特定函数
void slub_init(void);
struct kmem_cache *kmem_cache_create(const char *name, size_t size, size_t align, unsigned int flags);
void *kmem_cache_alloc(struct kmem_cache *cache);
void kmem_cache_free(struct kmem_cache *cache, void *obj);
void *kmalloc(size_t size);
void kfree(void *ptr);

#endif /* !__KERN_MM_SLUB_PMM_H__ */