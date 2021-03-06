dnl # 
dnl # Handle differences in kernel FPU code.
dnl #
dnl # Kernel
dnl # 5.2:	The fpu->initialized flag was replaced by TIF_NEED_FPU_LOAD.
dnl #		HAVE_KERNEL_TIF_NEED_FPU_LOAD
dnl #
dnl # 5.0:	As an optimization SIMD operations performed by kernel
dnl #		threads can skip saving and restoring their FPU context.
dnl #		Wrappers have been introduced to determine the running
dnl #		context and use either the SIMD or generic implementation.
dnl #		This change was made to the 4.19.38 and 4.14.120 LTS kernels.
dnl #		HAVE_KERNEL_FPU_INITIALIZED
dnl #
dnl # 4.2:	Use __kernel_fpu_{begin,end}()
dnl #		HAVE_UNDERSCORE_KERNEL_FPU & KERNEL_EXPORTS_X86_FPU
dnl #
dnl # Pre-4.2:	Use kernel_fpu_{begin,end}()
dnl #		HAVE_KERNEL_FPU & KERNEL_EXPORTS_X86_FPU
dnl #
dnl # N.B. The header check is performed before all other checks since it
dnl # depends on HAVE_KERNEL_FPU_API_HEADER being set in confdefs.h.
dnl #
AC_DEFUN([ZFS_AC_KERNEL_FPU_HEADER], [
	AC_MSG_CHECKING([whether fpu headers are available])
	ZFS_LINUX_TRY_COMPILE([
		#include <linux/module.h>
		#include <asm/fpu/api.h>
	],[
	],[
		AC_DEFINE(HAVE_KERNEL_FPU_API_HEADER, 1,
		    [kernel has asm/fpu/api.h])
		AC_MSG_RESULT(asm/fpu/api.h)
	],[
		AC_MSG_RESULT(i387.h & xcr.h)
	])
])

AC_DEFUN([ZFS_AC_KERNEL_SRC_FPU], [
	ZFS_LINUX_TEST_SRC([kernel_fpu], [
		#ifdef HAVE_KERNEL_FPU_API_HEADER
		#include <asm/fpu/api.h>
		#else
		#include <asm/i387.h>
		#include <asm/xcr.h>
		#endif
	], [
		kernel_fpu_begin();
		kernel_fpu_end();
	], [], [$ZFS_META_LICENSE])

	ZFS_LINUX_TEST_SRC([__kernel_fpu], [
		#ifdef HAVE_KERNEL_FPU_API_HEADER
		#include <asm/fpu/api.h>
		#else
		#include <asm/i387.h>
		#include <asm/xcr.h>
		#endif
	], [
		__kernel_fpu_begin();
		__kernel_fpu_end();
	], [], [$ZFS_META_LICENSE])

	ZFS_LINUX_TEST_SRC([fpu_initialized], [
		#include <linux/module.h>
		#include <linux/sched.h>
	],[
		struct fpu *fpu = &current->thread.fpu;
		if (fpu->initialized) { return (0); };
	])

	ZFS_LINUX_TEST_SRC([tif_need_fpu_load], [
		#include <linux/module.h>
		#include <asm/thread_info.h>

		#if !defined(TIF_NEED_FPU_LOAD)
		#error "TIF_NEED_FPU_LOAD undefined"
		#endif
	],[])
])

AC_DEFUN([ZFS_AC_KERNEL_FPU], [
	dnl #
	dnl # Legacy kernel
	dnl #
	AC_MSG_CHECKING([whether kernel fpu is available])
	ZFS_LINUX_TEST_RESULT_SYMBOL([kernel_fpu_license],
	    [kernel_fpu_begin], [arch/x86/kernel/fpu/core.c], [
		AC_MSG_RESULT(kernel_fpu_*)
		AC_DEFINE(HAVE_KERNEL_FPU, 1,
		    [kernel has kernel_fpu_* functions])
		AC_DEFINE(KERNEL_EXPORTS_X86_FPU, 1,
		    [kernel exports FPU functions])
	],[
		dnl #
		dnl # Linux 4.2 kernel
		dnl #
		ZFS_LINUX_TEST_RESULT_SYMBOL([__kernel_fpu_license],
		    [__kernel_fpu_begin],
		    [arch/x86/kernel/fpu/core.c arch/x86/kernel/i387.c], [
			AC_MSG_RESULT(__kernel_fpu_*)
			AC_DEFINE(HAVE_UNDERSCORE_KERNEL_FPU, 1,
			    [kernel has __kernel_fpu_* functions])
			AC_DEFINE(KERNEL_EXPORTS_X86_FPU, 1,
			    [kernel exports FPU functions])
		],[
			dnl #
			dnl # Linux 5.0 kernel
			dnl #
			ZFS_LINUX_TEST_RESULT([fpu_initialized], [
				AC_MSG_RESULT(fpu.initialized)
				AC_DEFINE(HAVE_KERNEL_FPU_INITIALIZED, 1,
				    [kernel fpu.initialized exists])
			],[
				dnl #
				dnl # Linux 5.2 kernel
				dnl #
				ZFS_LINUX_TEST_RESULT([tif_need_fpu_load], [
					AC_MSG_RESULT(TIF_NEED_FPU_LOAD)
					AC_DEFINE(
					    HAVE_KERNEL_TIF_NEED_FPU_LOAD, 1,
					    [kernel TIF_NEED_FPU_LOAD exists])
				],[
					AC_MSG_RESULT(unavailable)
				])
			])
		])
	])
])
