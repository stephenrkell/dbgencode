# Encoding-based approaches to generating debugging information

Compilers for C, C++ and the like traditionally support debugging by
generating extensive metadata. Not only that, but all through the
compilation pipeline, the metadata exists alongside the intermediate
representation proper. This creates a problem during compile-time
optimisation: the optimisation pass must correctly transform both the
code and the metadata, such that the two match. Quite often, the
treatment of metadata is incomplete or incorrect, and the result is to
degrade debugging. On the other hand, allowing this gives maximum
latitude for optimisation.

This repository collects tools for a completely different approach. We
encode the debuggability properties we want into the *source* program,
such that a compiler *even entirely lacking debugging information
support* will produce useful debugging information in its output. The
main trick for doing so is inline assembly, because it creates a porous
boundary between the source program and the assembly output. For
example, we can transform

```
int g(int);
int f(int x, int *vars)
    for (int i = 0; i < n; ++i)
    {
        vars[i] += g(i);
    }
    int r = vars[n-1];
    return r;
}
```
into

```
int g(int);
int f(int x, int *vars)
    for (int i = 0; i < n; ++i)
    {                         may_observe(x); may_observe(vars); may_observe(i);
        vars[i] += g(i);      may_observe(x); may_observe(vars); may_observe(i);
    }                         may_observe(x); may_observe(vars); 
    int r = vars[n-1];        may_observe(x); may_observe(vars); may_observe(r);
    return r;
}
```

where we have something like this:

```
#define may_observe(x) \
    may_observex(x, __LINE__)
#define may_observex(x, __LINE__) may_observey(x, __LINE__)
#define may_observey(x, ln) \
({ \
	asm volatile ("# OBSERVABLE: at line " #ln ", var '" #x "' is in %0 " :: "rm"(x)); \
})
```

... meaning the use of an assembly comment above has tricked the
compiler into outputting assembly like this:

```
.LCFI8:
	# OBSERVABLE: at line 80, var 'x' is in %edi 
	movl	%edi, 4(%rsp)
	movl	%edi, 8(%rsp)
	movl	%edi, 12(%rsp)
	# OBSERVABLE: at line 81, var 'x' is in %edi 
	leaq	4(%rsp), %rax
	# OBSERVABLE: at line 81, var 'vars' is in %rax 
	movq	n@GOTPCREL(%rip), %rax
	cmpl	$0, (%rax)
	jle	.L6
	movl	$0, %ebp
	leaq	4(%rsp), %r12
.L7:
	# OBSERVABLE: at line 83, var 'x' is in %ebx 
	# OBSERVABLE: at line 83, var 'vars' is in %r12 
	# OBSERVABLE: at line 83, var 'i' is in %ebp 
	movl	%ebp, %edi
	call	g@PLT
	movl	%eax, %edx
	movslq	%ebp, %rax
	imulq	$1431655766, %rax, %rax
	shrq	$32, %rax
	movl	%ebp, %ecx
	sarl	$31, %ecx
	subl	%ecx, %eax
	leal	(%rax,%rax,2), %ecx
	movl	%ebp, %eax
	subl	%ecx, %eax
	cltq
	addl	%edx, 4(%rsp,%rax,4)
	# OBSERVABLE: at line 84, var 'x' is in %ebx 
	# OBSERVABLE: at line 84, var 'vars' is in %r12 
	# OBSERVABLE: at line 84, var 'i' is in %ebp 
	addl	$1, %ebp
	movq	n@GOTPCREL(%rip), %rax
	cmpl	%ebp, (%rax)
	jg	.L7
```

... revealing the locations of the variables we annotated. Of course it
has also hampered optimisation somewhat, by forcing these variables to
be materialised. We were already somewhat wise to this, and generated
the annotation only for not-provably-dead locals (spot the deliberate
mistakes in the above).

In this space there exists a family of transformations and it is
possible some might avoid the overheads of materialisation. For example
it is possible to give expression arguments to the inline assembly
rather than simply variable arguments, forcing only the expression but
not its constituents to be materialised. There may also be useful
variations on the current inline assembly primitive, with similar but
non-identical optimisation behaviour yet cheap to implement within the
compiler (given that it already handles the very complex feature of
inline assembly!).
