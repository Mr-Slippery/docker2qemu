#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <stdarg.h>

char *const default_environment[] = {
    "HOME=/root",
    "PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin",
    NULL,
};

void mount_check(
    const char *source, const char *target,
    const char *filesystemtype, unsigned long mountflags,
    const void *data
) {
    struct stat info;

    if (stat(target, &info) == -1 && errno == ENOENT) {
        printf("Creating %s\n", target);
        if (mkdir(target, 0755) < 0) {
            perror("Creating directory failed");
            exit(1);
        }
    }

    printf("Mounting %s\n", target);
    if (mount(source, target, filesystemtype, mountflags, data) < 0) {
        perror("Mount failed");
        exit(1);
    }
}

void fork_exec(const char *cmd) {
   pid_t pid;
   int status, died;
   switch(pid=fork()) {
   case -1: exit(-1);
   case 0 : execle("/bin/sh", "sh", "-c", cmd, NULL, default_environment); exit(0);
   default: died= wait(&status);
   }
}

int main(int argc, char *argv[]) {
    mount_check("none", "/proc", "proc", 0, "");
    mount_check("none", "/dev/pts", "devpts", 0, "");
    mount_check("none", "/dev/mqueue", "mqueue", 0, "");
    mount_check("none", "/dev/shm", "tmpfs", 0, "");
    mount_check("none", "/sys", "sysfs", 0, "");
    mount_check("none", "/sys/fs/cgroup", "cgroup", 0, "");

    sethostname("microvm", sizeof("microvm"));
    fork_exec("/usr/bin/startup.sh");
    execle("/bin/bash", "/bin/bash", NULL, default_environment);
    perror("Exec failed");
    return 1;
}
