// Copyright (c) 2019 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module http

import os

fn download_file(url, out string) bool {
	s := http.get(url) or { return false }
	os.write_file(out, s.text)
	return true
	//download_file_with_progress(url, out, empty, empty)
}
