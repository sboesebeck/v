module builtin

pub struct array {
pub:
	data voidptr
	len int
	cap int
	element_size int
}

// for now off the stack
fn new_array_from_c_array(len, cap, elm_size int, c_array voidptr) array {
	arr := array {
		len: len
		cap: cap
		element_size: elm_size
		data: c_array
	}
	return arr
}

// Private function. Used to implement array[] operator
fn (a array) get(i int) voidptr {
	if i < 0 || i >= a.len {
		panic('array.get: index out of range') // FIXME: (i == $i, a.len == $a.len)')
	}
	return a.data + i * a.element_size
}

// Private function. Used to implement assigment to the array element.
fn (a mut array) set(i int, val voidptr) {
	if i < 0 || i >= a.len {
		panic('array.set: index out of range') //FIXME: (i == $i, a.len == $a.len)')
	}
	mem_copy(a.data + a.element_size * i, val, a.element_size)
}
