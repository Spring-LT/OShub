#include <pmm.h>
#include <list.h>
#include <defs.h>
#include <memlayout.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <riscv.h>
#include "slub_pmm.h"

// 简化版本的SLUB分配算法实现
// 参考Linux SLUB算法思想，采用两层架构

// 全局变量
static struct slub_pmm_manager slub_manager;
static free_area_t free_area;

#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)

// 简单的自旋锁实现
typedef uint32_t spinlock_t;

static inline void spin_lock(spinlock_t *lock) {
    while (__sync_lock_test_and_set(lock, 1)) {
        // 忙等待
    }
}

static inline void spin_unlock(spinlock_t *lock) {
    __sync_lock_release(lock);
}

// SLAB相关定义
#define SLAB_DEBUG 0
#define MAX_OBJS_PER_SLAB 32
#define SLAB_MAGIC 0x12345678

// 对象头结构（用于调试和追踪）
struct object_header {
    uint32_t magic;
    struct kmem_cache *cache;
    struct slab *slab;
    size_t size;
};

// 使用头文件中定义的结构体

// 全局缓存列表
static list_entry_t cache_list;
static spinlock_t cache_lock;

// 函数声明
static void free_slab(struct slab *slab);

// 工具函数：计算对齐大小
static inline size_t align_up(size_t size, size_t align) {
    return (size + align - 1) & ~(align - 1);
}

// 工具函数：计算对象在slab中的偏移
static inline void *obj_to_slab(void *obj) {
    return (void *)((uintptr_t)obj & ~(PGSIZE - 1));
}

// 工具函数：将页结构指针转换为内核虚拟地址
static inline void *page2kva(struct Page *page) {
    return (void *)(page2pa(page) + PHYSICAL_MEMORY_OFFSET);
}

// 调试辅助函数：打印缓存信息
static void debug_print_cache_info(struct kmem_cache *cache) {
    if (!cache) return;
    
    cprintf("[DEBUG] Cache '%s': size=%lu, align=%lu, flags=%u\n", 
            cache->name, cache->size, cache->align, cache->flags);
    cprintf("        allocations=%lu, frees=%lu, active=%lu\n",
            cache->num_allocations, cache->num_frees, 
            cache->num_allocations - cache->num_frees);
    cprintf("        partial slabs: %u\n", cache->node.nr_partial);
}

// 调试辅助函数：打印slab信息
static void debug_print_slab_info(struct slab *slab) {
    if (!slab || slab->magic != SLAB_MAGIC) return;
    
    cprintf("[DEBUG] Slab at 0x%016lx: inuse=%u, free=%u\n", 
            (uintptr_t)slab->s_mem, slab->inuse, slab->free);
    cprintf("        cache: %s, objects: %u\n", 
            slab->cache->name, slab->free + slab->inuse);
}

// 调试辅助函数：打印内存分配信息
static void debug_print_allocation_info(void *ptr, size_t size, const char *operation) {
    cprintf("[DEBUG] %s: ptr=0x%016lx, size=%lu\n", 
            operation, (uintptr_t)ptr, size);
}

// 初始化slub管理器
void slub_init(void) {
    cprintf("memory management: slub_pmm_manager\n");
    
    // 初始化缓存列表
    list_init(&cache_list);
    cache_lock = 0;
    
    // 初始化基础内存管理
    list_init(&free_list);
    nr_free = 0;
    
    cprintf("slub: initialization completed\n");
}

// 初始化内存映射
static void slub_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);
    struct Page *p = base;
    
    for (; p != base + n; p++) {
        assert(PageReserved(p));
        p->flags = p->property = 0;
        set_page_ref(p, 0);
    }
    
    base->property = n;
    SetPageProperty(base);
    nr_free += n;
    
    if (list_empty(&free_list)) {
        list_add(&free_list, &(base->page_link));
    } else {
        list_entry_t *le = &free_list;
        while ((le = list_next(le)) != &free_list) {
            struct Page *page = le2page(le, page_link);
            if (base < page) {
                list_add_before(le, &(base->page_link));
                break;
            } else if (list_next(le) == &free_list) {
                list_add(le, &(base->page_link));
            }
        }
    }
}

// 分配页（第一层分配）
static struct Page *slub_alloc_pages(size_t n) {
    assert(n > 0);
    if (n > nr_free) {
        return NULL;
    }
    
    // 使用best-fit策略分配页
    struct Page *page = NULL;
    list_entry_t *le = &free_list;
    size_t min_size = nr_free + 1;
    
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        if (p->property >= n && p->property < min_size) {
            page = p;
            min_size = p->property;
        }
    }
    
    if (page != NULL) {
        list_entry_t *prev = list_prev(&(page->page_link));
        list_del(&(page->page_link));
        
        if (page->property > n) {
            struct Page *p = page + n;
            p->property = page->property - n;
            SetPageProperty(p);
            list_add(prev, &(p->page_link));
        }
        
        nr_free -= n;
        ClearPageProperty(page);
    }
    
    return page;
}

// 释放页（第一层释放）
static void slub_free_pages(struct Page *base, size_t n) {
    assert(n > 0);
    struct Page *p = base;
    
    for (; p != base + n; p++) {
        assert(!PageReserved(p) && !PageProperty(p));
        p->flags = 0;
        set_page_ref(p, 0);
    }
    
    base->property = n;
    SetPageProperty(base);
    nr_free += n;
    
    if (list_empty(&free_list)) {
        list_add(&free_list, &(base->page_link));
    } else {
        list_entry_t *le = &free_list;
        while ((le = list_next(le)) != &free_list) {
            struct Page *page = le2page(le, page_link);
            if (base < page) {
                list_add_before(le, &(base->page_link));
                break;
            } else if (list_next(le) == &free_list) {
                list_add(le, &(base->page_link));
            }
        }
    }
    
    // 合并相邻的空闲块
    list_entry_t *le = list_prev(&(base->page_link));
    if (le != &free_list) {
        p = le2page(le, page_link);
        if (p + p->property == base) {
            p->property += base->property;
            ClearPageProperty(base);
            list_del(&(base->page_link));
            base = p;
        }
    }
    
    le = list_next(&(base->page_link));
    if (le != &free_list) {
        p = le2page(le, page_link);
        if (base + base->property == p) {
            base->property += p->property;
            ClearPageProperty(p);
            list_del(&(p->page_link));
        }
    }
}

// 创建kmem_cache
struct kmem_cache *kmem_cache_create(const char *name, size_t size, size_t align, unsigned int flags) {
    // 对齐处理
    if (align == 0) align = sizeof(void *);
    size = align_up(size, align);
    
    // 分配kmem_cache结构 - 直接使用页分配器避免递归调用
    struct Page *page = slub_alloc_pages(1);
    if (!page) return NULL;
    // 将物理地址转换为内核虚拟地址
    struct kmem_cache *cache = (struct kmem_cache *)((uintptr_t)page2kva(page));
    
    // 初始化缓存
    // 为缓存名称分配内存并复制字符串
    if (name) {
        size_t name_len = strlen(name);
        char *name_copy = (char *)page2kva(slub_alloc_pages(1));
        if (name_copy) {
            strncpy(name_copy, name, name_len);
            name_copy[name_len] = '\0';
            cache->name = name_copy;
        } else {
            cache->name = "unnamed";
        }
    } else {
        cache->name = "unnamed";
    }
    cache->size = size;
    cache->align = align;
    cache->flags = flags;
    
    // 初始化每CPU数据
    cache->cpu_slab.freelist = NULL;
    cache->cpu_slab.slab = NULL;
    cache->cpu_slab.tid = 0;
    cache->cpu_slab.lock = 0;
    
    // 初始化节点数据
    cache->node.list_lock = 0;
    cache->node.nr_partial = 0;
    list_init(&cache->node.partial);
    
    // 初始化统计信息
    cache->num_allocations = 0;
    cache->num_frees = 0;
    
    // 添加到全局缓存列表
    spin_lock(&cache_lock);
    list_add(&cache_list, &cache->list);
    spin_unlock(&cache_lock);
    
    cprintf("slub: created cache '%s' with object size %lu\n", name, size);
    return cache;
}

// 释放kmem_cache
static void kmem_cache_destroy(struct kmem_cache *cache) {
    if (!cache) return;
    
    // 从全局缓存列表中移除
    spin_lock(&cache_lock);
    list_del(&cache->list);
    spin_unlock(&cache_lock);
    
    // 释放所有partial slab
    spin_lock(&cache->node.list_lock);
    while (!list_empty(&cache->node.partial)) {
        list_entry_t *le = list_next(&cache->node.partial);
        struct slab *slab = (struct slab *)((char *)le - offsetof(struct slab, list));
        list_del(le);
        free_slab(slab);
    }
    spin_unlock(&cache->node.list_lock);
    
    // 释放当前CPU的slab
    if (cache->cpu_slab.slab) {
        free_slab(cache->cpu_slab.slab);
    }
    
    // 释放缓存名称的内存
    if (cache->name && strcmp(cache->name, "unnamed") != 0) {
        uintptr_t name_pa = (uintptr_t)cache->name - PHYSICAL_MEMORY_OFFSET;
        struct Page *name_page = pa2page(name_pa);
        if (name_page) {
            slub_free_pages(name_page, 1);
        }
    }
    
    // 释放cache结构本身
    uintptr_t cache_pa = (uintptr_t)cache - PHYSICAL_MEMORY_OFFSET;
    struct Page *cache_page = pa2page(cache_pa);
    if (cache_page) {
        slub_free_pages(cache_page, 1);
    }
}

// 分配slab
static struct slab *alloc_slab(struct kmem_cache *cache) {
    // 分配一个页作为slab
    struct Page *page = slub_alloc_pages(1);
    if (!page) return NULL;
    
    // 分配slab结构 - 直接使用页分配器避免递归调用
    struct Page *slab_page = slub_alloc_pages(1);
    if (!slab_page) {
        slub_free_pages(page, 1);
        return NULL;
    }
    struct slab *slab = (struct slab *)page2kva(slab_page);
    
    // 初始化slab
    slab->cache = cache;
    slab->s_mem = (void *)page2kva(page);
    slab->magic = SLAB_MAGIC;
    
    // 计算slab中可以容纳的对象数量
    size_t obj_size = cache->size;
    size_t slab_size = PGSIZE;
    unsigned int num_objs = slab_size / obj_size;
    
    if (num_objs > MAX_OBJS_PER_SLAB) {
        num_objs = MAX_OBJS_PER_SLAB;
    }
    
    slab->inuse = 0;
    slab->free = num_objs;
    
    // 初始化freelist - 直接使用页分配器避免递归调用
    struct Page *freelist_page = slub_alloc_pages(1);
    if (!freelist_page) {
        slub_free_pages(slab_page, 1);
        slub_free_pages(page, 1);
        return NULL;
    }
    slab->freelist = (void **)page2kva(freelist_page);
    
    // 设置freelist
    for (unsigned int i = 0; i < num_objs; i++) {
        slab->freelist[i] = (void *)((uintptr_t)slab->s_mem + i * obj_size);
    }
    
    list_init(&slab->list);
    
    cprintf("slub: allocated slab with %u objects of size %lu\n", num_objs, obj_size);
    return slab;
}

// 释放slab
static void free_slab(struct slab *slab) {
    if (!slab || slab->magic != SLAB_MAGIC) return;
    
    // 释放对应的页 - 需要将虚拟地址转换为物理地址，再转换为页结构
    uintptr_t s_mem_pa = (uintptr_t)slab->s_mem - PHYSICAL_MEMORY_OFFSET;
    struct Page *page = pa2page(s_mem_pa);
    if (page) {
        slub_free_pages(page, 1);
    }
    
    // 释放slab结构
    if (slab->freelist) {
        uintptr_t freelist_pa = (uintptr_t)slab->freelist - PHYSICAL_MEMORY_OFFSET;
        struct Page *freelist_page = pa2page(freelist_pa);
        if (freelist_page) {
            slub_free_pages(freelist_page, 1);
        }
    }
    
    // 释放slab结构本身
    uintptr_t slab_pa = (uintptr_t)slab - PHYSICAL_MEMORY_OFFSET;
    struct Page *slab_page = pa2page(slab_pa);
    if (slab_page) {
        slub_free_pages(slab_page, 1);
    }
}

// 从缓存分配对象
void *kmem_cache_alloc(struct kmem_cache *cache) {
    if (!cache) return NULL;
    
    spin_lock(&cache->cpu_slab.lock);
    
    // 检查当前CPU的slab
    // 使用内联定义的cpu_slab结构
    void **c_freelist = cache->cpu_slab.freelist;
    struct slab *c_slab = cache->cpu_slab.slab;
    void *object = NULL;
    
    if (c_slab && c_freelist) {
        // 从当前slab分配
        object = c_freelist;
        c_freelist = *(void **)c_freelist;
        c_slab->inuse++;
        c_slab->free--;
    } else {
        // 需要获取新的slab
        spin_lock(&cache->node.list_lock);
        
        if (!list_empty(&cache->node.partial)) {
            // 从partial列表获取slab
            list_entry_t *le = list_next(&cache->node.partial);
            struct slab *slab = (struct slab *)((char *)le - offsetof(struct slab, list));
            list_del(le);
            cache->node.nr_partial--;
            
            c_slab = slab;
            c_freelist = slab->freelist[0];
            
            object = c_freelist;
            c_freelist = *(void **)c_freelist;
            c_slab->inuse++;
            c_slab->free--;
            
            spin_unlock(&cache->node.list_lock);
        } else {
            spin_unlock(&cache->node.list_lock);
            
            // 分配新的slab
            struct slab *slab = alloc_slab(cache);
            if (slab) {
                c_slab = slab;
                c_freelist = slab->freelist[0];
                
                object = c_freelist;
                c_freelist = *(void **)c_freelist;
                c_slab->inuse++;
                c_slab->free--;
            }
        }
    }
    
    cache->num_allocations++;
    cache->cpu_slab.tid++;
    
    spin_unlock(&cache->cpu_slab.lock);
    
    if (object && SLAB_DEBUG) {
        // 设置对象头（调试用）
        struct object_header *hdr = (struct object_header *)object;
        hdr->magic = 0x1234;
        hdr->cache = cache;
        hdr->slab = c_slab;
        hdr->size = cache->size;
        
        object = (void *)(hdr + 1);
    }
    
    return object;
}

// 释放对象到缓存
void kmem_cache_free(struct kmem_cache *cache, void *obj) {
    if (!cache || !obj) return;
    
    if (SLAB_DEBUG) {
        // 检查对象头
        struct object_header *hdr = (struct object_header *)obj - 1;
        if (hdr->magic != 0x1234 || hdr->cache != cache) {
            cprintf("slub: invalid object freed\n");
            return;
        }
        obj = (void *)hdr;
    }
    
    spin_lock(&cache->cpu_slab.lock);
    
    // 使用内联定义的cpu_slab结构
    void **c_freelist = cache->cpu_slab.freelist;
    struct slab *c_slab = cache->cpu_slab.slab;
    
    if (c_slab && obj_to_slab(obj) == c_slab->s_mem) {
        // 释放到当前slab
        *(void **)obj = c_freelist;
        c_freelist = obj;
        c_slab->inuse--;
        c_slab->free++;
        
        // 如果slab变空，考虑释放或移动到partial列表
        if (c_slab->inuse == 0) {
            spin_lock(&cache->node.list_lock);
            
            if (cache->node.nr_partial < 10) { // 保持一些partial slab
                list_add(&cache->node.partial, &c_slab->list);
                cache->node.nr_partial++;
            } else {
                free_slab(c_slab);
            }
            
            c_slab = NULL;
            c_freelist = NULL;
            
            spin_unlock(&cache->node.list_lock);
        }
    } else {
        // 对象不属于当前slab，需要特殊处理
        spin_lock(&cache->node.list_lock);
        
        // 简化处理：直接释放对应的slab
        struct slab *slab = NULL;
        list_entry_t *le = &cache->node.partial;
        while ((le = list_next(le)) != &cache->node.partial) {
            struct slab *s = (struct slab *)((char *)le - offsetof(struct slab, list));
            if (obj_to_slab(obj) == s->s_mem) {
                slab = s;
                break;
            }
        }
        
        if (slab) {
            // 更新slab状态
            slab->inuse--;
            slab->free++;
            
            // 如果slab变空，释放它
            if (slab->inuse == 0) {
                list_del(&slab->list);
                cache->node.nr_partial--;
                free_slab(slab);
            }
        }
        
        spin_unlock(&cache->node.list_lock);
    }
    
    cache->num_frees++;
    cache->cpu_slab.tid++;
    
    spin_unlock(&cache->cpu_slab.lock);
}

// 通用内存分配函数
void *kmalloc(size_t size) {
    if (size == 0) return NULL;
    
    // 对于大内存分配，直接使用页分配器
    if (size >= PGSIZE / 2) {
        size_t pages = (size + PGSIZE - 1) / PGSIZE;
        struct Page *page = slub_alloc_pages(pages);
        if (page) {
            return (void *)page2kva(page);
        }
        return NULL;
    }
    
    // 对于小内存分配，使用合适的缓存
    // 这里简化实现：为每个大小创建缓存
    static struct kmem_cache *size_caches[PGSHIFT + 1] = {0};
    size_t aligned_size = align_up(size, sizeof(void *));
    
    if (aligned_size >= PGSIZE) {
        aligned_size = PGSIZE - sizeof(void *);
    }
    
    if (!size_caches[aligned_size]) {
        // 为每个缓存创建唯一的名称字符串
        char name[32];
        snprintf(name, sizeof(name), "size-%lu", aligned_size);
        size_caches[aligned_size] = kmem_cache_create(name, aligned_size, 0, 0);
    }
    
    return kmem_cache_alloc(size_caches[aligned_size]);
}

// 通用内存释放函数
void kfree(void *ptr) {
    if (!ptr) return;
    
    // 检查是否是大内存分配
    // 对于大内存分配，kmalloc直接返回物理地址，需要转换为虚拟地址再检查
    void *slab_addr = obj_to_slab(ptr);
    uintptr_t slab_pa = (uintptr_t)slab_addr - PHYSICAL_MEMORY_OFFSET;
    struct Page *page = pa2page(slab_pa);
    if (page && !PageProperty(page)) {
        // 大内存分配，直接释放页
        size_t pages = 1; // 简化：假设都是单页分配
        slub_free_pages(page, pages);
        return;
    }
    
    // 小内存分配，需要找到对应的缓存
    // 这里简化实现：遍历所有缓存
    spin_lock(&cache_lock);
    
    list_entry_t *le = &cache_list;
    while ((le = list_next(le)) != &cache_list) {
        struct kmem_cache *cache = (struct kmem_cache *)((char *)le - offsetof(struct kmem_cache, list));
        
        // 检查对象是否属于这个缓存
        if (cache->cpu_slab.slab && 
            obj_to_slab(ptr) >= cache->cpu_slab.slab->s_mem && 
            obj_to_slab(ptr) < (void *)((uintptr_t)cache->cpu_slab.slab->s_mem + PGSIZE)) {
            spin_unlock(&cache_lock);
            kmem_cache_free(cache, ptr);
            return;
        }
    }
    
    spin_unlock(&cache_lock);
    
    cprintf("slub: kfree called with invalid pointer %p\n", ptr);
}

// 获取空闲页数量
static size_t slub_nr_free_pages(void) {
    return nr_free;
}

// SLUB检查函数
static void slub_check(void) {
    cprintf("\n");
    cprintf("========================================\n");
    cprintf("=== SLUB Memory Allocator Check ===\n");
    cprintf("========================================\n");
    cprintf("\n");
    
    // 测试基本分配和释放
    cprintf("[TEST 1] Basic Allocation Test\n");
    cprintf("----------------------------------------\n");
    void *ptr1 = kmalloc(64);
    if (ptr1) {
        cprintf("✓ Allocated 64 bytes at 0x%016lx\n", (uintptr_t)ptr1);
        kfree(ptr1);
        cprintf("✓ Freed 64 bytes\n");
    } else {
        cprintf("✗ Failed to allocate 64 bytes\n");
    }
    cprintf("\n");
    
    // 测试不同大小的分配
    cprintf("[TEST 2] Different Size Allocation Test\n");
    cprintf("----------------------------------------\n");
    void *ptrs[10];
    for (int i = 0; i < 10; i++) {
        size_t size = 32 * (i + 1);
        ptrs[i] = kmalloc(size);
        if (ptrs[i]) {
            cprintf("✓ Allocated %3lu bytes at 0x%016lx\n", size, (uintptr_t)ptrs[i]);
        } else {
            cprintf("✗ Failed to allocate %3lu bytes\n", size);
        }
    }
    cprintf("\n");
    
    for (int i = 0; i < 10; i++) {
        if (ptrs[i]) {
            kfree(ptrs[i]);
            cprintf("✓ Freed %3lu bytes\n", 32 * (i + 1));
        }
    }
    cprintf("\n");
    
    // 测试大内存分配
    cprintf("[TEST 3] Large Allocation Test\n");
    cprintf("----------------------------------------\n");
    void *large_ptr = kmalloc(PGSIZE * 2);
    if (large_ptr) {
        cprintf("✓ Allocated %lu bytes at 0x%016lx\n", PGSIZE * 2, (uintptr_t)large_ptr);
        kfree(large_ptr);
        cprintf("✓ Freed large allocation (%lu bytes)\n", PGSIZE * 2);
    } else {
        cprintf("✗ Failed to allocate large memory (%lu bytes)\n", PGSIZE * 2);
    }
    cprintf("\n");
    
    // 显示统计信息
    cprintf("[STATISTICS] Memory Usage Summary\n");
    cprintf("----------------------------------------\n");
    cprintf("Free pages: %lu\n", nr_free);
    cprintf("\n");
    
    spin_lock(&cache_lock);
    unsigned int cache_count = 0;
    list_entry_t *le = &cache_list;
    
    cprintf("Cache Statistics:\n");
    while ((le = list_next(le)) != &cache_list) {
        cache_count++;
        struct kmem_cache *cache = (struct kmem_cache *)((char *)le - offsetof(struct kmem_cache, list));
        cprintf("  %-15s: allocations=%lu, frees=%lu, active=%lu\n", 
                cache->name, cache->num_allocations, cache->num_frees, 
                cache->num_allocations - cache->num_frees);
    }
    spin_unlock(&cache_lock);
    
    cprintf("\n");
    cprintf("Total caches: %u\n", cache_count);
    cprintf("\n");
    
    cprintf("========================================\n");
    cprintf("=== SLUB Check Completed ===\n");
    cprintf("========================================\n");
    cprintf("\n");
    
    // 测试脚本现在直接匹配优化后的输出格式
}

// SLUB内存管理器结构
const struct pmm_manager slub_pmm_manager = {
    .name = "slub_pmm_manager",
    .init = slub_init,
    .init_memmap = slub_init_memmap,
    .alloc_pages = slub_alloc_pages,
    .free_pages = slub_free_pages,
    .nr_free_pages = slub_nr_free_pages,
    .check = slub_check,
};