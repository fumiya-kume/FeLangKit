#ifndef FELANG_RUNTIME_ABI_H
#define FELANG_RUNTIME_ABI_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/*
 * FeLangKit Runtime C ABI
 * Auto-generated from RuntimeABISpec v1.0.0
 *
 * This header is the canonical reference for compiler backends.
 * Do NOT edit manually; regenerate from the spec instead.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* --- Memory Management --- */

/** Allocate size bytes. Returns NULL on failure. */
void * _Nullable kk_alloc(int64_t size);

/** Reallocate ptr to new_size bytes. Returns NULL on failure. */
void * _Nullable kk_realloc(void * _Nullable ptr, int64_t new_size);

/** Free memory at ptr. No-op if ptr is NULL. */
void kk_free(void * _Nullable ptr);

/** Increment reference count for obj. */
void kk_retain(void * obj);

/** Decrement reference count for obj. Frees when count reaches 0. */
void kk_release(void * obj);

/* --- Value Creation --- */

/** Create a boxed integer value. */
void * kk_value_integer(int64_t value);

/** Create a boxed real (double) value. */
void * kk_value_real(double value);

/** Create a boxed boolean value. */
void * kk_value_boolean(bool value);

/** Create a boxed string value from a UTF-8 buffer and byte length. */
void * kk_value_string(const char * str, int64_t len);

/** Create a boxed null value. */
void * kk_value_null(void);

/* --- Value Access --- */

/** Return the type tag of a boxed value (0=int,1=real,2=bool,3=string,4=null,5=array). */
int32_t kk_value_get_tag(void * val);

/** Extract integer payload. Undefined behaviour if tag != 0. */
int64_t kk_value_get_integer(void * val);

/** Extract real payload. Undefined behaviour if tag != 1. */
double kk_value_get_real(void * val);

/** Extract boolean payload. Undefined behaviour if tag != 2. */
bool kk_value_get_boolean(void * val);

/** Extract null-terminated UTF-8 string pointer. Undefined behaviour if tag != 3. */
const char * kk_value_get_string(void * val);

/** Return byte length of string payload. Undefined behaviour if tag != 3. */
int64_t kk_value_get_string_len(void * val);

/* --- I/O --- */

/** Print a null-terminated string to stdout (no trailing newline). */
void kk_print(const char * str);

/** Print a null-terminated string to stdout followed by a newline. */
void kk_println(const char * str);

/** Read a line from stdin. Returns NULL on EOF. */
const char * _Nullable kk_input(void);

/* --- Array --- */

/** Create a new empty array with the given initial capacity. */
void * kk_array_new(int64_t capacity);

/** Return the number of elements in the array. */
int64_t kk_array_length(void * arr);

/** Return the element at the given index. Traps on out-of-bounds. */
void * kk_array_get(void * arr, int64_t index);

/** Set the element at the given index. Traps on out-of-bounds. */
void kk_array_set(void * arr, int64_t index, void * value);

/** Append value to the end of the array. */
void kk_array_push(void * arr, void * value);

/* --- Environment --- */

/** Create a new runtime environment. */
void * kk_env_new(void);

/** Destroy a runtime environment and free resources. */
void kk_env_destroy(void * env);

/** Define a variable in the current scope. */
void kk_env_define(void * env, const char * name, void * value);

/** Look up a variable by name. Returns NULL if not found. */
void * _Nullable kk_env_get(void * env, const char * name);

/** Assign a new value to an existing variable. Returns false if undefined. */
bool kk_env_set(void * env, const char * name, void * value);

/** Push a new variable scope. */
void kk_env_push_scope(void * env);

/** Pop the innermost variable scope. */
void kk_env_pop_scope(void * env);

#ifdef __cplusplus
}
#endif

#endif /* FELANG_RUNTIME_ABI_H */
