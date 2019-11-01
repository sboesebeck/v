module filepath

import(
	os
	strings
)

// return the extension in the file `path`
pub fn ext(path string) string {
	pos := path.last_index_byte(`.`)
	if pos != -1 {
		return path[pos..]
	}
	return ''
}

// returns true if `path` is absolute
pub fn is_abs(path string) bool {
	$if windows {
		return path[0] == `/` || // incase we're in MingGW bash
			(path[0].is_letter() && path[1] == `:`)
	}
	return path[0] == `/`
}

// pass directories as parameters, returns path as string 
// TODO use []string.join once ...string becomes "[]string"
pub fn join(base string, dirs ...string) string {
	mut path := strings.new_builder(50)
	path.write(base.trim_right('\\/'))
	for d in dirs {
		path.write(os.path_separator)
		path.write(d)
	}
	return path.str()
}
