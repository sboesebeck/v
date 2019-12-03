// Copyright (c) 2019 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module compiler

import os
import filepath

pub fn get_vtmp_folder() string {
	vtmp := filepath.join(os.tmpdir(),'v')
	if !os.dir_exists( vtmp ) {
		os.mkdir(vtmp) or { panic(err) }
	}
	return vtmp
}

pub fn get_vtmp_filename(base_file_name string, postfix string) string {
	vtmp := get_vtmp_folder()
	return os.realpath( filepath.join(vtmp, os.filename( os.realpath(base_file_name) ) + postfix) )
}
