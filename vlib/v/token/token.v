// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module token

pub struct Token {
pub:
	kind    Kind // the token number/enum; for quick comparisons
	lit     string // literal representation of the token
	line_nr int // the line number in the source where the token occured
	// name_idx int // name table index for O(1) lookup
	// pos      int // the position of the token in scanner text
}

pub enum Kind {
	eof
	name // user
	number // 123
	str // 'foo'
	str_inter // 'name=$user.name'
	chartoken // `A`
	plus
	minus
	mul
	div
	mod
	xor // ^
	pipe // |
	inc // ++
	dec // --
	and // &&
	logical_or
	not
	bit_not
	question
	comma
	semicolon
	colon
	arrow // =>
	amp
	hash
	dollar
	str_dollar
	left_shift
	right_shift
	// at // @
	assign // =
	decl_assign // :=
	plus_assign // +=
	minus_assign // -=
	div_assign
	mult_assign
	xor_assign
	mod_assign
	or_assign
	and_assign
	righ_shift_assign
	left_shift_assign
	// {}  () []
	lcbr
	rcbr
	lpar
	rpar
	lsbr
	rsbr
	// == != <= < >= >
	eq
	ne
	gt
	lt
	ge
	le
	// comments
	line_comment
	mline_comment
	nl
	dot
	dotdot
	ellipsis
	// keywords
	keyword_beg
	key_as
	key_asm
	key_assert
	key_atomic
	key_break
	key_const
	key_continue
	key_defer
	key_else
	key_embed
	key_enum
	key_false
	key_for
	key_fn
	key_global
	key_go
	key_goto
	key_if
	key_import
	key_import_const
	key_in
	key_interface
	// key_it
	key_match
	key_module
	key_mut
	key_none
	key_return
	key_select
	key_sizeof
	key_offsetof
	key_struct
	key_switch
	key_true
	key_type
	// typeof
	key_orelse
	key_union
	key_pub
	key_static
	key_unsafe
	keyword_end
}

const (
	assign_tokens = [Kind.assign, .plus_assign, .minus_assign, .mult_assign,
	.div_assign, .xor_assign, .mod_assign, .or_assign, .and_assign,
	.righ_shift_assign, .left_shift_assign]
	nr_tokens = 141
)
// build_keys genereates a map with keywords' string values:
// Keywords['return'] == .key_return
fn build_keys() map[string]int {
	mut res := map[string]int
	for t := int(Kind.keyword_beg) + 1; t < int(Kind.keyword_end); t++ {
		key := token_str[t]
		res[key] = t
	}
	return res
}

// TODO remove once we have `enum Kind { name('name') if('if') ... }`
fn build_token_str() []string {
	mut s := [''].repeat(nr_tokens)
	s[Kind.keyword_beg] = ''
	s[Kind.keyword_end] = ''
	s[Kind.eof] = 'eof'
	s[Kind.name] = 'name'
	s[Kind.number] = 'number'
	s[Kind.str] = 'STR'
	s[Kind.chartoken] = 'char'
	s[Kind.plus] = '+'
	s[Kind.minus] = '-'
	s[Kind.mul] = '*'
	s[Kind.div] = '/'
	s[Kind.mod] = '%'
	s[Kind.xor] = '^'
	s[Kind.bit_not] = '~'
	s[Kind.pipe] = '|'
	s[Kind.hash] = '#'
	s[Kind.amp] = '&'
	s[Kind.inc] = '++'
	s[Kind.dec] = '--'
	s[Kind.and] = '&&'
	s[Kind.logical_or] = '||'
	s[Kind.not] = '!'
	s[Kind.dot] = '.'
	s[Kind.dotdot] = '..'
	s[Kind.ellipsis] = '...'
	s[Kind.comma] = ','
	// s[Kind.at] = '@'
	s[Kind.semicolon] = ';'
	s[Kind.colon] = ':'
	s[Kind.arrow] = '=>'
	s[Kind.assign] = '='
	s[Kind.decl_assign] = ':='
	s[Kind.plus_assign] = '+='
	s[Kind.minus_assign] = '-='
	s[Kind.mult_assign] = '*='
	s[Kind.div_assign] = '/='
	s[Kind.xor_assign] = '^='
	s[Kind.mod_assign] = '%='
	s[Kind.or_assign] = '|='
	s[Kind.and_assign] = '&='
	s[Kind.righ_shift_assign] = '>>='
	s[Kind.left_shift_assign] = '<<='
	s[Kind.lcbr] = '{'
	s[Kind.rcbr] = '}'
	s[Kind.lpar] = '('
	s[Kind.rpar] = ')'
	s[Kind.lsbr] = '['
	s[Kind.rsbr] = ']'
	s[Kind.eq] = '=='
	s[Kind.ne] = '!='
	s[Kind.gt] = '>'
	s[Kind.lt] = '<'
	s[Kind.ge] = '>='
	s[Kind.le] = '<='
	s[Kind.question] = '?'
	s[Kind.left_shift] = '<<'
	s[Kind.right_shift] = '>>'
	s[Kind.line_comment] = '// line comment'
	s[Kind.mline_comment] = '/* mline comment */'
	s[Kind.nl] = 'NLL'
	s[Kind.dollar] = '$'
	s[Kind.str_dollar] = '$2'
	s[Kind.key_assert] = 'assert'
	s[Kind.key_struct] = 'struct'
	s[Kind.key_if] = 'if'
	// s[Kind.key_it] = 'it'
	s[Kind.key_else] = 'else'
	s[Kind.key_asm] = 'asm'
	s[Kind.key_return] = 'return'
	s[Kind.key_module] = 'module'
	s[Kind.key_sizeof] = 'sizeof'
	s[Kind.key_go] = 'go'
	s[Kind.key_goto] = 'goto'
	s[Kind.key_const] = 'const'
	s[Kind.key_mut] = 'mut'
	s[Kind.key_type] = 'type'
	s[Kind.key_for] = 'for'
	s[Kind.key_switch] = 'switch'
	s[Kind.key_fn] = 'fn'
	s[Kind.key_true] = 'true'
	s[Kind.key_false] = 'false'
	s[Kind.key_continue] = 'continue'
	s[Kind.key_break] = 'break'
	s[Kind.key_import] = 'import'
	s[Kind.key_embed] = 'embed'
	s[Kind.key_unsafe] = 'unsafe'
	// Kinds[key_typeof] = 'typeof'
	s[Kind.key_enum] = 'enum'
	s[Kind.key_interface] = 'interface'
	s[Kind.key_pub] = 'pub'
	s[Kind.key_import_const] = 'import_const'
	s[Kind.key_in] = 'in'
	s[Kind.key_atomic] = 'atomic'
	s[Kind.key_orelse] = 'or'
	s[Kind.key_global] = '__global'
	s[Kind.key_union] = 'union'
	s[Kind.key_static] = 'static'
	s[Kind.key_as] = 'as'
	s[Kind.key_defer] = 'defer'
	s[Kind.key_match] = 'match'
	s[Kind.key_select] = 'select'
	s[Kind.key_none] = 'none'
	s[Kind.key_offsetof] = '__offsetof'
	return s
}

const (
	token_str = build_token_str()
	keywords = build_keys()
)

pub fn key_to_token(key string) Kind {
	a := Kind(keywords[key])
	return a
}

pub fn is_key(key string) bool {
	return int(key_to_token(key)) > 0
}

pub fn is_decl(t Kind) bool {
	return t in [.key_enum, .key_interface, .key_fn, .key_struct, .key_type, .key_const, .key_import_const, .key_pub, .eof]
}

pub fn (t Kind) is_assign() bool {
	return t in assign_tokens
}

fn (t []Kind) contains(val Kind) bool {
	for tt in t {
		if tt == val {
			return true
		}
	}
	return false
}

pub fn (t Kind) str() string {
	if t == .number {
		return 'number'
	}
	if t == .chartoken {
		return 'char' // '`lit`'
	}
	if t == .str {
		return 'str' // "'lit'"
	}
	/*
	if t < .plus {
		return lit // string, number etc
	}
	*/

	return token_str[int(t)]
}

pub fn (t Token) str() string {
	return '$t.kind.str() "$t.lit"'
}

// Representation of highest and lowest precedence
pub const (
	lowest_prec = 0
	highest_prec = 8
)

pub enum Precedence {
	lowest
	cond // OR or AND
	assign // =
	eq // == or !=
	less_greater // > or <
	sum // + or -
	product // * or /
	mod // %
	prefix // -X or !X
	call // func(X) or foo.method(X)
	index // array[index], map[key]
}

pub fn build_precedences() []Precedence {
	mut p := []Precedence
	p = make(100, 100, sizeof(Precedence))
	p[Kind.assign] = .assign
	p[Kind.eq] = .eq
	p[Kind.ne] = .eq
	p[Kind.lt] = .less_greater
	p[Kind.gt] = .less_greater
	p[Kind.le] = .less_greater
	p[Kind.ge] = .less_greater
	p[Kind.plus] = .sum
	p[Kind.plus_assign] = .sum
	p[Kind.minus] = .sum
	p[Kind.minus_assign] = .sum
	p[Kind.div] = .product
	p[Kind.div_assign] = .product
	p[Kind.mul] = .product
	p[Kind.mult_assign] = .product
	p[Kind.mod] = .mod
	p[Kind.and] = .cond
	p[Kind.logical_or] = .cond
	p[Kind.lpar] = .call
	p[Kind.dot] = .call
	p[Kind.lsbr] = .index
	return p
}

const (
	precedences = build_precedences()
	// int(Kind.assign): Precedence.assign
	// }
)
// precedence returns a tokens precedence if defined, otherwise lowest_prec
pub fn (tok Token) precedence() int {
	// TODO
	// return int(precedences[int(tok)])
	match tok.kind {
		.lsbr {
			return 9
		}
		.dot {
			return 8
		}
		// `++` | `--`
		.inc, .dec {
			// return 0
			return 7
		}
		// `*` |  `/` | `%` | `<<` | `>>` | `&`
		.mul, .div, .mod, .left_shift, .right_shift, .amp {
			return 6
		}
		// `+` |  `-` |  `|` | `^`
		.plus, .minus, .pipe, .xor {
			return 5
		}
		// `==` | `!=` | `<` | `<=` | `>` | `>=`
		.eq, .ne, .lt, .le, .gt, .ge {
			return 4
		}
		// `&&`
		.and {
			return 3
		}
		// `||`
		.logical_or, .assign, .plus_assign, .minus_assign, .div_assign, .mod_assign, .or_assign,
		//
		.left_shift_assign, .righ_shift_assign, .mult_assign {
			return 2
		}
		.key_in, .key_as {
			return 1
		}
		// /.plus_assign {
		// /return 2
		// /}
		else {
			return lowest_prec
		}
	}
}

// is_scalar returns true if the token is a scalar
pub fn (tok Token) is_scalar() bool {
	return tok.kind in [.number, .str]
}

// is_unary returns true if the token can be in a unary expression
pub fn (tok Token) is_unary() bool {
	return tok.kind in [
	// `+` | `-` | `!` | `~` | `*` | `&`
	.plus, .minus, .not, .bit_not, .mul, .amp]
}

/*
// NOTE: do we need this for all tokens (is_left_assoc / is_right_assoc),
// or only ones with the same precedence?
// is_left_assoc returns true if the token is left associative
pub fn (tok Token) is_left_assoc() bool {
	return tok.kind in [
	// `.`
	.dot,
	// `+` | `-`
	.plus, .minus, // additive
	// .number,
	// `++` | `--`
	.inc, .dec,
	// `*` | `/` | `%`
	.mul, .div, .mod,
	// `^` | `||` | `&`
	.xor, .logical_or, .and,
	// `==` | `!=`
	.eq, .ne,
	// `<` | `<=` | `>` | `>=`
	.lt, .le, .gt, .ge, .ne, .eq,
	// `,`
	.comma]
}

// is_right_assoc returns true if the token is right associative
pub fn (tok Token) is_right_assoc() bool {
	return tok.kind in [
	// `+` | `-` | `!`
	.plus, .minus, .not, // unary
	// `=` | `+=` | `-=` | `*=` | `/=`
	.assign, .plus_assign, .minus_assign, .mult_assign, .div_assign,
	// `%=` | `>>=` | `<<=`
	.mod_assign, .righ_shift_assign, .left_shift_assign,
	// `&=` | `^=` | `|=`
	.and_assign, .xor_assign, .or_assign]
}
*/


pub fn (tok Kind) is_relational() bool {
	return tok in [
	// `<` | `<=` | `>` | `>=`
	.lt, .le, .gt, .ge, .eq, .ne]
}

pub fn (k Kind) is_start_of_type() bool {
	return k in [.name, .lpar, .amp, .lsbr, .question]
}

pub fn (kind Kind) is_infix() bool {
	return kind in [.plus, .minus, .mod, .mul, .div, .eq, .ne, .gt, .lt, .key_in,
	//
	.key_as, .ge, .le, .logical_or,
	//
	.and, .dot, .pipe, .amp, .left_shift, .right_shift]
}
