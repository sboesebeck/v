// Copyright (c) 2019 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module compiler

fn (p mut Parser) bool_expression() string {
	tok := p.tok
	typ := p.bterm()
	mut got_and := false // to catch `a && b || c` in one expression without ()
	mut got_or := false
	for p.tok == .and || p.tok == .logical_or {
		if p.tok == .and {
			got_and = true
			if got_or { p.error(and_or_error) }
		}
		if p.tok == .logical_or {
			got_or = true
			if got_and { p.error(and_or_error) }
		}
		if p.is_sql {
			if p.tok == .and {
				p.gen(' and ')
			}
			else if p.tok == .logical_or {
				p.gen(' or ')
			}
		} else {
			p.gen(' ${p.tok.str()} ')
		}
		p.check_space(p.tok)
		p.check_types(p.bterm(), typ)
		if typ != 'bool' {
			p.error('logical operators `&&` and `||` require booleans')
		}	
	}
	if typ == '' {
		println('curline:')
		println(p.cgen.cur_line)
		println(tok.str())
		p.error('expr() returns empty type')
	}
	return typ
}

fn (p mut Parser) bterm() string {
	ph := p.cgen.add_placeholder()
	mut typ := p.expression()
	p.expected_type = typ
	is_str := typ=='string'  &&   !p.is_sql
	is_ustr := typ=='ustring'
	is_float := typ[0] == `f` && (typ in ['f64', 'f32']) &&
		!(p.cur_fn.name in ['f64_abs', 'f32_abs']) &&
		!(p.cur_fn.name == 'eq')
	is_array := typ.contains('array_')
	expr_type := typ
	tok := p.tok
	if tok in [.eq, .gt, .lt, .le, .ge, .ne] {
		//TODO: remove when array comparing is supported
		if is_array {
			p.error('array comparing is not supported yet')
		}

		p.fspace()
		//p.fgen(' ${p.tok.str()} ')
		if (is_float || is_str || is_ustr) && !p.is_js {
			p.gen(',')
		}
		else if p.is_sql && tok == .eq {
			p.gen('=')
		}
		else {
			p.gen(tok.str())
		}
		p.next()
		p.fspace()
		// `id == user.id` => `id == $1`, `user.id`
		if p.is_sql {
			p.sql_i++
			p.gen('$' + p.sql_i.str())
			p.cgen.start_cut()
			p.check_types(p.expression(), typ)
			sql_param := p.cgen.cut()
			p.sql_params << sql_param
			p.sql_types  << typ
			//println('*** sql type: $typ | param: $sql_param')
		}  else {
			p.check_types(p.expression(), typ)
		}
		typ = 'bool'
		if is_str && !p.is_js { //&& !p.is_sql {
			p.gen(')')
			match tok {
				.eq { p.cgen.set_placeholder(ph, 'string_eq(') }
				.ne { p.cgen.set_placeholder(ph, 'string_ne(') }
				.le { p.cgen.set_placeholder(ph, 'string_le(') }
				.ge { p.cgen.set_placeholder(ph, 'string_ge(') }
				.gt { p.cgen.set_placeholder(ph, 'string_gt(') }
				.lt { p.cgen.set_placeholder(ph, 'string_lt(') }
			}
		}
		if is_ustr {
			p.gen(')')
			match tok {
				.eq { p.cgen.set_placeholder(ph, 'ustring_eq(') }
				.ne { p.cgen.set_placeholder(ph, 'ustring_ne(') }
				.le { p.cgen.set_placeholder(ph, 'ustring_le(') }
				.ge { p.cgen.set_placeholder(ph, 'ustring_ge(') }
				.gt { p.cgen.set_placeholder(ph, 'ustring_gt(') }
				.lt { p.cgen.set_placeholder(ph, 'ustring_lt(') }
			}
		}
		if is_float && p.cur_fn.name != 'f32_abs' && p.cur_fn.name != 'f64_abs' {
			p.gen(')')
			match tok {
				.eq { p.cgen.set_placeholder(ph, '${expr_type}_eq(') }
				.ne { p.cgen.set_placeholder(ph, '${expr_type}_ne(') }
				.le { p.cgen.set_placeholder(ph, '${expr_type}_le(') }
				.ge { p.cgen.set_placeholder(ph, '${expr_type}_ge(') }
				.gt { p.cgen.set_placeholder(ph, '${expr_type}_gt(') }
				.lt { p.cgen.set_placeholder(ph, '${expr_type}_lt(') }
			}
		}
	}
	return typ
}

// also called on *, &, @, . (enum)
fn (p mut Parser) name_expr() string {
	p.has_immutable_field = false
	p.is_const_literal = false
	ph := p.cgen.add_placeholder()
	// amp
	ptr := p.tok == .amp
	deref := p.tok == .mul
    mut mul_nr := 0
    mut deref_nr := 0
    for {
        if p.tok == .amp {
            mul_nr++
        }else if p.tok == .mul {
            deref_nr++
        }else {
            break
        }
        p.next()
    }

	if p.tok == .lpar {
		p.gen('*'.repeat(deref_nr))
		p.gen('(')
		p.check(.lpar)
		mut temp_type := p.bool_expression()
		p.gen(')')
		p.check(.rpar)
		for _ in 0..deref_nr {
			temp_type = temp_type.replace_once('*', '')
		}
		return temp_type
	}

	mut name := p.lit
	// Raw string (`s := r'hello \n ')
	if (name == 'r' || name == 'c') && p.peek() == .str && p.prev_tok != .dollar {
		p.string_expr()
		return 'string'
	}
	// known_type := p.table.known_type(name)
	orig_name := name
	is_c := name == 'C' && p.peek() == .dot
	if is_c {
		p.check(.name)
		p.check(.dot)
		name = p.lit
		// C struct initialization
		if p.peek() == .lcbr && p.table.known_type(name) {
			return p.get_struct_type(name, true, ptr)
		}
		// C function
		if p.peek() == .lpar {
			return p.get_c_func_type(name)
		}
		// C const (`C.GLFW_KEY_LEFT`)
		p.gen(name)
		p.next()
		return 'int'
	}
	// enum value? (`color == .green`)
	if p.tok == .dot {
		if p.table.known_type(p.expected_type) {
			p.check_enum_member_access()
			// println("found enum value: $p.expected_type")
			return p.expected_type
		} else {
			p.error("unknown enum: `$p.expected_type`")
		}
	}
	// Variable, checked before modules, so that module shadowing is allowed:
	// `gg = gg.newcontext(); gg.draw_rect(...)`
	if p.known_var_check_new_var(name) {
		return p.get_var_type(name, ptr, deref_nr)
	}
	// Module?
	if p.peek() == .dot && (name == p.mod ||
		p.import_table.known_alias(name))	&& !is_c
	{
		mut mod := name
		// must be aliased module
		if name != p.mod && p.import_table.known_alias(name) {
			p.import_table.register_used_import(name)
			mod = p.import_table.resolve_alias(name)
		}
		p.next()
		p.check(.dot)
		name = p.lit
		name = prepend_mod(mod_gen_name(mod), name)
	}
	// Unknown name, try prepending the module name to it
	// TODO perf
	else if !p.table.known_type(name) &&
		!p.table.known_fn(name) && !p.table.known_const(name) && !is_c
	{
		name = p.prepend_mod(name)
	}	
	// re-check
	if p.known_var_check_new_var(name) {
		return p.get_var_type(name, ptr, deref_nr)
	}

	// if known_type || is_c_struct_init || (p.first_pass() && p.peek() == .lcbr) {
	// known type? int(4.5) or Color.green (enum)
	if p.table.known_type(name) {
		// cast expression: float(5), byte(0), (*int)(ptr) etc
		if !is_c && ( p.peek() == .lpar || (deref && p.peek() == .rpar) ) {
			if deref {
				name += '*'.repeat(deref_nr )
			}
			else if ptr {
				name += '*'.repeat(mul_nr)
			}
			p.gen('(')
			mut typ := name
			if typ in p.cur_fn.dispatch_of.inst.keys() {
				typ = p.cur_fn.dispatch_of.inst[typ]
			}
			p.cast(typ)
			p.gen(')')
			for p.tok == .dot {
				typ = p.dot(typ, ph)
			}
			return typ
		}
		// Color.green
		else if p.peek() == .dot {
			enum_type := p.table.find_type(name)
			if enum_type.cat != .enum_ {
				p.error('`$name` is not an enum')
			}
			p.next()
			p.check(.dot)
			val := p.lit
			if !enum_type.has_enum_val(val) {
				p.error('enum `$enum_type.name` does not have value `$val`')
			}
			if p.expected_type == enum_type.name {
				// `if color == .red` is enough
				// no need in `if color == Color.red`
				p.warn('`${enum_type.name}.$val` is unnecessary, use `.$val`')
			}	
			// println('enum val $val')
			p.gen(mod_gen_name(enum_type.mod) + '__' + enum_type.name + '_' + val)// `color = main__Color_green`
			p.next()
			return enum_type.name
		}
		// normal struct init (non-C)
		else if p.peek() == .lcbr {
			return p.get_struct_type(name, false, ptr)
		}
	}

	// Constant
	if p.table.known_const(name) {
		return p.get_const_type(name, ptr)
	}
	// TODO: V script? Try os module.
	// Function (not method, methods are handled in `.dot()`)	
	mut f := p.table.find_fn_is_script(name, p.v_script) or {
		// First pass, the function can be defined later.
		if p.first_pass() {
			p.next()
			return 'void'
		}
		// exhaused all options type,enum,const,mod,var,fn etc
		// so show undefined error (also checks typos)
		p.undefined_error(name, orig_name) return '' // panics
	}
	// no () after func, so func is an argument, just gen its name
	// TODO verify this and handle errors
	peek := p.peek()
	if peek != .lpar && peek != .lt {
		// Register anon fn type
		fn_typ := Type {
			name: f.typ_str()// 'fn (int, int) string'
			mod: p.mod
			func: f
		}
		p.table.register_type2(fn_typ)
		p.gen(p.table.fn_gen_name(f))
		p.next()
		return f.typ_str() //'void*'
	}
	// TODO bring back
	if f.typ == 'void' && !p.inside_if_expr {
		// p.error('`$f.name` used as value')
	}

	fn_call_ph := p.cgen.add_placeholder()
	// println('call to fn $f.name of type $f.typ')
	// TODO replace the following dirty hacks (needs ptr access to fn table)
	new_f := f
	p.fn_call(mut new_f, 0, '', '')
	if f.is_generic {
		f2 := p.table.find_fn(f.name) or {
			return ''
		}
		// println('after call of generic instance $new_f.name(${new_f.str_args(p.table)}) $new_f.typ')
		// println('	from $f2.name(${f2.str_args(p.table)}) $f2.typ : $f2.type_inst')
	}
	f = new_f

	// optional function call `function() or {}`, no return assignment
	is_or_else := p.tok == .key_orelse
	if p.tok == .question {
		// `files := os.ls('.')?`
		if p.cur_fn.name != 'main__main' {
			p.error('`func()?` syntax can only be used inside `fn main()` for now')
		}	
		p.next()
		tmp := p.get_tmp()
		p.cgen.set_placeholder(fn_call_ph, '$f.typ $tmp = ')
		p.genln(';')
		p.genln('if (!${tmp}.ok) v_panic(${tmp}.error);')
		typ := f.typ[7..] // option_xxx
		p.gen('*($typ*) ${tmp}.data;')
		return typ
	}	
	else if !p.is_var_decl && is_or_else {
		f.typ = p.gen_handle_option_or_else(f.typ, '', fn_call_ph)
	}
    else if !p.is_var_decl && !is_or_else  && !p.inside_return_expr &&
		f.typ.starts_with('Option_') {
        opt_type := f.typ[7..]
        p.error('unhandled option type: `?$opt_type`')
    }

	// dot after a function call: `get_user().age`
	if p.tok == .dot {
		mut typ := ''
		for p.tok == .dot {
			// println('dot #$dc')
			typ = p.dot(f.typ, ph)
		}
		return typ
	}
	//p.log('end of name_expr')

	if f.typ.ends_with('*') {
		p.is_alloc = true
	}
	return f.typ
}

// returns resulting type
fn (p mut Parser) expression() string {
	p.is_const_literal = true
	//if p.scanner.file_path.contains('test_test') {
		//println('expression() pass=$p.pass tok=')
		//p.print_tok()
	//}
	ph := p.cgen.add_placeholder()
	mut typ := p.indot_expr()
	is_str := typ=='string'
	is_ustr := typ=='ustring'
	// `a << b` ==> `array_push(&a, b)`
	if p.tok == .left_shift {
		if typ.contains('array_') {
			// Can't pass integer literal, because push requires a void*
			// a << 7 => int tmp = 7; array_push(&a, &tmp);
			// _PUSH(&a, expression(), tmp, string)
			tmp := p.get_tmp()
			tmp_typ := typ[6..]// skip "array_"
			p.check_space(.left_shift)
			// Get the value we are pushing
			p.gen(', (')
			// Immutable? Can we push?
			if !p.expr_var.is_mut && !p.pref.translated {
				p.error('`$p.expr_var.name` is immutable (can\'t <<)')
			}
			if p.expr_var.is_arg && p.expr_var.typ.starts_with('array_') {
				p.error("for now it's not possible to append an element to "+
					'a mutable array argument `$p.expr_var.name`')
			}
			if !p.expr_var.is_changed {
				p.mark_var_changed(p.expr_var)
			}
			p.gen('/*typ = $typ   tmp_typ=$tmp_typ*/')
			ph_clone := p.cgen.add_placeholder()
			expr_type := p.expression()
			// Need to clone the string when appending it to an array?
			if p.pref.autofree && typ == 'array_string' && expr_type == 'string' {
				p.cgen.set_placeholder(ph_clone, 'string_clone(')
				p.gen(')')
			}
			p.gen_array_push(ph, typ, expr_type, tmp, tmp_typ)
			return 'void'
		}
		else {
			if !is_integer_type(typ)  {
				t := p.table.find_type(typ)
				if t.cat != .enum_ {
					p.error('cannot use shift operator on non-integer type `$typ`')
				}
			}
			p.next()
			p.gen(' << ')
			p.check_types(p.expression(), 'integer')
			return typ
		}
	}
	if p.tok == .righ_shift {
		if !is_integer_type(typ)  {
			t := p.table.find_type(typ)
			if t.cat != .enum_ {
				p.error('cannot use shift operator on non-integer type `$typ`')
			}
		}
		p.next()
		p.gen(' >> ')
		p.check_types(p.expression(), 'integer')
		return typ
	}
	// + - | ^
	for p.tok in [.plus, .minus, .pipe, .amp, .xor] {
		tok_op := p.tok
		if typ == 'bool' {
			p.error('operator ${p.tok.str()} not defined on bool ')
		}
		is_num := typ.contains('*') || is_number_type(typ)
		p.check_space(p.tok)
		if is_str && tok_op == .plus && !p.is_js {
			p.cgen.set_placeholder(ph, 'string_add(')
			p.gen(',')
		}
		else if is_ustr && tok_op == .plus {
			p.cgen.set_placeholder(ph, 'ustring_add(')
			p.gen(',')
		}
		// 3 + 4
		else if is_num || p.is_js {
			if typ == 'void*' {
				// Msvc errors on void* pointer arithmatic
				// ... So cast to byte* and then do the add
				p.cgen.set_placeholder(ph, '(byte*)')
			}else if typ.contains('*') {
                p.cgen.set_placeholder(ph, '($typ)')
            }
			p.gen(tok_op.str())
		}
		// Vec + Vec
		else {
			if p.pref.translated {
				p.gen(tok_op.str() + ' /*doom hack*/')// TODO hack to fix DOOM's angle_t
			}
			else {
				p.gen(',')
			}
		}
		if is_str && tok_op != .plus {
			p.error('strings only support `+` operator')
		}	
		expr_type := p.term()
		if (tok_op in [.pipe, .amp, .xor]) && !(is_integer_type(expr_type) &&
			is_integer_type(typ)) {
			p.error('operator ${tok_op.str()} is defined only on integer types')
		}	
		p.check_types(expr_type, typ)
		if (is_str || is_ustr) && tok_op == .plus && !p.is_js {
			p.gen(')')
		}
		// Make sure operators are used with correct types
		if !p.pref.translated && !is_str && !is_ustr && !is_num {
			T := p.table.find_type(typ)
			if      tok_op == .plus {  p.handle_operator('+', typ, 'op_plus', ph, T)  }
			else if tok_op == .minus { p.handle_operator('-', typ, 'op_minus', ph, T) }
		}
	}
	return typ
}

fn (p mut Parser) handle_operator(op string, typ string, cpostfix string, ph int, T &Type) {
	if T.has_method( op ) {
		p.cgen.set_placeholder(ph, '${typ}_${cpostfix}(')
		p.gen(')')
	}
	else {
		p.error('operator $op not defined on `$typ`')
	}
}

fn (p mut Parser) term() string {
	line_nr := p.scanner.line_nr
	//if p.fileis('fn_test') {
		//println('\nterm() $line_nr')
	//}
	ph := p.cgen.add_placeholder()
	typ := p.unary()
	//if p.fileis('fn_test') {
		//println('2: $line_nr')
	//}
	// `*` on a newline? Can't be multiplication, only dereference
	if p.tok == .mul && line_nr != p.scanner.line_nr {
		return typ
	}
	for p.tok == .mul || p.tok == .div || p.tok == .mod {
		tok := p.tok
		is_mul := tok == .mul
		is_div := tok == .div
		is_mod := tok == .mod
		p.fspace()
		p.next()
		p.gen(tok.str())// + ' /*op2*/ ')
		oph := p.cgen.add_placeholder()
		p.fspace()
		if (is_div || is_mod) && p.tok == .number && p.lit == '0' {
			p.error('division or modulo by zero')
		}
		expr_type := p.unary()
		if (is_mul || is_div) && expr_type == 'string' {
			p.error('operator ${tok.str()} cannot be used on strings')
		}
		if !is_primitive_type(expr_type) && expr_type == typ {
			p.check_types(expr_type, typ)
			T := p.table.find_type(typ)
			// NB: oph is a char index just after the OP
			before_oph := p.cgen.cur_line[..oph-1]
			after_oph := p.cgen.cur_line[oph..]
			p.cgen.cur_line = before_oph + ',' + after_oph
			match tok {
				.mul {   p.handle_operator('*', typ, 'op_mul', ph, T) }
				.div {   p.handle_operator('/', typ, 'op_div', ph, T) }
				.mod {   p.handle_operator('%', typ, 'op_mod', ph, T) }
			}
			continue
		}
		
		if is_mod {
			if !(is_integer_type(expr_type) && is_integer_type(typ)) {
				p.error('operator `mod` requires integer types')
			}
		} else {
			p.check_types(expr_type, typ)
		}	
	}
	return typ
}

fn (p mut Parser) unary() string {
	mut typ := ''
	tok := p.tok
	match tok {
	.not {
		p.gen('!')
		p.check(.not)
		// typ should be bool type
		typ = p.indot_expr()
		if typ != 'bool' {
			p.error('operator ! requires bool type, not `$typ`')
		}
	}
	.bit_not {
		p.gen('~')
		p.check(.bit_not)
		typ = p.bool_expression()
	}
	else {
		typ = p.factor()
	}
	}
	return typ
}

fn (p mut Parser) factor() string {
	mut typ := ''
	tok := p.tok
	match tok {
	.key_none {
		if !p.expected_type.starts_with('Option_') {
			p.error('need "$p.expected_type" got none')
		}
		p.gen('opt_none()')
		p.check(.key_none)
		return p.expected_type
	}
	.number {
		typ = 'int'
		// Check if float (`1.0`, `1e+3`) but not if is hexa
		if (p.lit.contains('.') || (p.lit.contains('e') || p.lit.contains('E'))) &&
			!(p.lit[0] == `0` && (p.lit[1] == `x` || p.lit[1] == `X`)) {
			typ = 'f32'
			// typ = 'f64' // TODO
		} else {
			v_u64 := p.lit.u64()
			if u64(u32(v_u64)) < v_u64 {
				typ = 'u64'
			}
		}
		if p.expected_type != '' && !is_valid_int_const(p.lit, p.expected_type) {
			p.error('constant `$p.lit` overflows `$p.expected_type`')
		}
		p.gen(p.lit)
	}
	.minus {
		p.gen('-')
		p.next()
		return p.factor()
		// Variable
	}
	.key_sizeof {
		p.gen('sizeof(')
		p.fgen('sizeof(')
		p.next()
		p.check(.lpar)
		mut sizeof_typ := p.get_type()
		p.check(.rpar)
		p.gen('$sizeof_typ)')
		p.fgen('$sizeof_typ)')
		return 'int'
	}
	.amp, .dot, .mul {
		// (dot is for enum vals: `.green`)
		return p.name_expr()
	}
	.name {
		// map[string]int
		if p.lit == 'map' && p.peek() == .lsbr {
			return p.map_init()
		}
		if p.lit == 'json' && p.peek() == .dot {
			if !('json' in p.table.imports) {
				p.error('undefined: `json`, use `import json`')
			}
			p.import_table.register_used_import('json')
			return p.js_decode()
		}
		//if p.fileis('orm_test') {
			//println('ORM name: $p.lit')
		//}
		typ = p.name_expr()
		return typ
	}
	/*
	.key_default {
		p.next()
		p.next()
		name := p.check_name()
		if name != 'T' {
			p.error('default needs T')
		}
		p.gen('default(T)')
		p.next()
		return 'T'
	}
	*/
	.lpar {
		//p.gen('(/*lpar*/')
		p.gen('(')
		p.check(.lpar)
		typ = p.bool_expression()
		// Hack. If this `)` referes to a ptr cast `(*int__)__`, it was already checked
		// TODO: fix parser so that it doesn't think it's a par expression when it sees `(` in
		// __(__*int)(
		if !p.ptr_cast {
			p.check(.rpar)
		}
		p.ptr_cast = false
		p.gen(')')
		return typ
	}
	.chartoken {
		p.char_expr()
		typ = 'byte'
		return typ
	}
	.str {
		p.string_expr()
		typ = 'string'
		return typ
	}
	.key_false {
		typ = 'bool'
		p.gen('0')
	}
	.key_true {
		typ = 'bool'
		p.gen('1')
	}
	.lsbr {
		// `[1,2,3]` or `[]` or `[20]byte`
		// TODO have to return because arrayInit does next()
		// everything should do next()
		return p.array_init()
	}
	.lcbr {
		// `m := { 'one': 1 }`
		if p.peek() == .str {
			return p.map_init()
		}
		// { user | name :'new name' }
		return p.assoc()
	}
	.key_if {
		typ = p.if_st(true, 0)
		return typ
	}
	.key_match {
		typ = p.match_statement(true)
		return typ
	}
	else {
		if p.pref.is_verbose || p.pref.is_debug {
			next := p.peek()
			println('prev=${p.prev_tok.str()}')
			println('next=${next.str()}')
		}
		p.error('unexpected token: `${p.tok.str()}`')
	}
	}
	p.next()// TODO everything should next()
	return typ
}

// { user | name: 'new name' }
