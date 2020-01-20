module f

import fontstash

pub const (
  used_import = 1 + fontstash.used_import
)

#flag windows -I @VROOT/thirdparty/freetype/include
#flag windows -L @VROOT/thirdparty/freetype/win64

#flag linux -I/usr/include/freetype2
#flag darwin -I/usr/local/include/freetype2
#flag darwin -I/opt/local/include/freetype2
#flag darwin -I/usr/local/Cellar/freetype/2.10.0/include/freetype2/
#flag freebsd -I/usr/local/include/freetype2
#flag freebsd -Wl -L/usr/local/lib

#flag -lfreetype
#flag darwin -lpng -lbz2 -lz

#flag linux -I.

#include "ft2build.h"

#define FONS_USE_FREETYPE
#define SOKOL_FONTSTASH_IMPL
#include "util/sokol_fontstash.h"
